import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';

/// A widget that displays password requirements with checkmarks.
class PasswordRequirements extends StatelessWidget {
  final String password;

  const PasswordRequirements({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Password Requirements',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RequirementRow(
            text: 'At least 8 characters',
            isMet: password.length >= 8,
          ),
          _RequirementRow(
            text: 'At least 1 uppercase letter',
            isMet: RegExp(r'[A-Z]').hasMatch(password),
          ),
          _RequirementRow(
            text: 'At least 1 lowercase letter',
            isMet: RegExp(r'[a-z]').hasMatch(password),
          ),
          _RequirementRow(
            text: 'At least 1 number',
            isMet: RegExp(r'[0-9]').hasMatch(password),
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final String text;
  final bool isMet;

  const _RequirementRow({required this.text, required this.isMet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isMet
                  ? AppColors.success500.withAlpha(26)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isMet ? AppColors.success500 : AppColors.grey300,
                width: 1.5,
              ),
            ),
            child: isMet
                ? const Icon(Icons.check, size: 12, color: AppColors.success500)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: isMet ? AppColors.success500 : AppColors.textSecondary,
                fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
