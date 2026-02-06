import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';

/// A widget that shows whether passwords match.
class PasswordMatchIndicator extends StatelessWidget {
  final String password;
  final String confirmPassword;

  const PasswordMatchIndicator({
    super.key,
    required this.password,
    required this.confirmPassword,
  });

  bool get _passwordsMatch {
    return confirmPassword.isNotEmpty && password == confirmPassword;
  }

  @override
  Widget build(BuildContext context) {
    if (confirmPassword.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: _passwordsMatch
                ? AppColors.success500.withAlpha(26)
                : AppColors.error500.withAlpha(26),
            shape: BoxShape.circle,
            border: Border.all(
              color: _passwordsMatch
                  ? AppColors.success500
                  : AppColors.error500,
              width: 1.5,
            ),
          ),
          child: Icon(
            _passwordsMatch ? Icons.check : Icons.close,
            size: 12,
            color: _passwordsMatch ? AppColors.success500 : AppColors.error500,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _passwordsMatch ? 'Passwords match' : 'Passwords do not match',
          style: AppTextStyles.bodySmall.copyWith(
            color: _passwordsMatch ? AppColors.success500 : AppColors.error500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
