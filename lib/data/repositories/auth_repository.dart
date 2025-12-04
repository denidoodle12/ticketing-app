import '../models/user_model.dart';
import '../datasources/local/local_storage.dart';
import '../datasources/mock/auth_mock_datasource.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../../core/constants/app_constants.dart';
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
  Future<Result<User>> login(String email, String password);
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

  /// Login with email and password
  @override
  Future<Result<User>> login(String email, String password) async {
    try {
      // Use mock or real datasource based on app constants
      final response = AppConstants.useMockData
          ? await _mockDatasource!.login(email, password)
          : await _remoteDatasource!.login(email, password);

      if (response.success && response.data != null) {
        // Save tokens
        await _localStorage.saveTokens(
          accessToken: response.data!.accessToken,
          refreshToken: response.data!.refreshToken,
        );

        // Save user data
        final user = response.data!.user;
        await _localStorage.saveUserData(
          userId: user.id,
          email: user.email,
          fullName: user.fullName,
          role: user.role,
          avatarUrl: user.avatarUrl,
        );

        return Result.success(user);
      } else {
        return Result.failure(
          ServerFailure(response.message),
        );
      }
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

  /// Register new user
  @override
  Future<Result<String>> register(
    String name,
    String email,
    String password,
  ) async {
    try {
      // Use mock or real datasource based on app constants
      final response = AppConstants.useMockData
          ? await _mockDatasource!.register(name, email, password)
          : await _remoteDatasource!.register(name, email, password);

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
    final fullName = _localStorage.getUserFullName();
    final role = _localStorage.getUserRole();

    if (userId == null || email == null || fullName == null || role == null) {
      return null;
    }

    return User(
      id: userId,
      email: email,
      fullName: fullName,
      role: role,
      avatarUrl: _localStorage.getUserAvatarUrl(),
    );
  }
}
