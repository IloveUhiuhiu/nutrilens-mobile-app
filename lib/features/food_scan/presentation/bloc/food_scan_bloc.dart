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
  static const _maxPollAttempts = 40; // 40 × 3s = 120s total

  // Tracks whether a cancel was requested so the poll loop can exit cleanly
  // after the in-flight HTTP call returns/throws.
  bool _cancelRequested = false;

  Future<void> _onCancelRequested(
    FoodScanCancelRequested event,
    Emitter<FoodScanState> emit,
  ) async {
    _cancelRequested = true;
    _repository.cancelCurrentJob();
    emit(const FoodScanCancelled());
  }

  Future<void> _onFoodImagePicked(
    FoodImagePicked event,
    Emitter<FoodScanState> emit,
  ) async {
    _cancelRequested = false;
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
      );
    } on RequestCancelledException {
      // Cancel state was already emitted by _onCancelRequested.
      return;
    } on ApiException catch (error) {
      if (_cancelRequested) return;
      final status = error.statusCode == null ? '' : ' (${error.statusCode})';
      emit(FoodScanError(
        'Không thể tải ảnh lên máy chủ AI$status: ${error.message}',
      ));
    } catch (error) {
      if (_cancelRequested) return;
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
    _cancelRequested = false;

    if (event.jobId != null && event.jobId!.isNotEmpty) {
      emit(FoodScanUploading(event.imagePath));
      await _pollJob(
        imagePath: event.imagePath,
        jobId: event.jobId!,
        emit: emit,
      );
      return;
    }

    if (event.metadata != null) {
      add(FoodImagePicked(
        imagePath: event.imagePath,
        metadata: event.metadata!,
      ));
    }
  }

  Future<void> _pollJob({
    required String imagePath,
    required String jobId,
    required Emitter<FoodScanState> emit,
  }) async {
    for (var attempt = 0; attempt < _maxPollAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_pollInterval);
        // Check flag after delay in case cancel arrived while waiting.
        if (_cancelRequested) return;
      }

      try {
        final status = await _repository.getJobStatus(jobId);

        if (status.isFailed) {
          emit(
            FoodScanPollingFailed(
              imagePath: imagePath,
              jobId: jobId,
              message: status.message ??
                  'Quá trình phân tích thất bại hoặc hết thời gian chờ.',
            ),
          );
          return;
        }

        if (status.isPending) {
          emit(FoodScanUploading(imagePath));
        } else if (status.isProcessing) {
          emit(FoodScanProcessing(imagePath: imagePath, jobId: jobId));
        }

        // Khi server báo đã xong (hoặc status không nhận dạng được),
        // thử lấy kết quả. 404 nghĩa là chưa sẵn sàng → tiếp tục poll.
        final shouldProbeResult = status.isCompleted || status.isUnknown;
        if (shouldProbeResult) {
          try {
            final analysis = await _repository.getJobResult(jobId);
            emit(FoodScanResultReady(imagePath: imagePath, jobId: jobId, analysis: analysis));
            return;
          } on RequestCancelledException {
            return;
          } on ApiException catch (e) {
            // 404 = kết quả chưa sẵn sàng, tiếp tục vòng poll.
            // Nếu status thực sự là completed mà vẫn lỗi khác → fail luôn.
            if (status.isCompleted && e.statusCode != 404) {
              debugPrint('[FoodScanBloc] getJobResult failed: HTTP ${e.statusCode} – ${e.message}');
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
        if (_cancelRequested) return;
        if (attempt == _maxPollAttempts - 1) {
          emit(
            FoodScanPollingFailed(
              imagePath: imagePath,
              jobId: jobId,
              message: error.message,
            ),
          );
          return;
        }
      }
    }

    if (_cancelRequested) return;
    emit(
      FoodScanPollingFailed(
        imagePath: imagePath,
        jobId: jobId,
        message: 'Hết thời gian chờ phân tích AI. Vui lòng thử lại.',
      ),
    );
  }

  Future<void> _onSaveRequested(
    FoodAnalysisSaveRequested event,
    Emitter<FoodScanState> emit,
  ) async {
    final current = state;
    if (current is! FoodScanResultReady) return;

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
