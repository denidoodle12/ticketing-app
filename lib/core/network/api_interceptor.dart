import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/storage_keys.dart';
import '../errors/exceptions.dart';
import '../services/token_refresh_service.dart';

/// API Interceptor with automatic token refresh.
///
/// When a 401 response is received:
/// 1. Skip refresh for auth endpoints (login, refresh)
/// 2. Try to get a new access token using the refresh token
/// 3. Retry the original request with the new token
/// 4. If refresh fails, clear tokens and throw UnauthorizedException
///
/// Special handling for FormData:
/// - FormData (file uploads) cannot be retried because the stream is consumed
/// - After refreshing the token, returns a special error asking user to retry
class ApiInterceptor extends Interceptor {
  final _secureStorage = const FlutterSecureStorage();
  final _tokenService = TokenRefreshService.instance;

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
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Handle successful response
    return handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
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
      case DioExceptionType.unknown:
        // Both connectionError and unknown can occur when device is offline
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
        final rawData = err.response?.data;
        // Safely extract message — handle both Map and String responses
        final data = rawData is Map<String, dynamic> ? rawData : null;
        final message = data?['message'] as String? ??
            (rawData is String ? rawData : null);

        if (statusCode == 401) {
          // Don't try refresh for auth endpoints (avoid infinite loop)
          final path = err.requestOptions.path;
          if (path.contains('/auth/login') ||
              path.contains('/auth/refresh') ||
              path.contains('/auth/logout')) {
            await _tokenService.clearTokens();
            return handler.reject(
              DioException(
                requestOptions: err.requestOptions,
                error: UnauthorizedException(
                  message ?? 'Unauthorized access',
                ),
              ),
            );
          }

          // Try to refresh the token using the centralized service
          final newToken = await _tokenService.refreshToken();

          if (newToken != null) {
            // Token refreshed — restart the proactive timer
            _tokenService.startProactiveRefresh();

            // Check if the original request has FormData
            // FormData streams are consumed and CANNOT be retried
            if (err.requestOptions.data is FormData) {
              // Token is refreshed but we can't retry the upload
              // Return a special error so the caller knows to retry
              return handler.reject(
                DioException(
                  requestOptions: err.requestOptions,
                  error: SessionRefreshedException(
                    'Session refreshed. Please try again.',
                  ),
                ),
              );
            }

            // Retry the original request with new token
            try {
              final retryResponse = await _retryRequest(
                err.requestOptions,
                newToken,
              );
              return handler.resolve(retryResponse);
            } catch (retryError) {
              // Retry failed — reject with original error
              return handler.reject(
                DioException(
                  requestOptions: err.requestOptions,
                  error: UnauthorizedException(
                    'Session expired. Please login again.',
                  ),
                ),
              );
            }
          } else {
            // Refresh failed — clear tokens and reject
            await _tokenService.clearTokens();
            return handler.reject(
              DioException(
                requestOptions: err.requestOptions,
                error: UnauthorizedException(
                  'Session expired. Please login again.',
                ),
              ),
            );
          }
        } else if (statusCode == 403) {
          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: ForbiddenException(message ?? 'Access forbidden'),
            ),
          );
        } else if (statusCode == 404) {
          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: NotFoundException(
                message ?? 'Resource not found',
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
                message ?? 'Validation failed',
                errorMap,
              ),
            ),
          );
        } else if (statusCode != null && statusCode >= 500) {
          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: ServerException(
                message ?? 'Server error occurred',
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

  /// Retry the original request with a new access token.
  /// Uses the full URI from the original request to avoid path duplication.
  Future<Response> _retryRequest(
    RequestOptions requestOptions,
    String newToken,
  ) async {
    // Use a fresh Dio instance without interceptors to avoid loop
    final dio = Dio(
      BaseOptions(
        connectTimeout: requestOptions.connectTimeout,
        receiveTimeout: requestOptions.receiveTimeout,
      ),
    );

    final options = Options(
      method: requestOptions.method,
      headers: {...requestOptions.headers, 'Authorization': 'Bearer $newToken'},
    );

    // Use the full URI to avoid base URL + path duplication
    return dio.request(
      requestOptions.uri.toString(),
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }
}
