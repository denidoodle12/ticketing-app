import 'user_model.dart';

// ==================== REQUEST MODELS ====================

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() {
    return {'email': email, 'password': password};
  }
}

class RegisterRequest {
  final String name;
  final String email;
  final String password;
  final String? role;

  RegisterRequest({
    required this.name,
    required this.email,
    required this.password,
    this.role,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'password': password,
      if (role != null) 'role': role,
    };
  }
}

// ==================== RESPONSE MODELS ====================

/// Login Response from API
/// Real API (Redis): { "data": { "access_token": "...", "refresh_token": "...", "expires_in": 900, "user": {...} } }
/// Mock API: { "access_token": "...", "refresh_token": "...", "user": {...} }
class LoginResponse {
  final String token; // Primary access token
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn; // Token lifetime in seconds
  final User user;

  LoginResponse({
    required this.token,
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    // Real API format (Redis) — returns access_token + refresh_token
    if (json.containsKey('access_token')) {
      final accessToken = json['access_token'] as String;
      return LoginResponse(
        token: accessToken,
        accessToken: accessToken,
        refreshToken: json['refresh_token'] as String?,
        expiresIn: json['expires_in'] as int?,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
      );
    }
    // Legacy format — single token
    else if (json.containsKey('token')) {
      return LoginResponse(
        token: json['token'] as String,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
      );
    }
    // Fallback
    else {
      throw Exception('Invalid login response format: missing token fields');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      if (accessToken != null) 'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (expiresIn != null) 'expires_in': expiresIn,
      'user': user.toJson(),
    };
  }
}

class RegisterResponse {
  final String userId;
  final String email;
  final DateTime createdAt;

  RegisterResponse({
    required this.userId,
    required this.email,
    required this.createdAt,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      userId: json['user_id'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
