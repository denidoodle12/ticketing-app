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
    try {
      final id = json['id'];
      final name = json['name'];
      final email = json['email'];
      final username = json['username'];
      final roleField = json['role'];

      if (id == null) {
        throw Exception('User id is null');
      }
      if (name == null) {
        throw Exception('User name is null');
      }
      if (email == null) {
        throw Exception('User email is null');
      }
      if (username == null) {
        throw Exception('User username is null');
      }
      if (roleField == null) {
        throw Exception('User role is null');
      }

      // Handle role: can be String or Object
      String roleName;
      if (roleField is String) {
        roleName = roleField;
      } else if (roleField is Map) {
        roleName = roleField['name'] as String;
      } else {
        throw Exception('Unknown role format: ${roleField.runtimeType}');
      }

      return User(
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
    } catch (e) {
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
