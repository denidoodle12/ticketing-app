import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_model.dart';
import '../../models/auth_models.dart';
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
    print('════════════════════════════════════════');
    print('🚀 DATASOURCE - Starting login request');
    print('📧 Identifier: $identifier');
    print('🌐 URL: ${ApiEndpoints.authLogin}');

    try {
      final response = await _dioAuth.post(
        ApiEndpoints.authLogin,
        data: {
          'identifier': identifier,
          'password': password,
        },
      );

      print('✅ DATASOURCE - Response received');
      print('📊 Status Code: ${response.statusCode}');
      print('📦 Response Data Type: ${response.data.runtimeType}');
      print('📦 Response Data: ${response.data}');

      // API Response format: { "data": { "token": "...", "user": {...} } }
      if (response.data == null) {
        print('❌ DATASOURCE - Response data is NULL!');
        throw Exception('Response data is null');
      }

      final responseData = response.data as Map<String, dynamic>;
      print('🔍 DATASOURCE - Response keys: ${responseData.keys}');

      if (!responseData.containsKey('data')) {
        print('❌ DATASOURCE - Missing "data" field!');
        print('❌ Available keys: ${responseData.keys}');
        throw Exception('Response does not contain "data" field');
      }

      final data = responseData['data'] as Map<String, dynamic>;
      print('🔍 DATASOURCE - Data field keys: ${data.keys}');
      print('🔍 DATASOURCE - Token: ${data['token']}');
      print('🔍 DATASOURCE - User: ${data['user']}');

      print('🔄 DATASOURCE - Parsing LoginResponse...');
      final loginResponse = LoginResponse.fromJson(data);
      print('✅ DATASOURCE - LoginResponse parsed successfully');
      print('👤 User ID: ${loginResponse.user.id}');
      print('👤 User Email: ${loginResponse.user.email}');
      print('════════════════════════════════════════');

      return loginResponse;
    } on DioException catch (e, stackTrace) {
      print('════════════════════════════════════════');
      print('❌❌❌ DATASOURCE ERROR ❌❌❌');
      print('Error Type: ${e.runtimeType}');
      print('DioException Type: ${e.type}');
      print('Error Message: $e');
      print('Error Object: ${e.error}');
      print('Error Object Type: ${e.error.runtimeType}');

      // Extract custom exception from DioException.error (set by ApiInterceptor)
      if (e.error is AppException) {
        print('🔄 DATASOURCE - Throwing extracted exception: ${e.error}');
        print('════════════════════════════════════════');
        throw e.error as AppException;
      }

      // If not a custom exception, handle DioException types
      print('⚠️ DATASOURCE - No custom exception found, handling DioException type');
      print('Stack Trace:');
      print(stackTrace);
      print('════════════════════════════════════════');

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
    } catch (e, stackTrace) {
      print('════════════════════════════════════════');
      print('❌❌❌ DATASOURCE UNEXPECTED ERROR ❌❌❌');
      print('Error Type: ${e.runtimeType}');
      print('Error Message: $e');
      print('Stack Trace:');
      print(stackTrace);
      print('════════════════════════════════════════');

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
