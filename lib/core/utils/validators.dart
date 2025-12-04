import '../constants/app_constants.dart';

class Validators {
  /// Email validation
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email tidak boleh kosong';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Format email tidak valid';
    }

    return null;
  }

  /// Password validation
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password tidak boleh kosong';
    }

    if (value.length < AppConstants.minPasswordLength) {
      return 'Password minimal ${AppConstants.minPasswordLength} karakter';
    }

    return null;
  }

  /// Required field validation
  static String? required(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName tidak boleh kosong';
    }
    return null;
  }

  /// Name validation
  static String? name(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nama tidak boleh kosong';
    }

    if (value.length > AppConstants.maxNameLength) {
      return 'Nama maksimal ${AppConstants.maxNameLength} karakter';
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
      return 'Format nomor telepon tidak valid';
    }

    return null;
  }

  /// Confirm password validation
  static String? confirmPassword(String? value, String originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Konfirmasi password tidak boleh kosong';
    }

    if (value != originalPassword) {
      return 'Password tidak sama';
    }

    return null;
  }
}
