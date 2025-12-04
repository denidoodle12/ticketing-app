/// Base failure class for error handling in repository layer
abstract class Failure {
  final String message;
  final String? code;

  const Failure(this.message, [this.code]);

  @override
  String toString() => message;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Failure &&
        other.message == message &&
        other.code == code;
  }

  @override
  int get hashCode => message.hashCode ^ code.hashCode;
}

/// Server failure
class ServerFailure extends Failure {
  const ServerFailure([String message = 'Server error occurred'])
      : super(message, 'SERVER_ERROR');
}

/// Network failure
class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'Network connection failed'])
      : super(message, 'NETWORK_ERROR');
}

/// Unauthorized failure
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([String message = 'Unauthorized access'])
      : super(message, 'UNAUTHORIZED');
}

/// Forbidden failure
class ForbiddenFailure extends Failure {
  const ForbiddenFailure([String message = 'Access forbidden'])
      : super(message, 'FORBIDDEN');
}

/// Not found failure
class NotFoundFailure extends Failure {
  const NotFoundFailure([String message = 'Resource not found'])
      : super(message, 'NOT_FOUND');
}

/// Validation failure
class ValidationFailure extends Failure {
  final Map<String, String>? errors;

  const ValidationFailure(String message, [this.errors])
      : super(message, 'VALIDATION_ERROR');
}

/// Cache failure
class CacheFailure extends Failure {
  const CacheFailure([String message = 'Cache error occurred'])
      : super(message, 'CACHE_ERROR');
}
