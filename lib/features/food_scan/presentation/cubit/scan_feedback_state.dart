part of 'scan_feedback_cubit.dart';

enum ScanFeedbackStatus { initial, loading, success, failure }

class ScanFeedbackState extends Equatable {
  const ScanFeedbackState({
    this.status = ScanFeedbackStatus.initial,
    this.errorMessage,
  });

  final ScanFeedbackStatus status;
  final String? errorMessage;

  bool get isLoading => status == ScanFeedbackStatus.loading;
  bool get succeeded => status == ScanFeedbackStatus.success;

  ScanFeedbackState copyWith({
    ScanFeedbackStatus? status,
    String? errorMessage,
  }) {
    return ScanFeedbackState(
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
