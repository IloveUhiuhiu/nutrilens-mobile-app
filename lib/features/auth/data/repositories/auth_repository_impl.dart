import '../../../../core/storage/secure_token_storage.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remoteDataSource, this._tokenStorage);

  final AuthRemoteDataSource _remoteDataSource;
  final SecureTokenStorage _tokenStorage;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final session = await _remoteDataSource.login(
      email: email,
      password: password,
    );
    await _saveTokensIfPresent(session);
    return session;
  }

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    required double weightKg,
    required double heightCm,
    String? activityLevelId,
  }) async {
    final session = await _remoteDataSource.register(
      name: name,
      email: email,
      password: password,
      weightKg: weightKg,
      heightCm: heightCm,
      activityLevelId: activityLevelId,
    );
    await _saveTokensIfPresent(session);
    return session;
  }

  @override
  Future<void> requestOtp(String email) {
    return _remoteDataSource.requestOtp(email);
  }

  @override
  Future<void> verifyOtp({
    required String email,
    required String otpCode,
  }) {
    return _remoteDataSource.verifyOtp(email: email, otpCode: otpCode);
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    return _remoteDataSource.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> logout() {
    return _tokenStorage.clearTokens();
  }

  @override
  Future<bool> tryRestoreSession() async {
    try {
      final accessToken = await _tokenStorage.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        // Don't validate it here — an expired access token is handled
        // transparently by AuthInterceptor on the first real API call.
        return true;
      }

      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final newAccessToken =
          await _remoteDataSource.refreshAccessToken(refreshToken);
      if (newAccessToken == null || newAccessToken.isEmpty) {
        await _tokenStorage.clearTokens();
        return false;
      }
      await _tokenStorage.saveAccessToken(newAccessToken);
      return true;
    } catch (_) {
      // Covers both a failed refresh call and the token storage itself being
      // unavailable (e.g. locked keystore) — either way, fall back to login
      // instead of leaving the splash screen stuck. clearTokens() is
      // best-effort here since storage itself may be what's failing.
      try {
        await _tokenStorage.clearTokens();
      } catch (_) {
        // ignore
      }
      return false;
    }
  }

  Future<void> _saveTokensIfPresent(AuthSession session) {
    if (session.accessToken.isEmpty || session.refreshToken.isEmpty) {
      return Future.value();
    }

    return _tokenStorage.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
  }
}
