import 'dart:io' as io;
import 'package:flutter/material.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/text_styles.dart';

/// Full-screen preview dialog for a LOCAL image file (not yet uploaded).
///
/// Used by:
/// - Ticket Chat Tab (preview attachment before send)
/// - Create Ticket Screen (preview attachment before submit)
///
/// Tap the image (or back arrow) to dismiss. Pinch-zoom supported.
class LocalImagePreviewDialog {
  /// Show the preview dialog. Returns when user dismisses it.
  static Future<void> show({
    required BuildContext context,
    required String filePath,
    required String fileName,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _LocalImagePreviewScreen(
            filePath: filePath,
            fileName: fileName,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }
}

class _LocalImagePreviewScreen extends StatelessWidget {
  final String filePath;
  final String fileName;

  const _LocalImagePreviewScreen({
    required this.filePath,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;
    final file = io.File(filePath);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Zoomable image
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          size: 56,
                          color: AppColors.white.withAlpha(130),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load image',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.white.withAlpha(180),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // Top bar with back button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: topPadding + 8,
                bottom: 12,
                left: 4,
                right: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(180),
                    Colors.black.withAlpha(60),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Attachment Preview',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom filename bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: 16,
                bottom: bottomPadding + 16,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withAlpha(200),
                    Colors.black.withAlpha(80),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 18,
                    color: AppColors.white.withAlpha(180),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fileName,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.white.withAlpha(200),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
