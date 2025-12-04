import '../../models/api_response.dart';
import '../../models/auth_models.dart';
import '../../models/user_model.dart';
import '../../../core/errors/exceptions.dart';

/// Mock datasource for Auth - simulates API responses
class AuthMockDatasource {
  // Simulated delay to mimic network request
  static const _mockDelay = Duration(milliseconds: 1500);

  // Mock user database
  final List<Map<String, dynamic>> _mockUsers = [
    {
      'id': 'user-001',
      'email': 'test@example.com',
      'password': 'test123',
      'full_name': 'Test User',
      'role': 'customer',
      'phone_number': '081234567890',
      'avatar_url': null,
      'stat_tickets_created_count': 5,
      'stat_tickets_resolved_count': 3,
    },
    {
      'id': 'user-002',
      'email': 'deny@enigma.com',
      'password': 'deny123',
      'full_name': 'Deny Mobile Dev',
      'role': 'customer',
      'phone_number': '081987654321',
      'avatar_url': null,
      'stat_tickets_created_count': 10,
      'stat_tickets_resolved_count': 7,
    },
  ];

  /// Mock login
  Future<ApiResponse<LoginResponse>> login(
    String email,
    String password,
  ) async {
    await Future.delayed(_mockDelay);

    // Find user by email
    final userMap = _mockUsers.firstWhere(
      (user) => user['email'] == email,
      orElse: () => {},
    );

    if (userMap.isEmpty) {
      throw UnauthorizedException('Invalid email or password');
    }

    // Check password
    if (userMap['password'] != password) {
      throw UnauthorizedException('Invalid email or password');
    }

    // Create user object
    final user = User(
      id: userMap['id'],
      fullName: userMap['full_name'],
      email: userMap['email'],
      phoneNumber: userMap['phone_number'],
      avatarUrl: userMap['avatar_url'],
      role: userMap['role'],
      statTicketsCreatedCount: userMap['stat_tickets_created_count'],
      statTicketsResolvedCount: userMap['stat_tickets_resolved_count'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Create login response
    final loginResponse = LoginResponse(
      accessToken: 'mock_access_token_${userMap['id']}',
      refreshToken: 'mock_refresh_token_${userMap['id']}',
      expiresIn: 3600,
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
      phoneNumber: userMap['phone_number'],
      avatarUrl: userMap['avatar_url'],
      role: userMap['role'],
      statTicketsCreatedCount: userMap['stat_tickets_created_count'],
      statTicketsResolvedCount: userMap['stat_tickets_resolved_count'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return ApiResponse(
      success: true,
      message: 'User retrieved successfully',
      data: user,
    );
  }
}
