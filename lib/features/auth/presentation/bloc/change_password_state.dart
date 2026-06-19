part of 'change_password_cubit.dart';

enum ChangePasswordStatus { initial, loading, success, failure }

class ChangePasswordState extends Equatable {
  const ChangePasswordState({
    this.status = ChangePasswordStatus.initial,
    this.errorMessage,
    this.fieldErrors = const {},
  });

  final ChangePasswordStatus status;
  final String? errorMessage;
  final Map<String, String> fieldErrors;

  bool get isLoading => status == ChangePasswordStatus.loading;
  bool get succeeded => status == ChangePasswordStatus.success;

  ChangePasswordState copyWith({
    ChangePasswordStatus? status,
    String? errorMessage,
    Map<String, String>? fieldErrors,
  }) {
    return ChangePasswordState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, fieldErrors];
}
