import '../entities/auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession> login({
    required String email,
    required String password,
  });

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    required double weightKg,
    required double heightCm,
    String? activityLevelId,
  });

  Future<void> requestOtp(String email);

  Future<void> verifyOtp({
    required String email,
    required String otpCode,
  });

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });

  Future<void> logout();

  /// Resolves a saved session on app startup without forcing a fresh login.
  /// Returns `true` if there's a usable access token (existing one, or a
  /// freshly refreshed one), `false` if the user needs to log in again.
  Future<bool> tryRestoreSession();
}
