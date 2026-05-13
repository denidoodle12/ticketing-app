import 'package:flutter/material.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/text_styles.dart';

/// Reusable empty state widget with illustration, title, and description.
///
/// Usage:
/// ```dart
/// EmptyStateWidget(
///   imagePath: 'assets/images/empty-states/empty-one.png',
///   title: 'No Tickets Yet',
///   description: 'Create a new ticket to get started.',
/// )
/// ```
class EmptyStateWidget extends StatelessWidget {
  /// Path to the illustration asset image.
  final String imagePath;

  /// Bold title text (max 4 words recommended).
  final String title;

  /// Supportive description text (1-2 lines).
  final String description;

  /// Optional action widget (e.g. a button) displayed below the description.
  final Widget? action;

  /// Size of the illustration image. Defaults to 180.
  final double imageSize;

  const EmptyStateWidget({
    super.key,
    required this.imagePath,
    required this.title,
    required this.description,
    this.action,
    this.imageSize = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            width: imageSize,
            height: imageSize,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Empty state widget for text-only scenarios (no illustration image).
///
/// Used for Ticket Overview, Ticket Activity offline stale data, etc.
class TextEmptyStateWidget extends StatelessWidget {
  /// Icon to display.
  final IconData icon;

  /// Bold title text.
  final String title;

  /// Supportive description text.
  final String description;

  /// Optional action widget.
  final Widget? action;

  /// Size of the icon. Defaults to 48.
  final double iconSize;

  const TextEmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
    this.iconSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: AppColors.textSecondary.withAlpha(100),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Empty state widget for offline mode scenarios.
///
/// Uses the `empty-offline.png` illustration and a wifi-off themed appearance.
class OfflineStateWidget extends StatelessWidget {
  /// Bold title text.
  final String title;

  /// Supportive description text.
  final String description;

  /// Size of the illustration. Defaults to 180.
  final double imageSize;

  const OfflineStateWidget({
    super.key,
    required this.title,
    required this.description,
    this.imageSize = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/empty-states/empty-offline.png',
            width: imageSize,
            height: imageSize,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
