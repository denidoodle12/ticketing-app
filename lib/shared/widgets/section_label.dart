import 'package:flutter/material.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/text_styles.dart';

/// A reusable section label widget with accent line.
class SectionLabel extends StatelessWidget {
  final String label;
  final Color? accentColor;

  const SectionLabel({super.key, required this.label, this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: accentColor ?? AppColors.primary500,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
