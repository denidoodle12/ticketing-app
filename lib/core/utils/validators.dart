import '../constants/app_constants.dart';

class Validators {
  /// Email validation
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email cannot be empty';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Invalid email format';
    }

    return null;
  }

  /// Email or Username validation
  static String? emailOrUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email/Username cannot be empty';
    }

    // Check if it's an email
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
    );

    // Check if it's a username (alphanumeric and underscore, 3-20 characters)
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

    // Valid if it matches either email or username pattern
    if (!emailRegex.hasMatch(value) && !usernameRegex.hasMatch(value)) {
      return 'Invalid email/username format';
    }

    return null;
  }

  /// Password validation
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password cannot be blank';
    }

    if (value.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters long';
    }

    // Check for at least one uppercase letter
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Passwords must contain at least 1 capital letter';
    }

    // Check for at least one number
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Passwords must contain at least 1 number';
    }

    return null;
  }

  /// Required field validation
  static String? required(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName cannot be empty';
    }
    return null;
  }

  /// Name validation
  static String? name(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name cannot be empty';
    }

    if (value.length > AppConstants.maxNameLength) {
      return 'Name must be at most ${AppConstants.maxNameLength} characters';
    }

    return null;
  }

  /// Phone number validation (Indonesian format)
  static String? phoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }

    final phoneRegex = RegExp(r'^(\+62|62|0)[0-9]{9,12}$');

    if (!phoneRegex.hasMatch(value)) {
      return 'Invalid phone number format';
    }

    return null;
  }

  /// Confirm password validation
  static String? confirmPassword(String? value, String originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Confirm password cannot be empty';
    }

    if (value != originalPassword) {
      return 'Passwords do not match';
    }

    return null;
  }
}
