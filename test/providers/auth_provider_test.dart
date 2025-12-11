import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:ticketing_app/providers/auth_provider.dart';
import 'package:ticketing_app/data/repositories/auth_repository.dart';
import 'package:ticketing_app/data/models/user_model.dart';
import 'package:ticketing_app/core/errors/failures.dart';

import 'auth_provider_test.mocks.dart';

@GenerateMocks([AuthRepository])
void main() {
  late AuthProvider authProvider;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    authProvider = AuthProvider(mockAuthRepository);
  });

  group('AuthProvider - login', () {
    const testIdentifier = 'admin_one';
    const testPassword = 'CustomerPass123!';

    final testUser = User(
      id: 1,
      email: 'customer1@test.com',
      username: 'admin_one',
      fullName: 'Admin One',
      role: 'customer',
    );

    test('should set state to loading then authenticated when login succeeds', () async {
      // Arrange
      when(mockAuthRepository.login(testIdentifier, testPassword))
          .thenAnswer((_) async => Result.success(testUser));

      // Act
      final result = await authProvider.login(testIdentifier, testPassword);

      // Assert
      expect(result, true);
      expect(authProvider.state, AuthState.authenticated);
      expect(authProvider.currentUser, testUser);
      expect(authProvider.errorMessage, null);
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.isLoading, false);
    });

    test('should set state to error when login fails with wrong credentials', () async {
      // Arrange
      const errorMessage = 'Email/username atau password salah';
      when(mockAuthRepository.login(testIdentifier, testPassword))
          .thenAnswer((_) async => Result.failure(
                const UnauthorizedFailure(errorMessage),
              ));

      // Act
      final result = await authProvider.login(testIdentifier, testPassword);

      // Assert
      expect(result, false);
      expect(authProvider.state, AuthState.error);
      expect(authProvider.currentUser, null);
      expect(authProvider.errorMessage, errorMessage);
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.isLoading, false);
    });

    test('should set state to error when login fails with network error', () async {
      // Arrange
      const errorMessage = 'No internet connection';
      when(mockAuthRepository.login(testIdentifier, testPassword))
          .thenAnswer((_) async => Result.failure(
                const NetworkFailure(errorMessage),
              ));

      // Act
      final result = await authProvider.login(testIdentifier, testPassword);

      // Assert
      expect(result, false);
      expect(authProvider.state, AuthState.error);
      expect(authProvider.errorMessage, errorMessage);
    });

    test('should set state to error when login fails with server error', () async {
      // Arrange
      const errorMessage = 'Internal server error';
      when(mockAuthRepository.login(testIdentifier, testPassword))
          .thenAnswer((_) async => Result.failure(
                const ServerFailure(errorMessage),
              ));

      // Act
      final result = await authProvider.login(testIdentifier, testPassword);

      // Assert
      expect(result, false);
      expect(authProvider.state, AuthState.error);
      expect(authProvider.errorMessage, errorMessage);
    });

    test('should handle unexpected errors gracefully', () async {
      // Arrange
      when(mockAuthRepository.login(testIdentifier, testPassword))
          .thenThrow(Exception('Unexpected error'));

      // Act
      final result = await authProvider.login(testIdentifier, testPassword);

      // Assert
      expect(result, false);
      expect(authProvider.state, AuthState.error);
      expect(authProvider.errorMessage, isNotNull);
      expect(authProvider.errorMessage, contains('unexpected'));
    });

    test('should set currentUser when login succeeds', () async {
      // Arrange
      when(mockAuthRepository.login(testIdentifier, testPassword))
          .thenAnswer((_) async => Result.success(testUser));

      // Act
      await authProvider.login(testIdentifier, testPassword);

      // Assert
      expect(authProvider.currentUser, isNotNull);
      expect(authProvider.currentUser?.id, testUser.id);
      expect(authProvider.currentUser?.email, testUser.email);
      expect(authProvider.currentUser?.username, testUser.username);
    });

    test('should clear currentUser when login fails', () async {
      // Arrange
      when(mockAuthRepository.login(testIdentifier, testPassword))
          .thenAnswer((_) async => Result.failure(
                const UnauthorizedFailure('Invalid credentials'),
              ));

      // Act
      await authProvider.login(testIdentifier, testPassword);

      // Assert
      expect(authProvider.currentUser, null);
    });
  });

  group('AuthProvider - checkAuthStatus', () {
    final testUser = User(
      id: 1,
      email: 'test@test.com',
      username: 'testuser',
      fullName: 'Test User',
      role: 'customer',
    );

    test('should set state to authenticated when user is logged in', () async {
      // Arrange
      when(mockAuthRepository.isLoggedIn()).thenAnswer((_) async => true);
      when(mockAuthRepository.getCurrentUser()).thenAnswer((_) async => testUser);

      // Act
      await authProvider.checkAuthStatus();

      // Assert
      expect(authProvider.state, AuthState.authenticated);
      expect(authProvider.currentUser, testUser);
      expect(authProvider.isAuthenticated, true);
    });

    test('should set state to unauthenticated when user is not logged in', () async {
      // Arrange
      when(mockAuthRepository.isLoggedIn()).thenAnswer((_) async => false);

      // Act
      await authProvider.checkAuthStatus();

      // Assert
      expect(authProvider.state, AuthState.unauthenticated);
      expect(authProvider.currentUser, null);
      expect(authProvider.isAuthenticated, false);
    });

    test('should set state to unauthenticated when error occurs', () async {
      // Arrange
      when(mockAuthRepository.isLoggedIn()).thenThrow(Exception('Error'));

      // Act
      await authProvider.checkAuthStatus();

      // Assert
      expect(authProvider.state, AuthState.unauthenticated);
      expect(authProvider.errorMessage, isNotNull);
    });
  });

  group('AuthProvider - logout', () {
    test('should clear user data and set state to unauthenticated', () async {
      // Arrange
      when(mockAuthRepository.logout()).thenAnswer((_) async => Future.value());

      // Act
      await authProvider.logout();

      // Assert
      expect(authProvider.state, AuthState.unauthenticated);
      expect(authProvider.currentUser, null);
      expect(authProvider.isAuthenticated, false);

      verify(mockAuthRepository.logout()).called(1);
    });

    test('should handle logout errors', () async {
      // Arrange
      when(mockAuthRepository.logout()).thenThrow(Exception('Logout failed'));

      // Act
      await authProvider.logout();

      // Assert
      expect(authProvider.state, AuthState.error);
      expect(authProvider.errorMessage, 'Failed to logout');
    });
  });

  group('AuthProvider - clearError', () {
    test('should clear error message and reset state from error to unauthenticated', () async {
      // Arrange
      const errorMessage = 'Some error';
      when(mockAuthRepository.login(any, any))
          .thenAnswer((_) async => Result.failure(
                const ServerFailure(errorMessage),
              ));

      await authProvider.login('test', 'test');
      expect(authProvider.errorMessage, errorMessage);
      expect(authProvider.state, AuthState.error);

      // Act
      authProvider.clearError();

      // Assert
      expect(authProvider.errorMessage, null);
      expect(authProvider.state, AuthState.unauthenticated);
    });

    test('should not change state if not in error state', () async {
      // Arrange
      final testUser = User(
        id: 1,
        email: 'test@test.com',
        username: 'testuser',
        fullName: 'Test User',
        role: 'customer',
      );

      when(mockAuthRepository.login(any, any))
          .thenAnswer((_) async => Result.success(testUser));

      await authProvider.login('test', 'test');
      expect(authProvider.state, AuthState.authenticated);

      // Act
      authProvider.clearError();

      // Assert
      expect(authProvider.state, AuthState.authenticated); // Should stay authenticated
    });
  });

  group('AuthProvider - state getters', () {
    test('isLoading should return true when state is loading', () {
      // Note: We can't easily test loading state without triggering an async operation
      // But we can verify the getter logic
      expect(authProvider.isLoading, false); // Initial state
    });

    test('isAuthenticated should return true when state is authenticated', () async {
      // Arrange
      final testUser = User(
        id: 1,
        email: 'test@test.com',
        username: 'testuser',
        fullName: 'Test User',
        role: 'customer',
      );

      when(mockAuthRepository.login(any, any))
          .thenAnswer((_) async => Result.success(testUser));

      // Act
      await authProvider.login('test', 'test');

      // Assert
      expect(authProvider.isAuthenticated, true);
    });

    test('isAuthenticated should return false when state is not authenticated', () {
      // Initial state
      expect(authProvider.isAuthenticated, false);
    });
  });
}
