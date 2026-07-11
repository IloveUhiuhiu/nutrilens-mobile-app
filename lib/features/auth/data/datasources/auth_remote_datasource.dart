import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/auth_session_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthSessionModel> login({
    required String email,
    required String password,
  });

  Future<AuthSessionModel> register({
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

  Future<({String access, String refresh})?> refreshAccessToken(
    String refreshToken,
  );
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._client);

  final DioClient _client;

  @override
  Future<AuthSessionModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.authLogin,
      data: {
        'email': email,
        'password': password,
      },
    );

    return AuthSessionModel.fromJson(
        response.data ?? const <String, dynamic>{});
  }

  @override
  Future<AuthSessionModel> register({
    required String name,
    required String email,
    required String password,
    required double weightKg,
    required double heightCm,
    String? activityLevelId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.authRegister,
      data: {
        'full_name': name,
        'email': email,
        'password': password,
        'weight': weightKg,
        'height': heightCm,
        if (activityLevelId != null && activityLevelId.isNotEmpty)
          'activity_level': activityLevelId,
      },
    );

    return AuthSessionModel.fromJson(
        response.data ?? const <String, dynamic>{});
  }

  @override
  Future<void> requestOtp(String email) {
    return _client.post<void>(
      ApiEndpoints.otpRequest,
      data: {'contact_info': email},
    );
  }

  @override
  Future<void> verifyOtp({
    required String email,
    required String otpCode,
  }) {
    return _client.post<void>(
      ApiEndpoints.otpVerify,
      data: {
        'contact_info': email,
        'otp_code': otpCode,
      },
    );
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.passwordChange,
      data: {
        'old_password': oldPassword,
        'new_password': newPassword,
      },
    );
  }

  @override
  Future<({String access, String refresh})?> refreshAccessToken(
    String refreshToken,
  ) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.authTokenRefresh,
      data: {'refresh': refreshToken},
      // Avoids AuthInterceptor retrying this same call on a 401 (the refresh
      // token itself being invalid/expired), which would just duplicate the
      // request instead of fixing anything.
      options: Options(extra: {'skip_auth_refresh': true}),
    );
    // Stock simplejwt TokenRefreshView — returns {"access": ..., "refresh":
    // ...} directly, unlike every other endpoint which wraps in "data".
    final body = response.data ?? const <String, dynamic>{};
    final accessToken = '${body['access'] ?? ''}';
    if (accessToken.isEmpty) {
      return null;
    }
    // Backend rotates + blacklists the old refresh token on every refresh
    // (ROTATE_REFRESH_TOKENS/BLACKLIST_AFTER_ROTATION) — the new one must be
    // returned so the caller persists it, or the next refresh attempt fails.
    final newRefreshToken = '${body['refresh'] ?? ''}';
    return (
      access: accessToken,
      refresh: newRefreshToken.isNotEmpty ? newRefreshToken : refreshToken,
    );
  }
}
