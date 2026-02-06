import 'package:flutter/material.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/text_styles.dart';

/// A reusable gradient header widget with icon, title, subtitle,
/// and curved bottom transition.
class GradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final double iconSize;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;

  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconSize = 40,
    this.leading,
    this.showBackButton = true,
    this.onBackPressed,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary600, AppColors.primary500],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Custom AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Back button or custom leading
                  if (leading != null)
                    leading!
                  else if (showBackButton)
                    _buildActionButton(
                      icon: Icons.arrow_back,
                      onTap: onBackPressed ?? () => Navigator.pop(context),
                    )
                  else
                    const SizedBox(width: 44),
                  Expanded(
                    child: Center(
                      child: Text(
                        title,
                        style: AppTextStyles.h5.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Placeholder for symmetry
                  const SizedBox(width: 44),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.white.withAlpha(51),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: iconSize, color: AppColors.white),
            ),

            if (subtitle != null) ...[
              const SizedBox(height: 16),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  subtitle!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.white.withAlpha(204),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Curved bottom transition
            Container(
              height: 24,
              decoration: BoxDecoration(
                color: backgroundColor ?? AppColors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.white.withAlpha(51),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.white, size: 22),
        ),
      ),
    );
  }
}
