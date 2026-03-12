import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/storage_keys.dart';
import '../constants/api_endpoints.dart';
import '../errors/exceptions.dart';

/// API Interceptor with automatic token refresh.
///
/// When a 401 response is received:
/// 1. Skip refresh for auth endpoints (login, refresh)
/// 2. Try to get a new access token using the refresh token
/// 3. Retry the original request with the new token
/// 4. If refresh fails, clear tokens and throw UnauthorizedException
class ApiInterceptor extends Interceptor {
  final _secureStorage = const FlutterSecureStorage();

  /// Mutex to prevent multiple simultaneous refresh calls
  static bool _isRefreshing = false;
  static Completer<String?>? _refreshCompleter;

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
            await _clearTokens();
            return handler.reject(
              DioException(
                requestOptions: err.requestOptions,
                error: UnauthorizedException(
                  message ?? 'Unauthorized access',
                ),
              ),
            );
          }

          // Try to refresh the token
          final newToken = await _tryRefreshToken();

          if (newToken != null) {
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
            await _clearTokens();
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

  /// Try to refresh the access token using the refresh token.
  /// Uses a mutex so that multiple concurrent 401s only trigger one refresh.
  Future<String?> _tryRefreshToken() async {
    // If already refreshing, wait for the result
    if (_isRefreshing && _refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    try {
      final refreshToken = await _secureStorage.read(
        key: StorageKeys.refreshToken,
      );

      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter!.complete(null);
        return null;
      }

      // Use a fresh Dio instance WITHOUT interceptors to avoid infinite loop
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiEndpoints.authBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final response = await dio.post(
        ApiEndpoints.authRefresh,
        data: {'refresh_token': refreshToken},
      );

      final responseData = response.data as Map<String, dynamic>;
      final data = responseData['data'] as Map<String, dynamic>?;
      final newAccessToken = data?['access_token'] as String?;

      if (newAccessToken != null) {
        // Save the new access token
        await _secureStorage.write(
          key: StorageKeys.accessToken,
          value: newAccessToken,
        );

        _refreshCompleter!.complete(newAccessToken);
        return newAccessToken;
      } else {
        _refreshCompleter!.complete(null);
        return null;
      }
    } catch (e) {
      // Refresh failed — token is truly expired
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  /// Retry the original request with a new access token
  Future<Response> _retryRequest(
    RequestOptions requestOptions,
    String newToken,
  ) async {
    // Use a fresh Dio instance to avoid interceptor loop
    final dio = Dio(
      BaseOptions(
        baseUrl: requestOptions.baseUrl,
        connectTimeout: requestOptions.connectTimeout,
        receiveTimeout: requestOptions.receiveTimeout,
      ),
    );

    final options = Options(
      method: requestOptions.method,
      headers: {...requestOptions.headers, 'Authorization': 'Bearer $newToken'},
    );

    return dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  Future<void> _clearTokens() async {
    await _secureStorage.delete(key: StorageKeys.accessToken);
    await _secureStorage.delete(key: StorageKeys.refreshToken);
  }
}
