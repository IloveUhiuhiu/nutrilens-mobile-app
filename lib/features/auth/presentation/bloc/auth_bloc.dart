import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required AuthRepository authRepository,
  })  : _loginUseCase = loginUseCase,
        _registerUseCase = registerUseCase,
        _authRepository = authRepository,
        super(const Unauthenticated()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final AuthRepository _authRepository;

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const Authenticating());
    try {
      final session = await _loginUseCase(
        email: event.email,
        password: event.password,
      );
      emit(Authenticated(session));
    } catch (error) {
      emit(AuthError(_messageFromError(error)));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const Authenticating());
    try {
      final session = await _registerUseCase(
        name: event.name,
        email: event.email,
        password: event.password,
        weightKg: event.weightKg,
        heightCm: event.heightCm,
        activityLevelId: event.activityLevelId,
      );
      await _authRepository.requestOtp(event.email);
      emit(Authenticated(session));
    } catch (error) {
      emit(AuthError(_messageFromError(error)));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    emit(const Unauthenticated());
  }

  String _messageFromError(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Không thể xác thực. Vui lòng thử lại.';
  }
}
