import 'package:flutter/material.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/text_styles.dart';

/// Full-screen loading overlay with a centered card containing a spinner
/// and an optional message. Used during long-running async operations
/// (e.g. updating profile, uploading avatar) where the screen should be
/// blocked from interaction.
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final Color? barrierColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.barrierColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          // Block touches behind the overlay
          Positioned.fill(
            child: AbsorbPointer(
              // Material ancestor ensures Text widgets have a proper
              // DefaultTextStyle (otherwise Flutter renders the debug
              // yellow-underline style).
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  color: barrierColor ?? Colors.black.withValues(alpha: 0.4),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Compact 36px spinner — less intrusive than 48px
                            const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryDark,
                                ),
                              ),
                            ),
                            if (message != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                message!,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.none,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Please wait...',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  decoration: TextDecoration.none,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
