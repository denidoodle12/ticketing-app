import '../../../data/models/api_response.dart';
import '../models/auth_models.dart';
import '../models/user_model.dart';
import '../../../core/errors/exceptions.dart';

/// Mock datasource for Auth - simulates API responses
class AuthMockDatasource {
  // Simulated delay to mimic network request
  static const _mockDelay = Duration(milliseconds: 1500);

  // Mock user database
  final List<Map<String, dynamic>> _mockUsers = [
    {
      'id': 1,
      'email': 'test@example.com',
      'username': 'testuser',
      'password': 'test123',
      'full_name': 'Test User',
      'role': 'customer',
      'is_first_login': false,
    },
    {
      'id': 2,
      'email': 'deny@enigma.com',
      'username': 'denymobile',
      'password': 'deny123',
      'full_name': 'Deny Mobile Dev',
      'role': 'customer',
      'is_first_login': false,
    },
    {
      'id': 3,
      'email': 'newuser@example.com',
      'username': 'newuser',
      'password': 'Newuser123',
      'full_name': 'New User',
      'role': 'customer',
      'is_first_login': true,
    },
  ];

  /// Mock login with identifier (email or username)
  Future<ApiResponse<LoginResponse>> login(
    String identifier,
    String password,
  ) async {
    await Future.delayed(_mockDelay);

    // Find user by email or username
    final userMap = _mockUsers.firstWhere(
      (user) => user['email'] == identifier || user['username'] == identifier,
      orElse: () => {},
    );

    if (userMap.isEmpty) {
      throw UnauthorizedException('Invalid credentials');
    }

    // Check password
    if (userMap['password'] != password) {
      throw UnauthorizedException('Invalid credentials');
    }

    // Create user object
    final user = User(
      id: userMap['id'],
      fullName: userMap['full_name'],
      email: userMap['email'],
      username: userMap['username'],
      role: userMap['role'],
      isFirstLogin: userMap['is_first_login'] ?? false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Create login response
    final loginResponse = LoginResponse(
      token: 'mock_access_token_${userMap['id']}',
      accessToken: 'mock_access_token_${userMap['id']}',
      refreshToken: 'mock_refresh_token_${userMap['id']}',
      user: user,
    );

    return ApiResponse(
      success: true,
      message: 'Login successful',
      data: loginResponse,
    );
  }

  /// Mock register
  Future<ApiResponse<RegisterResponse>> register(
    String name,
    String email,
    String password,
  ) async {
    await Future.delayed(_mockDelay);

    // Check if email already exists
    final existingUser = _mockUsers.any(
      (user) => user['email'] == email,
    );

    if (existingUser) {
      throw ValidationException(
        'Email already registered',
        {'email': 'Email already registered'},
      );
    }

    // Simulate validation
    if (password.length < 6) {
      throw ValidationException(
        'Validation failed',
        {'password': 'Password must be at least 6 characters'},
      );
    }

    // Create new user ID
    final newUserId = 'user-${DateTime.now().millisecondsSinceEpoch}';

    // Add to mock database
    _mockUsers.add({
      'id': newUserId,
      'email': email,
      'password': password,
      'full_name': name,
      'role': 'customer',
      'phone_number': null,
      'avatar_url': null,
      'stat_tickets_created_count': 0,
      'stat_tickets_resolved_count': 0,
    });

    // Create register response
    final registerResponse = RegisterResponse(
      userId: newUserId,
      email: email,
      createdAt: DateTime.now(),
    );

    return ApiResponse(
      success: true,
      message: 'Registration successful. Please login.',
      data: registerResponse,
    );
  }

  /// Mock get user by ID
  Future<ApiResponse<User>> getUserById(String userId) async {
    await Future.delayed(_mockDelay);

    // Find user by ID
    final userMap = _mockUsers.firstWhere(
      (user) => user['id'] == userId,
      orElse: () => {},
    );

    if (userMap.isEmpty) {
      throw NotFoundException('User not found');
    }

    final user = User(
      id: userMap['id'],
      fullName: userMap['full_name'],
      email: userMap['email'],
      username: userMap['username'],
      role: userMap['role'],
      isFirstLogin: userMap['is_first_login'] ?? false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return ApiResponse(
      success: true,
      message: 'User retrieved successfully',
      data: user,
    );
  }

  /// Mock change password
  Future<ApiResponse<String>> changePassword({
    required String oldPassword,
    required String newPassword,
    required int userId,
  }) async {
    await Future.delayed(_mockDelay);

    // Find user by ID
    final userIndex = _mockUsers.indexWhere((user) => user['id'] == userId);

    if (userIndex == -1) {
      throw NotFoundException('User not found');
    }

    final userMap = _mockUsers[userIndex];

    // Check old password
    if (userMap['password'] != oldPassword) {
      throw ValidationException(
        'old password is incorrect',
        {'old_password': 'Old password is incorrect'},
      );
    }

    // Validate new password
    if (newPassword.length < 8) {
      throw ValidationException(
        'Validation failed',
        {'new_password': 'Password must be at least 8 characters'},
      );
    }

    // Update password and set is_first_login to false
    _mockUsers[userIndex]['password'] = newPassword;
    _mockUsers[userIndex]['is_first_login'] = false;

    return ApiResponse(
      success: true,
      message: 'password changed successfully',
      data: 'password changed successfully',
    );
  }
}
