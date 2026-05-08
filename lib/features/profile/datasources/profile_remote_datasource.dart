import 'package:dio/dio.dart';
import '../../auth/models/user_model.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/exceptions.dart';

class ProfileRemoteDatasource {
  final Dio _dioUser;

  ProfileRemoteDatasource({Dio? dioUser})
      : _dioUser = dioUser ?? DioClient.userInstance;

  /// Get current user profile
  Future<User> getProfile() async {
    try {
      final response = await _dioUser.get(ApiEndpoints.userMe);
      final data = response.data['data'] as Map<String, dynamic>;
      return User.fromJson(data);
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error as AppException;
      }
      _handleDioError(e);
      rethrow;
    }
  }

  /// Update user profile
  /// Note: PUT /users/me returns partial data, so we fetch full profile after update
  Future<User> updateProfile({
    String? name,
    String? lastName,
    String? phoneNumber,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (lastName != null) data['last_name'] = lastName;
      if (phoneNumber != null) data['phone_number'] = phoneNumber;

      // Update profile
      await _dioUser.put(
        ApiEndpoints.userMe,
        data: data,
      );

      // Fetch complete profile after update
      return await getProfile();
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error as AppException;
      }
      _handleDioError(e);
      rethrow;
    }
  }

  /// Upload profile picture
  /// Note: Response may not include all user fields, so we fetch full profile after upload
  Future<User> uploadProfilePicture(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });

      // Upload profile picture
      await _dioUser.post(
        ApiEndpoints.userMeProfilePicture,
        data: formData,
      );

      // Fetch complete profile after upload
      return await getProfile();
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error as AppException;
      }
      _handleDioError(e);
      rethrow;
    }
  }

  /// Delete profile picture
  Future<User> deleteProfilePicture() async {
    try {
      await _dioUser.delete(ApiEndpoints.userMeProfilePicture);

      // Fetch complete profile after deletion
      return await getProfile();
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error as AppException;
      }
      _handleDioError(e);
      rethrow;
    }
  }

  void _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        throw NetworkException('Connection timeout. Please try again.');
      case DioExceptionType.connectionError:
        throw NetworkException('No internet connection.');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['message'] ?? 'An error occurred';
        if (statusCode == 400) {
          throw ValidationException(message, {});
        } else if (statusCode == 401) {
          throw UnauthorizedException(message);
        } else {
          throw ServerException(message);
        }
      default:
        throw ServerException('An unexpected error occurred');
    }
  }
}
