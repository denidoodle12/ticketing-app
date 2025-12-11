import '../models/user_model.dart';
import '../datasources/local/local_storage.dart';
import '../datasources/mock/auth_mock_datasource.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../../core/constants/api_config.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';

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
  Future<bool> isLoggedIn();
  Future<void> logout();
  Future<User?> getCurrentUser();
}

/// Auth repository implementation
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource? _remoteDatasource;
  final AuthMockDatasource? _mockDatasource;
  final LocalStorage _localStorage;

  AuthRepositoryImpl({
    AuthRemoteDatasource? remoteDatasource,
    AuthMockDatasource? mockDatasource,
    required LocalStorage localStorage,
  })  : _remoteDatasource = remoteDatasource,
        _mockDatasource = mockDatasource,
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

          // Save tokens
          await _localStorage.saveTokens(
            accessToken: loginData.accessToken ?? loginData.token,
            refreshToken: loginData.refreshToken ?? loginData.token,
          );

          // Save user data
          final user = loginData.user;
          await _localStorage.saveUserData(
            userId: user.id.toString(),
            email: user.email,
            username: user.username,
            fullName: user.fullName,
            role: user.role,
          );

          return Result.success(user);
        } else {
          return Result.failure(ServerFailure(response.message));
        }
      } else {
        // Real API datasource returns LoginResponse directly (not wrapped in ApiResponse)
        final loginResponse = await _remoteDatasource!.login(identifier, password);

        // Save token (single token from API)
        await _localStorage.saveTokens(
          accessToken: loginResponse.token,
          refreshToken: loginResponse.token,
        );

        // Save user data
        final user = loginResponse.user;
        await _localStorage.saveUserData(
          userId: user.id.toString(),
          email: user.email,
          username: user.username,
          fullName: user.fullName,
          role: user.role,
        );

        return Result.success(user);
      }
    } on UnauthorizedException catch (e) {
      // Provide user-friendly message for login failure
      final message = e.message.toLowerCase().contains('unauthorized') ||
                      e.message.toLowerCase().contains('invalid')
          ? 'Email/username atau password salah'
          : e.message;
      return Result.failure(UnauthorizedFailure(message));
    } on NetworkException catch (e) {
      return Result.failure(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } on ValidationException catch (e) {
      return Result.failure(ValidationFailure(e.message, e.errors));
    } catch (e) {
      print('❌ REPOSITORY - Unexpected error: $e');
      print('❌ Error type: ${e.runtimeType}');
      return Result.failure(
        ServerFailure('Terjadi kesalahan yang tidak terduga. Silakan coba lagi.'),
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
        return Result.failure(
          ServerFailure(response.message),
        );
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
    await _localStorage.clearAll();
  }

  /// Get current user from local storage
  @override
  Future<User?> getCurrentUser() async {
    final userId = _localStorage.getUserId();
    final email = _localStorage.getUserEmail();
    final username = _localStorage.getUserUsername();
    final fullName = _localStorage.getUserFullName();
    final role = _localStorage.getUserRole();

    if (userId == null || email == null || username == null || fullName == null || role == null) {
      return null;
    }

    return User(
      id: int.parse(userId),
      email: email,
      username: username,
      fullName: fullName,
      role: role,
    );
  }
}
