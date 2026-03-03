import 'package:flutter_test/flutter_test.dart';
import 'package:ticketing_app/core/utils/validators.dart';

void main() {
  group('Validators', () {
    group('emailOrUsername', () {
      test('should return null when valid email is provided', () {
        // Arrange
        const email = 'customer1@test.com';

        // Act
        final result = Validators.emailOrUsername(email);

        // Assert
        expect(result, null);
      });

      test('should return null when valid username is provided', () {
        // Arrange
        const username = 'admin_one';

        // Act
        final result = Validators.emailOrUsername(username);

        // Assert
        expect(result, null);
      });

      test('should return error when empty string is provided', () {
        // Arrange
        const empty = '';

        // Act
        final result = Validators.emailOrUsername(empty);

        // Assert
        expect(result, 'Email/Username tidak boleh kosong');
      });

      test('should return error when null is provided', () {
        // Arrange
        const String? nullValue = null;

        // Act
        final result = Validators.emailOrUsername(nullValue);

        // Assert
        expect(result, 'Email/Username tidak boleh kosong');
      });

      test('should return error when username is too short (less than 3 chars)', () {
        // Arrange
        const shortUsername = 'ab';

        // Act
        final result = Validators.emailOrUsername(shortUsername);

        // Assert
        expect(result, 'Format email/username tidak valid');
      });

      test('should return error when username is too long (more than 20 chars)', () {
        // Arrange
        const longUsername = 'this_is_a_very_long_username_more_than_20';

        // Act
        final result = Validators.emailOrUsername(longUsername);

        // Assert
        expect(result, 'Format email/username tidak valid');
      });

      test('should return error when invalid email format is provided', () {
        // Arrange
        const invalidEmail = 'invalid.email.com';

        // Act
        final result = Validators.emailOrUsername(invalidEmail);

        // Assert
        expect(result, 'Format email/username tidak valid');
      });

      test('should return error when special characters in username', () {
        // Arrange
        const invalidUsername = 'user@name!';

        // Act
        final result = Validators.emailOrUsername(invalidUsername);

        // Assert
        expect(result, 'Format email/username tidak valid');
      });

      test('should return null when username has underscore', () {
        // Arrange
        const validUsername = 'user_name';

        // Act
        final result = Validators.emailOrUsername(validUsername);

        // Assert
        expect(result, null);
      });

      test('should return null when username has numbers', () {
        // Arrange
        const validUsername = 'user123';

        // Act
        final result = Validators.emailOrUsername(validUsername);

        // Assert
        expect(result, null);
      });
    });

    group('password', () {
      test('should return null when valid password is provided', () {
        // Arrange
        const password = 'CustomerPass123!';

        // Act
        final result = Validators.password(password);

        // Assert
        expect(result, null);
      });

      test('should return error when empty string is provided', () {
        // Arrange
        const empty = '';

        // Act
        final result = Validators.password(empty);

        // Assert
        expect(result, 'Password tidak boleh kosong');
      });

      test('should return error when null is provided', () {
        // Arrange
        const String? nullValue = null;

        // Act
        final result = Validators.password(nullValue);

        // Assert
        expect(result, 'Password tidak boleh kosong');
      });

      test('should return error when password is too short', () {
        // Arrange
        const shortPassword = '12345'; // Assuming min length is 6

        // Act
        final result = Validators.password(shortPassword);

        // Assert
        expect(result, isNotNull);
        expect(result, contains('minimal'));
      });

      test('should return null when password meets minimum length', () {
        // Arrange
        const validPassword = 'Pass123!';

        // Act
        final result = Validators.password(validPassword);

        // Assert
        expect(result, null);
      });
    });

    group('email', () {
      test('should return null when valid email is provided', () {
        // Arrange
        const email = 'test@example.com';

        // Act
        final result = Validators.email(email);

        // Assert
        expect(result, null);
      });

      test('should return error when invalid email format is provided', () {
        // Arrange
        const invalidEmail = 'invalid.email';

        // Act
        final result = Validators.email(invalidEmail);

        // Assert
        expect(result, 'Format email tidak valid');
      });

      test('should return error when empty email is provided', () {
        // Arrange
        const empty = '';

        // Act
        final result = Validators.email(empty);

        // Assert
        expect(result, 'Email tidak boleh kosong');
      });
    });

    group('required', () {
      test('should return null when value is provided', () {
        // Arrange
        const value = 'some value';
        const fieldName = 'Field Name';

        // Act
        final result = Validators.required(value, fieldName);

        // Assert
        expect(result, null);
      });

      test('should return error with field name when empty', () {
        // Arrange
        const empty = '';
        const fieldName = 'Username';

        // Act
        final result = Validators.required(empty, fieldName);

        // Assert
        expect(result, 'Username tidak boleh kosong');
      });

      test('should return error with field name when null', () {
        // Arrange
        const String? nullValue = null;
        const fieldName = 'Email';

        // Act
        final result = Validators.required(nullValue, fieldName);

        // Assert
        expect(result, 'Email tidak boleh kosong');
      });
    });
  });
}
