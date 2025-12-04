import 'package:dio/dio.dart';
import '../../models/api_response.dart';
import '../../models/auth_models.dart';
import '../../models/user_model.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

/// Remote datasource for Auth - calls real API
class AuthRemoteDatasource {
  final Dio _dioAuth;
  final Dio _dioUser;

  AuthRemoteDatasource({
    Dio? dioAuth,
    Dio? dioUser,
  })  : _dioAuth = dioAuth ?? DioClient.authInstance,
        _dioUser = dioUser ?? DioClient.userInstance;

  /// Login with email and password
  Future<ApiResponse<LoginResponse>> login(
    String email,
    String password,
  ) async {
    final response = await _dioAuth.post(
      ApiEndpoints.authLogin,
      data: LoginRequest(email: email, password: password).toJson(),
    );

    return ApiResponse.fromJson(
      response.data,
      (json) => LoginResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Register new user
  Future<ApiResponse<RegisterResponse>> register(
    String name,
    String email,
    String password,
  ) async {
    final response = await _dioAuth.post(
      ApiEndpoints.authRegister,
      data: RegisterRequest(
        name: name,
        email: email,
        password: password,
        role: 'customer',
      ).toJson(),
    );

    return ApiResponse.fromJson(
      response.data,
      (json) => RegisterResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Get user by ID
  Future<ApiResponse<User>> getUserById(String userId) async {
    final response = await _dioUser.get(
      ApiEndpoints.userById(userId),
    );

    return ApiResponse.fromJson(
      response.data,
      (json) => User.fromJson(json as Map<String, dynamic>),
    );
  }
}
