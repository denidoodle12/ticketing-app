class User {
  final int id;
  final String name;
  final String? lastName;
  final String email;
  final String username;
  final String? phoneNumber;
  final String? profilePicture;
  final String role;
  final bool isFirstLogin;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.name,
    this.lastName,
    required this.email,
    required this.username,
    this.phoneNumber,
    this.profilePicture,
    required this.role,
    this.isFirstLogin = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Full name combining name and lastName
  String get fullName {
    if (lastName != null && lastName!.isNotEmpty) {
      return '$name $lastName';
    }
    return name;
  }

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
        name: name as String,
        lastName: json['last_name'] as String?,
        email: email as String,
        username: username as String,
        phoneNumber: json['phone_number'] as String?,
        profilePicture: json['profile_picture'] as String?,
        role: roleName,
        isFirstLogin: json['is_first_login'] as bool? ?? false,
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
      'name': name,
      'last_name': lastName,
      'email': email,
      'username': username,
      'phone_number': phoneNumber,
      'profile_picture': profilePicture,
      'role': role,
      'is_first_login': isFirstLogin,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? lastName,
    String? email,
    String? username,
    String? phoneNumber,
    String? profilePicture,
    String? role,
    bool? isFirstLogin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      username: username ?? this.username,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePicture: profilePicture ?? this.profilePicture,
      role: role ?? this.role,
      isFirstLogin: isFirstLogin ?? this.isFirstLogin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, name: $name, lastName: $lastName, email: $email, username: $username, phoneNumber: $phoneNumber, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
