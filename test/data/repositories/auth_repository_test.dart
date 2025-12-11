import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:ticketing_app/data/repositories/auth_repository.dart';
import 'package:ticketing_app/data/datasources/remote/auth_remote_datasource.dart';
import 'package:ticketing_app/data/datasources/local/local_storage.dart';
import 'package:ticketing_app/data/models/user_model.dart';
import 'package:ticketing_app/data/models/auth_models.dart';
import 'package:ticketing_app/core/errors/exceptions.dart';
import 'package:ticketing_app/core/errors/failures.dart';

import 'auth_repository_test.mocks.dart';

@GenerateMocks([AuthRemoteDatasource, LocalStorage])
void main() {
  late AuthRepositoryImpl repository;
  late MockAuthRemoteDatasource mockRemoteDatasource;
  late MockLocalStorage mockLocalStorage;

  setUp(() {
    mockRemoteDatasource = MockAuthRemoteDatasource();
    mockLocalStorage = MockLocalStorage();
    repository = AuthRepositoryImpl(
      remoteDatasource: mockRemoteDatasource,
      localStorage: mockLocalStorage,
    );
  });

  group('AuthRepository - login', () {
    const testIdentifier = 'admin_one';
    const testPassword = 'CustomerPass123!';

    final testUser = User(
      id: 1,
      email: 'customer1@test.com',
      username: 'admin_one',
      fullName: 'Admin One',
      role: 'customer',
    );

    final testLoginResponse = LoginResponse(
      token: 'test_token_123',
      user: testUser,
    );

    test('should return User when login is successful', () async {
      // Arrange
      when(mockRemoteDatasource.login(testIdentifier, testPassword))
          .thenAnswer((_) async => testLoginResponse);

      when(mockLocalStorage.saveTokens(
        accessToken: anyNamed('accessToken'),
        refreshToken: anyNamed('refreshToken'),
      )).thenAnswer((_) async => Future.value());

      when(mockLocalStorage.saveUserData(
        userId: anyNamed('userId'),
        email: anyNamed('email'),
        username: anyNamed('username'),
        fullName: anyNamed('fullName'),
        role: anyNamed('role'),
      )).thenAnswer((_) async => Future.value());

      // Act
      final result = await repository.login(testIdentifier, testPassword);

      // Assert
      expect(result.isSuccess, true);
      expect(result.data, testUser);
      expect(result.data?.username, 'admin_one');
      expect(result.data?.email, 'customer1@test.com');

      // Verify interactions
      verify(mockRemoteDatasource.login(testIdentifier, testPassword)).called(1);
      verify(mockLocalStorage.saveTokens(
        accessToken: testLoginResponse.token,
        refreshToken: testLoginResponse.token,
      )).called(1);
      verify(mockLocalStorage.saveUserData(
        userId: testUser.id.toString(),
        email: testUser.email,
        username: testUser.username,
        fullName: testUser.fullName,
        role: testUser.role,
      )).called(1);
    });

    test('should return UnauthorizedFailure when credentials are wrong', () async {
      // Arrange
      when(mockRemoteDatasource.login(testIdentifier, testPassword))
          .thenThrow(UnauthorizedException('Invalid credentials'));

      // Act
      final result = await repository.login(testIdentifier, testPassword);

      // Assert
      expect(result.isFailure, true);
      expect(result.failure, isA<UnauthorizedFailure>());
      expect(result.failure?.message, 'Email/username atau password salah');

      // Verify no token was saved
      verifyNever(mockLocalStorage.saveTokens(
        accessToken: anyNamed('accessToken'),
        refreshToken: anyNamed('refreshToken'),
      ));
    });

    test('should return UnauthorizedFailure with custom message when unauthorized', () async {
      // Arrange
      when(mockRemoteDatasource.login(testIdentifier, testPassword))
          .thenThrow(UnauthorizedException('User not found'));

      // Act
      final result = await repository.login(testIdentifier, testPassword);

      // Assert
      expect(result.isFailure, true);
      expect(result.failure, isA<UnauthorizedFailure>());
      // Custom message is preserved if it doesn't contain 'unauthorized' or 'invalid'
      expect(result.failure?.message, 'User not found');
    });

    test('should return NetworkFailure when there is no internet connection', () async {
      // Arrange
      when(mockRemoteDatasource.login(testIdentifier, testPassword))
          .thenThrow(NetworkException('No internet connection'));

      // Act
      final result = await repository.login(testIdentifier, testPassword);

      // Assert
      expect(result.isFailure, true);
      expect(result.failure, isA<NetworkFailure>());
      expect(result.failure?.message, 'No internet connection');
    });

    test('should return ServerFailure when server returns 500 error', () async {
      // Arrange
      when(mockRemoteDatasource.login(testIdentifier, testPassword))
          .thenThrow(ServerException('Internal server error'));

      // Act
      final result = await repository.login(testIdentifier, testPassword);

      // Assert
      expect(result.isFailure, true);
      expect(result.failure, isA<ServerFailure>());
      expect(result.failure?.message, 'Internal server error');
    });

    test('should return ServerFailure when unexpected error occurs', () async {
      // Arrange
      when(mockRemoteDatasource.login(testIdentifier, testPassword))
          .thenThrow(Exception('Unexpected error'));

      // Act
      final result = await repository.login(testIdentifier, testPassword);

      // Assert
      expect(result.isFailure, true);
      expect(result.failure, isA<ServerFailure>());
      expect(result.failure?.message, contains('Terjadi kesalahan'));
    });

    test('should save token to local storage when login is successful', () async {
      // Arrange
      when(mockRemoteDatasource.login(testIdentifier, testPassword))
          .thenAnswer((_) async => testLoginResponse);

      when(mockLocalStorage.saveTokens(
        accessToken: anyNamed('accessToken'),
        refreshToken: anyNamed('refreshToken'),
      )).thenAnswer((_) async => Future.value());

      when(mockLocalStorage.saveUserData(
        userId: anyNamed('userId'),
        email: anyNamed('email'),
        username: anyNamed('username'),
        fullName: anyNamed('fullName'),
        role: anyNamed('role'),
      )).thenAnswer((_) async => Future.value());

      // Act
      await repository.login(testIdentifier, testPassword);

      // Assert
      verify(mockLocalStorage.saveTokens(
        accessToken: testLoginResponse.token,
        refreshToken: testLoginResponse.token,
      )).called(1);
    });

    test('should save user data to local storage when login is successful', () async {
      // Arrange
      when(mockRemoteDatasource.login(testIdentifier, testPassword))
          .thenAnswer((_) async => testLoginResponse);

      when(mockLocalStorage.saveTokens(
        accessToken: anyNamed('accessToken'),
        refreshToken: anyNamed('refreshToken'),
      )).thenAnswer((_) async => Future.value());

      when(mockLocalStorage.saveUserData(
        userId: anyNamed('userId'),
        email: anyNamed('email'),
        username: anyNamed('username'),
        fullName: anyNamed('fullName'),
        role: anyNamed('role'),
      )).thenAnswer((_) async => Future.value());

      // Act
      await repository.login(testIdentifier, testPassword);

      // Assert
      verify(mockLocalStorage.saveUserData(
        userId: testUser.id.toString(),
        email: testUser.email,
        username: testUser.username,
        fullName: testUser.fullName,
        role: testUser.role,
      )).called(1);
    });
  });

  group('AuthRepository - isLoggedIn', () {
    test('should return true when valid token exists', () async {
      // Arrange
      when(mockLocalStorage.hasValidToken()).thenAnswer((_) async => true);

      // Act
      final result = await repository.isLoggedIn();

      // Assert
      expect(result, true);
      verify(mockLocalStorage.hasValidToken()).called(1);
    });

    test('should return false when no token exists', () async {
      // Arrange
      when(mockLocalStorage.hasValidToken()).thenAnswer((_) async => false);

      // Act
      final result = await repository.isLoggedIn();

      // Assert
      expect(result, false);
      verify(mockLocalStorage.hasValidToken()).called(1);
    });
  });

  group('AuthRepository - logout', () {
    test('should clear all data from local storage', () async {
      // Arrange
      when(mockLocalStorage.clearAll()).thenAnswer((_) async => Future.value());

      // Act
      await repository.logout();

      // Assert
      verify(mockLocalStorage.clearAll()).called(1);
    });
  });

  group('AuthRepository - getCurrentUser', () {
    test('should return User when all user data exists in local storage', () async {
      // Arrange
      when(mockLocalStorage.getUserId()).thenReturn('1');
      when(mockLocalStorage.getUserEmail()).thenReturn('test@test.com');
      when(mockLocalStorage.getUserUsername()).thenReturn('testuser');
      when(mockLocalStorage.getUserFullName()).thenReturn('Test User');
      when(mockLocalStorage.getUserRole()).thenReturn('customer');

      // Act
      final result = await repository.getCurrentUser();

      // Assert
      expect(result, isNotNull);
      expect(result?.id, 1);
      expect(result?.email, 'test@test.com');
      expect(result?.username, 'testuser');
      expect(result?.fullName, 'Test User');
      expect(result?.role, 'customer');
    });

    test('should return null when user data is incomplete', () async {
      // Arrange
      when(mockLocalStorage.getUserId()).thenReturn(null);
      when(mockLocalStorage.getUserEmail()).thenReturn('test@test.com');
      when(mockLocalStorage.getUserUsername()).thenReturn('testuser');
      when(mockLocalStorage.getUserFullName()).thenReturn('Test User');
      when(mockLocalStorage.getUserRole()).thenReturn('customer');

      // Act
      final result = await repository.getCurrentUser();

      // Assert
      expect(result, null);
    });

    test('should return null when no user data exists', () async {
      // Arrange
      when(mockLocalStorage.getUserId()).thenReturn(null);
      when(mockLocalStorage.getUserEmail()).thenReturn(null);
      when(mockLocalStorage.getUserUsername()).thenReturn(null);
      when(mockLocalStorage.getUserFullName()).thenReturn(null);
      when(mockLocalStorage.getUserRole()).thenReturn(null);

      // Act
      final result = await repository.getCurrentUser();

      // Assert
      expect(result, null);
    });
  });
}
