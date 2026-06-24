import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/request_cancelled_exception.dart';
import '../../domain/entities/food_analysis.dart';
import '../../domain/repositories/food_scan_repository.dart';
import 'food_scan_event.dart';
import 'food_scan_state.dart';

class FoodScanBloc extends Bloc<FoodScanEvent, FoodScanState> {
  FoodScanBloc({
    required FoodScanRepository repository,
  })  : _repository = repository,
        super(const FoodScanIdle()) {
    on<FoodImagePicked>(_onFoodImagePicked);
    on<FoodScanCancelRequested>(_onCancelRequested);
    on<FoodScanRetryRequested>(_onRetryRequested);
    on<FoodAnalysisSaveRequested>(_onSaveRequested);
    on<FoodAnalysisItemEdited>(_onItemEdited);
  }

  final FoodScanRepository _repository;
  static const _pollInterval = Duration(seconds: 3);

  // How long the job may continuously report "running"/"retrying"
  // (server-side AI call in progress, including its own retries) before
  // it's treated as stuck rather than legitimately slow. Worst-case AI
  // latency with retries is AI_SERVER_TIMEOUT=60s × up to 3 attempts + 2
  // backoffs of a few seconds each ≈ 3 min (see inference/tasks.py on the
  // backend) — 4 min gives a ~1 min buffer without making the user wait
  // unnecessarily long for a job that's actually stuck.
  static const _stuckRunningThreshold = Duration(minutes: 4);

  // "pending" means no worker has picked the job up yet — under normal
  // load this should resolve to "running" within seconds, so a much
  // shorter threshold is enough to call it stuck.
  static const _stuckPendingThreshold = Duration(minutes: 1);

  // Absolute backstop independent of reported status, in case status keeps
  // flapping between pending/running just under each threshold above
  // without ever actually finishing.
  static const _maxTotalPollDuration = Duration(minutes: 15);

  // Bumped on every new upload/retry/cancel. A poll loop captures the
  // generation it was started with and checks it before every emit — if the
  // user starts a new scan (or cancels) while an older loop is still
  // mid-flight (e.g. awaiting its next delay after the user backed out of
  // ScanProcessingPage), the stale loop notices the mismatch and stops
  // instead of racing the new one and overwriting its state with a result
  // for the wrong job.
  int _activeGeneration = 0;

  bool _isStale(int generation) => generation != _activeGeneration;

  // Guards saveAnalysis against a double-tap firing two FoodAnalysisSaveRequested
  // events before the first one's network call returns — flutter_bloc runs
  // event handlers concurrently by default, so the `state.saved` UI check alone
  // doesn't close that window.
  bool _isSaving = false;

  Future<void> _onCancelRequested(
    FoodScanCancelRequested event,
    Emitter<FoodScanState> emit,
  ) async {
    _activeGeneration++;
    _repository.cancelCurrentJob();
    emit(const FoodScanCancelled());
  }

  Future<void> _onFoodImagePicked(
    FoodImagePicked event,
    Emitter<FoodScanState> emit,
  ) async {
    final generation = ++_activeGeneration;
    emit(FoodScanUploading(event.imagePath));
    try {
      final jobId = await _repository.createInferenceJob(
        event.imagePath,
        event.metadata,
      );
      await _pollJob(
        imagePath: event.imagePath,
        jobId: jobId,
        emit: emit,
        generation: generation,
      );
    } on RequestCancelledException {
      // Cancel state was already emitted by _onCancelRequested.
      return;
    } on ApiException catch (error) {
      if (_isStale(generation)) return;
      final status = error.statusCode == null ? '' : ' (${error.statusCode})';
      emit(FoodScanError(
        'Không thể tải ảnh lên máy chủ AI$status: ${error.message}',
      ));
    } catch (error) {
      if (_isStale(generation)) return;
      debugPrint('[FoodScanBloc] unexpected upload error: $error');
      emit(const FoodScanError(
        'Không thể tải ảnh lên máy chủ AI. Vui lòng thử lại.',
      ));
    }
  }

  Future<void> _onRetryRequested(
    FoodScanRetryRequested event,
    Emitter<FoodScanState> emit,
  ) async {
    final jobId = event.jobId;
    // The only call site (ScanProcessingPage, retrying a FoodScanPollingFailed)
    // always has a jobId — this resumes polling the same job rather than
    // re-uploading. A fresh upload after a full FoodScanError goes through
    // the capture flow again instead, which naturally regenerates metadata.
    if (jobId == null || jobId.isEmpty) return;

    final generation = ++_activeGeneration;
    emit(FoodScanUploading(event.imagePath));
    await _pollJob(
      imagePath: event.imagePath,
      jobId: jobId,
      emit: emit,
      generation: generation,
    );
  }

  Future<void> _pollJob({
    required String imagePath,
    required String jobId,
    required Emitter<FoodScanState> emit,
    required int generation,
  }) async {
    // Remembers the most recent swallowed transient error (e.g. a network
    // blip) so the final timeout message — if we get there — can say what
    // actually went wrong instead of a generic "timed out", which would
    // otherwise hide e.g. "no connection for the last two minutes" behind a
    // message that reads like the AI was just slow.
    String? lastTransientError;
    final pollStartedAt = DateTime.now();
    // Set the first time each respective status is observed, cleared the
    // moment the job leaves that status — so "stuck" means continuously in
    // that state, not just cumulatively. A backend-side reclaim (stale
    // "running" job picked up fresh by another worker) naturally resets
    // this instead of counting against the new attempt.
    DateTime? pendingSince;
    DateTime? runningSince;
    var isFirstAttempt = true;

    try {
      while (true) {
        if (DateTime.now().difference(pollStartedAt) > _maxTotalPollDuration) {
          if (_isStale(generation)) return;
          emit(
            FoodScanPollingFailed(
              imagePath: imagePath,
              jobId: jobId,
              message: lastTransientError == null
                  ? 'Hết thời gian chờ phân tích AI. Vui lòng thử lại.'
                  : 'Hết thời gian chờ phân tích AI, có thể do lỗi kết nối: $lastTransientError',
            ),
          );
          return;
        }

        if (!isFirstAttempt) {
          await Future<void>.delayed(_pollInterval);
          // Check after the delay in case a cancel/new scan arrived while
          // this loop was waiting.
          if (_isStale(generation)) return;
        }
        isFirstAttempt = false;

        try {
          final status = await _repository.getJobStatus(jobId);
          if (_isStale(generation)) return;

          if (status.isFailed) {
            emit(
              FoodScanPollingFailed(
                imagePath: imagePath,
                jobId: jobId,
                message: status.failureMessage,
              ),
            );
            return;
          }

          if (status.isPending) {
            runningSince = null;
            pendingSince ??= DateTime.now();
            if (DateTime.now().difference(pendingSince) > _stuckPendingThreshold) {
              emit(
                FoodScanPollingFailed(
                  imagePath: imagePath,
                  jobId: jobId,
                  message: 'Hệ thống chưa bắt đầu xử lý ảnh sau hơn 1 phút. Vui lòng thử lại.',
                ),
              );
              return;
            }
            emit(FoodScanUploading(imagePath));
          } else if (status.isProcessing) {
            pendingSince = null;
            runningSince ??= DateTime.now();
            if (DateTime.now().difference(runningSince) > _stuckRunningThreshold) {
              emit(
                FoodScanPollingFailed(
                  imagePath: imagePath,
                  jobId: jobId,
                  message:
                      'Quá trình phân tích AI có vẻ đang bị treo (đã hơn 6 phút không có kết quả). Vui lòng thử lại.',
                ),
              );
              return;
            }
            emit(FoodScanProcessing(imagePath: imagePath, jobId: jobId));
          } else {
            pendingSince = null;
            runningSince = null;
          }

          // Khi server báo đã xong (hoặc status không nhận dạng được),
          // thử lấy kết quả. 404 nghĩa là chưa sẵn sàng → tiếp tục poll.
          final shouldProbeResult = status.isCompleted || status.isUnknown;
          if (shouldProbeResult) {
            try {
              final analysis = await _repository.getJobResult(jobId);
              if (_isStale(generation)) return;
              emit(FoodScanResultReady(imagePath: imagePath, jobId: jobId, analysis: analysis));
              return;
            } on RequestCancelledException {
              return;
            } on ApiException catch (e) {
              // 404 = kết quả chưa sẵn sàng, tiếp tục vòng poll.
              // Nếu status thực sự là completed mà vẫn lỗi khác → fail luôn.
              if (status.isCompleted && e.statusCode != 404) {
                debugPrint('[FoodScanBloc] getJobResult failed: HTTP ${e.statusCode} – ${e.message}');
                if (_isStale(generation)) return;
                emit(
                  FoodScanPollingFailed(
                    imagePath: imagePath,
                    jobId: jobId,
                    message: 'Lấy kết quả phân tích thất bại: ${e.message}',
                  ),
                );
                return;
              }
              // unknown status + non-404: bỏ qua, tiếp tục poll.
            }
          }

          // Probe kết quả khi đang processing (server có thể trả kết quả
          // trước khi cập nhật status thành completed).
          if (status.isProcessing) {
            try {
              final analysis = await _repository.getJobResult(jobId);
              if (_isStale(generation)) return;
              emit(FoodScanResultReady(imagePath: imagePath, jobId: jobId, analysis: analysis));
              return;
            } on RequestCancelledException {
              return;
            } on ApiException catch (error) {
              if (error.statusCode != 404) rethrow;
            }
          }
        } on RequestCancelledException {
          return;
        } on ApiException catch (error) {
          if (_isStale(generation)) return;
          // Transient network/server error on the status check itself —
          // swallow and retry. The absolute backstop at the top of the loop
          // is what eventually gives up, not an attempt count; remember the
          // message in case we end up there.
          lastTransientError = error.message;
        }
      }
    } on RequestCancelledException {
      return;
    } catch (error) {
      // Safety net for anything that isn't ApiException/RequestCancelledException
      // (e.g. a TypeError from an unexpectedly-shaped JSON payload). Without
      // this, such an error escapes _pollJob uncaught — most notably from
      // the jobId-only retry path in _onRetryRequested, which has no
      // try/catch of its own around this call.
      if (_isStale(generation)) return;
      debugPrint('[FoodScanBloc] unexpected polling error: $error');
      emit(
        FoodScanPollingFailed(
          imagePath: imagePath,
          jobId: jobId,
          message: 'Đã xảy ra lỗi không mong muốn khi lấy kết quả. Vui lòng thử lại.',
        ),
      );
    }
  }

  Future<void> _onSaveRequested(
    FoodAnalysisSaveRequested event,
    Emitter<FoodScanState> emit,
  ) async {
    final current = state;
    if (current is! FoodScanResultReady || current.saved || _isSaving) return;

    _isSaving = true;
    final a = current.analysis;
    try {
      await _repository.saveAnalysis(
        current.jobId,
        nutritionOverrides: {
          'total_calories': a.totalCalories,
          'total_protein': a.proteinGrams,
          'total_carbs': a.carbsGrams,
          'total_fat': a.fatGrams,
          'total_weight': a.items.fold(0.0, (s, it) => s + it.weightGrams),
        },
      );
      emit(
        FoodScanResultReady(
          imagePath: current.imagePath,
          jobId: current.jobId,
          analysis: current.analysis,
          saved: true,
        ),
      );
    } on ApiException catch (error) {
      debugPrint('[FoodScanBloc] saveAnalysis failed: HTTP ${error.statusCode} – ${error.message}');
      emit(const FoodScanError('Không thể lưu kết quả vào nhật ký.'));
      emit(current);
    } catch (error) {
      debugPrint('[FoodScanBloc] saveAnalysis unexpected error: $error');
      emit(const FoodScanError('Không thể lưu kết quả vào nhật ký.'));
      emit(current);
    } finally {
      _isSaving = false;
    }
  }

  void _onItemEdited(
    FoodAnalysisItemEdited event,
    Emitter<FoodScanState> emit,
  ) {
    final current = state;
    if (current is! FoodScanResultReady) return;

    final items = List<FoodAnalysisItem>.from(current.analysis.items);
    if (event.index < 0 || event.index >= items.length) return;

    items[event.index] = items[event.index].copyWith(
      label: event.label,
      calories: event.calories,
      proteinGrams: event.proteinGrams,
      carbsGrams: event.carbsGrams,
      fatGrams: event.fatGrams,
      weightGrams: event.weightGrams,
    );

    final updatedAnalysis = current.analysis.copyWith(
      items: items,
      totalCalories: items.fold<double>(0.0, (s, it) => s + it.calories),
      proteinGrams: items.fold<double>(0.0, (s, it) => s + it.proteinGrams),
      carbsGrams: items.fold<double>(0.0, (s, it) => s + it.carbsGrams),
      fatGrams: items.fold<double>(0.0, (s, it) => s + it.fatGrams),
    );

    emit(FoodScanResultReady(
      imagePath: current.imagePath,
      jobId: current.jobId,
      analysis: updatedAnalysis,
      saved: current.saved,
    ));
  }
}
