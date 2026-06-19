import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  const RegisterUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthSession> call({
    required String name,
    required String email,
    required String password,
    required double weightKg,
    required double heightCm,
    String? activityLevelId,
  }) {
    return _repository.register(
      name: name,
      email: email,
      password: password,
      weightKg: weightKg,
      heightCm: heightCm,
      activityLevelId: activityLevelId,
    );
  }
}
