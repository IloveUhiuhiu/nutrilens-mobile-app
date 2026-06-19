class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.statusCode,
    this.data,
  });

  final String message;
  final int? statusCode;
  final Object? data;

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, message: $message)';
  }
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException({super.data})
      : super(
          message: 'Unauthorized. Please sign in again.',
          statusCode: 401,
        );
}

class ForbiddenException extends ApiException {
  const ForbiddenException({super.data})
      : super(
          message: 'Forbidden. You do not have permission.',
          statusCode: 403,
        );
}

class ServerException extends ApiException {
  const ServerException({super.data})
      : super(
          message: 'Internal server error. Please try again later.',
          statusCode: 500,
        );
}
