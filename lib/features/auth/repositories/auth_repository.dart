import '../models/user_model.dart';
import '../../../data/datasources/local/local_storage.dart';
import '../datasources/auth_mock_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/forgot_password_remote_datasource.dart';
import '../../../core/constants/api_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../core/services/token_refresh_service.dart';

/// Result type for repository methods
class Result<T> {
  final T? data;
  final Failure? failure;

  Result.success(this.data) : failure = null;
  Result.failure(this.failure) : data = null;

  bool get isSuccess => data != null;
  bool get isFailure => failure != null;
}

/// Auth repository interface
abstract class AuthRepository {
  Future<Result<User>> login(String identifier, String password);
  Future<Result<String>> register(String name, String email, String password);
  Future<Result<String>> changePassword(String oldPassword, String newPassword);
  Future<Result<String>> requestPasswordReset(String email);
  Future<Result<bool>> verifyResetToken(String token);
  Future<Result<String>> resetPassword(String token, String newPassword);
  Future<bool> isLoggedIn();
  Future<void> logout();
  Future<User?> getCurrentUser();
  Future<void> setFirstLoginComplete();
  bool getIsFirstLogin();
}

/// Auth repository implementation
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource? _remoteDatasource;
  final AuthMockDatasource? _mockDatasource;
  final ForgotPasswordRemoteDatasource? _forgotPasswordDatasource;
  final LocalStorage _localStorage;

  AuthRepositoryImpl({
    AuthRemoteDatasource? remoteDatasource,
    AuthMockDatasource? mockDatasource,
    ForgotPasswordRemoteDatasource? forgotPasswordDatasource,
    required LocalStorage localStorage,
  }) : _remoteDatasource = remoteDatasource,
       _mockDatasource = mockDatasource,
       _forgotPasswordDatasource = forgotPasswordDatasource,
       _localStorage = localStorage;

  /// Login with identifier (email or username) and password
  @override
  Future<Result<User>> login(String identifier, String password) async {
    try {
      // Use mock or real datasource based on config
      if (ApiConfig.useMockData) {
        // Mock datasource returns ApiResponse<LoginResponse>
        final response = await _mockDatasource!.login(identifier, password);

        if (response.success && response.data != null) {
          final loginData = response.data!;
          final user = loginData.user;

          // Validate user role - only allow users
          if (user.role.toLowerCase() != AppConstants.allowedRole) {
            return Result.failure(
              ForbiddenFailure(
                'Access denied. This application is for users only.',
              ),
            );
          }

          // Save tokens
          await _localStorage.saveTokens(
            accessToken: loginData.accessToken ?? loginData.token,
            refreshToken: loginData.refreshToken ?? loginData.token,
          );

          // Save user data (including profile picture if available)
          await _localStorage.saveUserData(
            userId: user.id.toString(),
            email: user.email,
            username: user.username,
            fullName: user.name,
            role: user.role,
            isFirstLogin: user.isFirstLogin,
            lastName: user.lastName,
            phoneNumber: user.phoneNumber,
            profilePicture: user.profilePicture,
          );

          return Result.success(user);
        } else {
          return Result.failure(ServerFailure(response.message));
        }
      } else {
        // Real API datasource returns LoginResponse directly (not wrapped in ApiResponse)
        final loginResponse = await _remoteDatasource!.login(
          identifier,
          password,
        );
        final user = loginResponse.user;

        // Validate user role - only allow users
        if (user.role.toLowerCase() != AppConstants.allowedRole) {
          return Result.failure(
            ForbiddenFailure(
              'Access denied. This application is for users only.',
            ),
          );
        }

        // Save tokens (separate access + refresh)
        await _localStorage.saveTokens(
          accessToken: loginResponse.accessToken ?? loginResponse.token,
          refreshToken: loginResponse.refreshToken ?? loginResponse.token,
        );

        // Start proactive token refresh timer
        // This refreshes the token ~2 min before expiry (at ~13 min of 15 min)
        // preventing token expiry issues in Create Ticket, Chat WS, SSE.
        TokenRefreshService.instance.startProactiveRefresh(
          tokenLifetimeSeconds: loginResponse.expiresIn,
        );

        // Save user data (including profile picture if available)
        await _localStorage.saveUserData(
          userId: user.id.toString(),
          email: user.email,
          username: user.username,
          fullName: user.name,
          role: user.role,
          isFirstLogin: user.isFirstLogin,
          lastName: user.lastName,
          phoneNumber: user.phoneNumber,
          profilePicture: user.profilePicture,
        );

        return Result.success(user);
      }
    } on UnauthorizedException catch (e) {
      // Provide user-friendly message for login failure
      final message =
          e.message.toLowerCase().contains('unauthorized') ||
              e.message.toLowerCase().contains('invalid')
          ? 'Incorrect email/username or password.'
          : e.message;
      return Result.failure(UnauthorizedFailure(message));
    } on NetworkException catch (e) {
      return Result.failure(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } on ValidationException catch (e) {
      return Result.failure(ValidationFailure(e.message, e.errors));
    } catch (e) {
      return Result.failure(
        ServerFailure('An unexpected error has occurred. Please try again.'),
      );
    }
  }

  /// Register new user
  @override
  Future<Result<String>> register(
    String name,
    String email,
    String password,
  ) async {
    try {
      // Currently only mock registration is implemented
      // Real API registration endpoint will be added in Sprint 2
      final response = await _mockDatasource!.register(name, email, password);

      if (response.success && response.data != null) {
        return Result.success(response.message);
      } else {
        return Result.failure(ServerFailure(response.message));
      }
    } on ValidationException catch (e) {
      return Result.failure(ValidationFailure(e.message, e.errors));
    } on NetworkException catch (e) {
      return Result.failure(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(
        ServerFailure('An unexpected error occurred: ${e.toString()}'),
      );
    }
  }

  /// Check if user is logged in
  @override
  Future<bool> isLoggedIn() async {
    return await _localStorage.hasValidToken();
  }

  /// Logout user
  @override
  Future<void> logout() async {
    // Try to call logout API to blacklist tokens on server
    if (!ApiConfig.useMockData && _remoteDatasource != null) {
      try {
        final refreshToken = await _localStorage.getRefreshToken();
        await _remoteDatasource.logout(refreshToken);
      } catch (_) {
        // Ignore errors — clear local data regardless
      }
    }
    await _localStorage.clearAll();
  }

  /// Get current user from local storage
  @override
  Future<User?> getCurrentUser() async {
    final userId = _localStorage.getUserId();
    final email = _localStorage.getUserEmail();
    final username = _localStorage.getUserUsername();
    final fullName = _localStorage.getUserName();
    final lastName = _localStorage.getUserLastName();
    final phoneNumber = _localStorage.getUserPhoneNumber();
    final profilePicture = _localStorage.getUserProfilePicture();
    final role = _localStorage.getUserRole();
    final isFirstLogin = _localStorage.getUserIsFirstLogin();

    if (userId == null ||
        email == null ||
        username == null ||
        fullName == null ||
        role == null) {
      return null;
    }

    return User(
      id: int.parse(userId),
      email: email,
      username: username,
      name: fullName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      profilePicture: profilePicture,
      role: role,
      isFirstLogin: isFirstLogin,
    );
  }

  /// Change password
  @override
  Future<Result<String>> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    try {
      final message = await _remoteDatasource!.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      // After successful password change, set isFirstLogin to false
      await _localStorage.setUserIsFirstLogin(false);

      return Result.success(message);
    } on ValidationException catch (e) {
      return Result.failure(ValidationFailure(e.message, e.errors));
    } on UnauthorizedException catch (e) {
      return Result.failure(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Result.failure(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(
        ServerFailure('An unexpected error occurred: ${e.toString()}'),
      );
    }
  }

  /// Set first login complete
  @override
  Future<void> setFirstLoginComplete() async {
    await _localStorage.setUserIsFirstLogin(false);
  }

  /// Get is first login flag
  @override
  bool getIsFirstLogin() {
    return _localStorage.getUserIsFirstLogin();
  }

  /// Request password reset - sends 4-digit code to email
  @override
  Future<Result<String>> requestPasswordReset(String email) async {
    try {
      final message = await _forgotPasswordDatasource!.requestPasswordReset(
        email: email,
      );
      return Result.success(message);
    } on ValidationException catch (e) {
      return Result.failure(ValidationFailure(e.message, e.errors));
    } on NetworkException catch (e) {
      return Result.failure(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(
        ServerFailure('An unexpected error occurred: ${e.toString()}'),
      );
    }
  }

  /// Verify reset token - check if 4-digit code is valid
  @override
  Future<Result<bool>> verifyResetToken(String token) async {
    try {
      final isValid = await _forgotPasswordDatasource!.verifyResetToken(
        token: token,
      );
      return Result.success(isValid);
    } on ValidationException catch (e) {
      return Result.failure(ValidationFailure(e.message, e.errors));
    } on UnauthorizedException catch (e) {
      return Result.failure(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Result.failure(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(
        ServerFailure('An unexpected error occurred: ${e.toString()}'),
      );
    }
  }

  /// Reset password using the 4-digit code
  @override
  Future<Result<String>> resetPassword(String token, String newPassword) async {
    try {
      final message = await _forgotPasswordDatasource!.resetPassword(
        token: token,
        newPassword: newPassword,
      );
      return Result.success(message);
    } on ValidationException catch (e) {
      return Result.failure(ValidationFailure(e.message, e.errors));
    } on UnauthorizedException catch (e) {
      return Result.failure(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Result.failure(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(
        ServerFailure('An unexpected error occurred: ${e.toString()}'),
      );
    }
  }
}
