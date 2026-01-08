import 'user_model.dart';

// ==================== REQUEST MODELS ====================

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
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
/// Real API returns: { "data": { "token": "...", "user": {...} } }
/// Mock API returns: { "access_token": "...", "refresh_token": "...", "user": {...} }
class LoginResponse {
  final String token;
  final String? accessToken; // For mock compatibility
  final String? refreshToken; // For mock compatibility
  final User user;

  LoginResponse({
    required this.token,
    this.accessToken,
    this.refreshToken,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    // Real API format
    if (json.containsKey('token')) {
      return LoginResponse(
        token: json['token'] as String,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
      );
    }
    // Mock API format (backward compatibility)
    else {
      final token = json['access_token'] as String;
      return LoginResponse(
        token: token,
        accessToken: token,
        refreshToken: json['refresh_token'] as String,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
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
