/// Base exception class
abstract class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, [this.code]);

  @override
  String toString() => message;
}

/// Server exception (500, 502, 503, etc)
class ServerException extends AppException {
  ServerException([String message = 'Server error occurred'])
      : super(message, 'SERVER_ERROR');
}

/// Network exception (no internet, timeout)
class NetworkException extends AppException {
  NetworkException([String message = 'Network connection failed'])
      : super(message, 'NETWORK_ERROR');
}

/// Unauthorized exception (401)
class UnauthorizedException extends AppException {
  UnauthorizedException([String message = 'Unauthorized access'])
      : super(message, 'UNAUTHORIZED');
}

/// Forbidden exception (403)
class ForbiddenException extends AppException {
  ForbiddenException([String message = 'Access forbidden'])
      : super(message, 'FORBIDDEN');
}

/// Not found exception (404)
class NotFoundException extends AppException {
  NotFoundException([String message = 'Resource not found'])
      : super(message, 'NOT_FOUND');
}

/// Validation exception (422)
class ValidationException extends AppException {
  final Map<String, String>? errors;

  ValidationException(String message, [this.errors])
      : super(message, 'VALIDATION_ERROR');
}

/// Cache exception
class CacheException extends AppException {
  CacheException([String message = 'Cache error occurred'])
      : super(message, 'CACHE_ERROR');
}

/// Session refreshed exception
/// Thrown when token was refreshed but the original request cannot be retried
/// (e.g., FormData/file upload where the stream was already consumed)
class SessionRefreshedException extends AppException {
  SessionRefreshedException([
    String message = 'Session refreshed. Please try again.',
  ]) : super(message, 'SESSION_REFRESHED');
}
