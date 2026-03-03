import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/exceptions.dart';

/// API Endpoints for forgot password
class ForgotPasswordEndpoints {
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyResetToken = '/auth/verify-reset-token';
  static const String resetPassword = '/auth/reset-password';
}

/// Remote datasource for forgot password API calls
class ForgotPasswordRemoteDatasource {
  final Dio _dioAuth;

  ForgotPasswordRemoteDatasource({Dio? dioAuth})
    : _dioAuth = dioAuth ?? DioClient.authInstance;

  /// Request password reset - sends 4-digit code to email
  /// POST /auth/forgot-password
  Future<String> requestPasswordReset({required String email}) async {
    try {
      final response = await _dioAuth.post(
        ForgotPasswordEndpoints.forgotPassword,
        data: {'email': email},
      );

      // API always returns success message for security
      final message =
          response.data['message'] as String? ??
          'If your email is registered, you will receive a password reset code.';
      return message;
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error as AppException;
      }
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(
        'Failed to request password reset: ${e.toString()}',
      );
    }
  }

  /// Verify reset token - check if 4-digit code is valid
  /// POST /auth/verify-reset-token
  Future<bool> verifyResetToken({required String token}) async {
    try {
      final response = await _dioAuth.post(
        ForgotPasswordEndpoints.verifyResetToken,
        data: {'token': token},
      );

      return response.data['valid'] as bool? ?? false;
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error as AppException;
      }
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to verify reset token: ${e.toString()}');
    }
  }

  /// Reset password using the 4-digit code
  /// POST /auth/reset-password
  Future<String> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await _dioAuth.post(
        ForgotPasswordEndpoints.resetPassword,
        data: {'token': token, 'new_password': newPassword},
      );

      final message =
          response.data['message'] as String? ??
          'Password reset successfully. You can now login with your new password.';
      return message;
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error as AppException;
      }
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to reset password: ${e.toString()}');
    }
  }

  /// Common DioException handler
  AppException _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException('Connection timeout. Please try again.');
      case DioExceptionType.connectionError:
        return NetworkException(
          'No internet connection. Please check your network.',
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['message'] as String?;

        if (statusCode == 400) {
          return ValidationException(
            message ?? 'Invalid request. Please check your input.',
            {},
          );
        } else if (statusCode == 401) {
          return UnauthorizedException(message ?? 'Invalid or expired token.');
        } else if (statusCode != null && statusCode >= 500) {
          return ServerException(
            message ?? 'Server error. Please try again later.',
          );
        } else {
          return ServerException(
            message ?? 'An error occurred. Please try again.',
          );
        }
      default:
        return ServerException('An unexpected error occurred.');
    }
  }
}
