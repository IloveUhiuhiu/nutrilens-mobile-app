import 'package:dio/dio.dart';

import '../config/api_endpoints.dart';
import '../storage/secure_token_storage.dart';
import 'api_exception.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(
    this._tokenStorage,
    this._dio, {
    void Function()? onUnauthorized,
  }) : _onUnauthorized = onUnauthorized;

  final SecureTokenStorage _tokenStorage;
  final Dio _dio;
  final void Function()? _onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = await _tokenStorage.getAccessToken();

    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final responseData = err.response?.data;

    if (statusCode == 401) {
      final retried = err.requestOptions.extra['retried_after_refresh'] == true;
      final skipRefresh = err.requestOptions.extra['skip_auth_refresh'] == true;

      if (!retried && !skipRefresh) {
        final refreshed = await _refreshAccessToken();
        if (refreshed != null && refreshed.isNotEmpty) {
          try {
            final response =
                await _retryWithNewToken(err.requestOptions, refreshed);
            return handler.resolve(response);
          } catch (_) {
            await _tokenStorage.clearTokens();
          }
        }
      }

      await _tokenStorage.clearTokens();
      _onUnauthorized?.call();
      return handler.reject(
        err.copyWith(error: UnauthorizedException(data: responseData)),
      );
    }

    if (statusCode == 403) {
      return handler.reject(
        err.copyWith(error: ForbiddenException(data: responseData)),
      );
    }

    return handler.next(err);
  }

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.authTokenRefresh,
        data: {'refresh': refreshToken},
        options: Options(extra: {'skip_auth_refresh': true}),
      );
      final data = response.data?['data'];
      final accessToken = data is Map ? '${data['access'] ?? ''}' : '';
      if (accessToken.isEmpty) {
        return null;
      }
      await _tokenStorage.saveAccessToken(accessToken);
      return accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<Response<dynamic>> _retryWithNewToken(
    RequestOptions requestOptions,
    String accessToken,
  ) {
    final headers = Map<String, dynamic>.from(requestOptions.headers)
      ..['Authorization'] = 'Bearer $accessToken';
    final extra = Map<String, dynamic>.from(requestOptions.extra)
      ..['retried_after_refresh'] = true;

    return _dio.fetch<dynamic>(
      requestOptions.copyWith(headers: headers, extra: extra),
    );
  }
}
