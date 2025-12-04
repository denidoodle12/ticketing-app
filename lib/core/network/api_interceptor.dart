import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/storage_keys.dart';
import '../errors/exceptions.dart';

class ApiInterceptor extends Interceptor {
  final _secureStorage = const FlutterSecureStorage();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Add Authorization header if token exists
    final token = await _secureStorage.read(key: StorageKeys.accessToken);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    // Handle successful response
    return handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    // Handle different error types
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: NetworkException('Connection timeout. Please try again.'),
          ),
        );

      case DioExceptionType.connectionError:
        return handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: NetworkException(
              'No internet connection. Please check your network.',
            ),
          ),
        );

      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        final data = err.response?.data;

        if (statusCode == 401) {
          // Unauthorized - clear tokens and redirect to login
          _clearTokens();
          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: UnauthorizedException(
                data?['message'] ?? 'Unauthorized access',
              ),
            ),
          );
        } else if (statusCode == 403) {
          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: ForbiddenException(
                data?['message'] ?? 'Access forbidden',
              ),
            ),
          );
        } else if (statusCode == 404) {
          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: NotFoundException(
                data?['message'] ?? 'Resource not found',
              ),
            ),
          );
        } else if (statusCode == 422) {
          // Validation error
          final errors = data?['data']?['errors'];
          Map<String, String>? errorMap;

          if (errors != null && errors is List) {
            errorMap = {};
            for (var error in errors) {
              errorMap[error['field']] = error['message'];
            }
          }

          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: ValidationException(
                data?['message'] ?? 'Validation failed',
                errorMap,
              ),
            ),
          );
        } else if (statusCode != null && statusCode >= 500) {
          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: ServerException(
                data?['message'] ?? 'Server error occurred',
              ),
            ),
          );
        }
        break;

      default:
        break;
    }

    return handler.next(err);
  }

  Future<void> _clearTokens() async {
    await _secureStorage.delete(key: StorageKeys.accessToken);
    await _secureStorage.delete(key: StorageKeys.refreshToken);
  }
}
