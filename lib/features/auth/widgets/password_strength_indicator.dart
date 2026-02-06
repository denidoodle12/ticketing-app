import 'package:flutter/material.dart';
import 'package:flutter_password_strength/flutter_password_strength.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';

/// A password strength indicator widget using flutter_password_strength package.
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final bool showLabel;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
    this.showLabel = true,
  });

  // Calculate strength score (0-4)
  int get _strengthScore {
    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    return score;
  }

  String get _strengthLabel {
    switch (_strengthScore) {
      case 0:
        return 'Very Weak';
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return '';
    }
  }

  Color get _strengthColor {
    switch (_strengthScore) {
      case 0:
        return AppColors.grey400;
      case 1:
        return AppColors.error500;
      case 2:
        return AppColors.warning500;
      case 3:
        return AppColors.accent500;
      case 4:
        return AppColors.success500;
      default:
        return AppColors.grey400;
    }
  }

  IconData get _strengthIcon {
    switch (_strengthScore) {
      case 0:
      case 1:
        return Icons.shield_outlined;
      case 2:
        return Icons.shield;
      case 3:
        return Icons.verified_user_outlined;
      case 4:
        return Icons.verified_user;
      default:
        return Icons.shield_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Text(
                  'Password Strength',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Icon(_strengthIcon, size: 18, color: _strengthColor),
                const SizedBox(width: 6),
                Text(
                  _strengthLabel,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: _strengthColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // Using package's strength bar
        FlutterPasswordStrength(
          password: password,
          height: 8,
          radius: 4,
          strengthCallback: (strength) {
            // Optional callback
          },
        ),
      ],
    );
  }
}
