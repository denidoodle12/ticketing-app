import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../models/auth_models.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/exceptions.dart';

/// Remote datasource for Auth - calls real API
class AuthRemoteDatasource {
  final Dio _dioAuth;
  final Dio _dioUser;

  AuthRemoteDatasource({
    Dio? dioAuth,
    Dio? dioUser,
  })  : _dioAuth = dioAuth ?? DioClient.authInstance,
        _dioUser = dioUser ?? DioClient.userInstance;

  /// Login with identifier (email or username) and password
  Future<LoginResponse> login(
    String identifier,
    String password,
  ) async {
    try {
      final response = await _dioAuth.post(
        ApiEndpoints.authLogin,
        data: {
          'identifier': identifier,
          'password': password,
        },
      );

      // API Response format: { "data": { "token": "...", "user": {...} } }
      if (response.data == null) {
        throw Exception('Response data is null');
      }

      final responseData = response.data as Map<String, dynamic>;

      if (!responseData.containsKey('data')) {
        throw Exception('Response does not contain "data" field');
      }

      final data = responseData['data'] as Map<String, dynamic>;
      final loginResponse = LoginResponse.fromJson(data);

      return loginResponse;
    } on DioException catch (e) {
      // Extract custom exception from DioException.error (set by ApiInterceptor)
      if (e.error is AppException) {
        throw e.error as AppException;
      }

      // If not a custom exception, handle DioException types

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw NetworkException('Connection timeout. Please try again.');
        case DioExceptionType.connectionError:
          throw NetworkException('No internet connection. Please check your network.');
        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode;
          final message = e.response?.data?['message'] ?? 'An error occurred';

          if (statusCode == 401) {
            throw UnauthorizedException(message);
          } else if (statusCode != null && statusCode >= 500) {
            throw ServerException(message);
          } else {
            throw ServerException(message);
          }
        default:
          throw ServerException('An unexpected error occurred');
      }
    } catch (e) {
      // If it's already our custom exception, rethrow
      if (e is AppException) {
        rethrow;
      }

      // Otherwise wrap in ServerException
      throw ServerException('An unexpected error occurred: ${e.toString()}');
    }
  }

  /// Get current user profile
  Future<User> getUserMe() async {
    final response = await _dioUser.get(
      ApiEndpoints.userMe,
    );

    // API Response format: { "data": { "id": 1, "email": "...", ... } }
    final data = response.data['data'] as Map<String, dynamic>;
    return User.fromJson(data);
  }
}
