import 'package:flutter/foundation.dart';

class User {
  final int id;
  final String fullName;
  final String email;
  final String username;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.username,
    required this.role,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    print('═══════════════════════════════════');
    print('🔄 USER MODEL - Starting parsing');
    print('📦 JSON Input: $json');

    try {
      final id = json['id'];
      final name = json['name'];
      final email = json['email'];
      final username = json['username'];
      final roleField = json['role'];

      print('🔍 Field values:');
      print('  - id: $id (${id.runtimeType})');
      print('  - name: $name (${name.runtimeType})');
      print('  - email: $email (${email.runtimeType})');
      print('  - username: $username (${username.runtimeType})');
      print('  - role: $roleField (${roleField.runtimeType})');

      if (id == null) {
        print('❌ USER ERROR: id is NULL');
        throw Exception('User id is null');
      }
      if (name == null) {
        print('❌ USER ERROR: name is NULL');
        throw Exception('User name is null');
      }
      if (email == null) {
        print('❌ USER ERROR: email is NULL');
        throw Exception('User email is null');
      }
      if (username == null) {
        print('❌ USER ERROR: username is NULL');
        throw Exception('User username is null');
      }
      if (roleField == null) {
        print('❌ USER ERROR: role is NULL');
        throw Exception('User role is null');
      }

      // Handle role: can be String or Object
      String roleName;
      if (roleField is String) {
        roleName = roleField;
        print('✅ Role is String: $roleName');
      } else if (roleField is Map) {
        roleName = roleField['name'] as String;
        print('✅ Role is Map, extracted name: $roleName');
      } else {
        print('❌ Unknown role format: ${roleField.runtimeType}');
        throw Exception('Unknown role format: ${roleField.runtimeType}');
      }

      print('✅ USER MODEL - All fields validated');
      print('🏗️ Creating User object...');

      final user = User(
        id: id as int,
        fullName: name as String,
        email: email as String,
        username: username as String,
        role: roleName,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

      print('✅ USER MODEL - Successfully created!');
      print('👤 User: ${user.email} (ID: ${user.id})');
      print('═══════════════════════════════════');
      return user;
    } catch (e, stackTrace) {
      print('═══════════════════════════════════');
      print('❌❌❌ USER MODEL ERROR ❌❌❌');
      print('Error Type: ${e.runtimeType}');
      print('Error: $e');
      print('JSON that caused error: $json');
      print('Stack Trace:');
      print(stackTrace);
      print('═══════════════════════════════════');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': fullName,
      'email': email,
      'username': username,
      'role': role,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? fullName,
    String? email,
    String? username,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      username: username ?? this.username,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, fullName: $fullName, email: $email, username: $username, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
