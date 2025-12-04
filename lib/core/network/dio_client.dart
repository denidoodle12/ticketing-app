import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../constants/app_constants.dart';
import '../constants/api_endpoints.dart';
import 'api_interceptor.dart';

class DioClient {
  static Dio? _dioAuth;
  static Dio? _dioUser;

  /// Get Dio instance for Auth Service
  static Dio get authInstance {
    _dioAuth ??= _createDio(ApiEndpoints.authBaseUrl);
    return _dioAuth!;
  }

  /// Get Dio instance for User Service
  static Dio get userInstance {
    _dioUser ??= _createDio(ApiEndpoints.userBaseUrl);
    return _dioUser!;
  }

  /// Create Dio instance with base configuration
  static Dio _createDio(String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(
          milliseconds: AppConstants.connectionTimeoutMs,
        ),
        receiveTimeout: const Duration(
          milliseconds: AppConstants.receiveTimeoutMs,
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors
    dio.interceptors.add(ApiInterceptor());

    // Add pretty logger for development
    if (AppConstants.useMockData) {
      dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
        ),
      );
    }

    return dio;
  }

  /// Reset all Dio instances (useful for logout)
  static void reset() {
    _dioAuth = null;
    _dioUser = null;
  }
}
