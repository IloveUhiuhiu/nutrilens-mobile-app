import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/repositories/auth_repository.dart';

part 'change_password_state.dart';

class ChangePasswordCubit extends Cubit<ChangePasswordState> {
  ChangePasswordCubit(this._authRepository) : super(const ChangePasswordState());

  final AuthRepository _authRepository;

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    emit(state.copyWith(status: ChangePasswordStatus.loading, fieldErrors: {}));
    try {
      await _authRepository.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      emit(state.copyWith(status: ChangePasswordStatus.success));
    } on ApiException catch (error) {
      final fieldErrors = <String, String>{};
      final raw = error.data;
      if (raw is Map) {
        final errors = raw['errors'];
        if (errors is Map) {
          for (final entry in errors.entries) {
            final msgs = entry.value;
            if (msgs is List && msgs.isNotEmpty) {
              fieldErrors[entry.key.toString()] = msgs.first.toString();
            } else if (msgs is String) {
              fieldErrors[entry.key.toString()] = msgs;
            }
          }
        }
      }
      emit(state.copyWith(
        status: ChangePasswordStatus.failure,
        errorMessage: error.message,
        fieldErrors: fieldErrors,
      ));
    } catch (error) {
      debugPrint('[ChangePasswordCubit] changePassword failed: $error');
      emit(state.copyWith(
        status: ChangePasswordStatus.failure,
        errorMessage: 'Đã xảy ra lỗi không mong muốn.',
      ));
    }
  }
}
