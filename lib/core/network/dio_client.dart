import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../storage/secure_token_storage.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';
import 'request_cancelled_exception.dart';

class DioClient {
  DioClient({
    Dio? dio,
    SecureTokenStorage? tokenStorage,
    String? baseUrl,
    void Function()? onUnauthorized,
  }) : dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? ApiConfig.baseUrl,
                connectTimeout: ApiConfig.connectTimeout,
                receiveTimeout: ApiConfig.receiveTimeout,
                sendTimeout: ApiConfig.sendTimeout,
                responseType: ResponseType.json,
                headers: const {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    this.dio.interceptors.add(
          AuthInterceptor(
            tokenStorage ?? SecureTokenStorage(),
            this.dio,
            onUnauthorized: onUnauthorized,
          ),
        );
  }

  final Dio dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(
      dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(
      dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(
      dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(
      dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(
      dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> _guard<T>(Future<Response<T>> request) async {
    try {
      return await request;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) throw const RequestCancelledException();

      final mappedError = error.error;
      if (mappedError is ApiException) {
        throw mappedError;
      }

      // When the server doesn't return our JSON error envelope (e.g. a
      // proxy/platform error page, a crashed worker, or a dropped
      // connection), `_messageFromResponse` has nothing to read — fall back
      // to a friendly Vietnamese message instead of leaking Dio's internal
      // diagnostic string (e.g. "This exception was thrown because...") to
      // the user. The raw detail still goes to the debug log.
      final fromResponse = _messageFromResponse(error.response?.data);
      if (fromResponse == null) {
        debugPrint('[DioClient] ${error.type}: ${error.message}');
      }

      throw ApiException(
        message: fromResponse ?? _friendlyMessage(error),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  String _friendlyMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Kết nối mạng quá chậm. Vui lòng thử lại.';
      case DioExceptionType.connectionError:
        return 'Không có kết nối mạng. Vui lòng kiểm tra lại.';
      case DioExceptionType.badResponse:
        return 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return 'Có lỗi không xác định xảy ra. Vui lòng thử lại.';
    }
  }

  String? _messageFromResponse(Object? data) {
    if (data is! Map) {
      return null;
    }

    final message = data['message'];
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final firstValue = errors.values.first;
      if (firstValue is List && firstValue.isNotEmpty) {
        return _stringFromErrorValue(firstValue.first);
      }
      if (firstValue != null) {
        return _stringFromErrorValue(firstValue);
      }
    }

    if (message != null && '$message'.isNotEmpty) {
      return '$message';
    }

    return null;
  }

  String _stringFromErrorValue(Object? value) {
    if (value is Map) {
      final message = value['message'];
      final code = value['code'];
      if (message != null && '$message'.isNotEmpty) {
        return code == null || '$code'.isEmpty ? '$message' : '$message ($code)';
      }
    }
    return '$value';
  }
}
