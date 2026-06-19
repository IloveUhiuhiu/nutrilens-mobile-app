import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/repositories/food_scan_repository.dart';

part 'scan_feedback_state.dart';

class ScanFeedbackCubit extends Cubit<ScanFeedbackState> {
  ScanFeedbackCubit(this._repository) : super(const ScanFeedbackState());

  final FoodScanRepository _repository;

  Future<void> submit({
    required String jobId,
    required List<String> issueTypes,
    List<String> actualComponents = const [],
    String notes = '',
  }) async {
    emit(state.copyWith(status: ScanFeedbackStatus.loading));
    try {
      await _repository.submitFeedback(
        jobId,
        issueTypes: issueTypes,
        actualComponents: actualComponents,
        notes: notes,
      );
      emit(state.copyWith(status: ScanFeedbackStatus.success));
    } on ApiException catch (error) {
      debugPrint('[ScanFeedbackCubit] submitFeedback failed: HTTP ${error.statusCode} – ${error.message}');
      emit(state.copyWith(
        status: ScanFeedbackStatus.failure,
        errorMessage: error.message,
      ));
    } catch (error) {
      debugPrint('[ScanFeedbackCubit] submitFeedback error: $error');
      emit(state.copyWith(
        status: ScanFeedbackStatus.failure,
        errorMessage: 'Đã xảy ra lỗi không mong muốn.',
      ));
    }
  }
}
