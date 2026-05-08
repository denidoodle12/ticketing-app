import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/text_styles.dart';

/// A full-screen, zoomable profile picture viewer with Hero animation.
///
/// Usage:
/// ```dart
/// ProfilePictureViewer.show(
///   context: context,
///   imageUrl: 'https://...',
///   heroTag: 'profile_avatar_home',
///   userName: 'John Doe',
/// );
/// ```
class ProfilePictureViewer extends StatelessWidget {
  final String? imageUrl;
  final String userName;
  final String heroTag;

  const ProfilePictureViewer({
    super.key,
    this.imageUrl,
    required this.userName,
    required this.heroTag,
  });

  /// Show the full-screen viewer with a fade + hero transition.
  static void show({
    required BuildContext context,
    String? imageUrl,
    required String userName,
    required String heroTag,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) {
          return ProfilePictureViewer(
            imageUrl: imageUrl,
            userName: userName,
            heroTag: heroTag,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  String get _initials {
    final parts = userName.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // Image viewer — centered, zoomable
            Center(
              child: Hero(
                tag: heroTag,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: imageUrl != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: imageUrl!,
                            width: 280,
                            height: 280,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _buildPlaceholder(),
                            errorWidget: (_, __, ___) =>
                                _buildInitialsAvatar(),
                          ),
                        )
                      : _buildInitialsAvatar(),
                ),
              ),
            ),

            // Top bar — close button + user name
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      // Close button
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // User name
                      Expanded(
                        child: Text(
                          userName,
                          style: AppTextStyles.h5.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 280,
      height: 280,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary100,
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary500,
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary100,
        border: Border.all(color: AppColors.primaryDark, width: 3),
      ),
      child: Center(
        child: Text(
          _initials,
          style: AppTextStyles.h1.copyWith(
            color: AppColors.primary500,
            fontSize: 90,
          ),
        ),
      ),
    );
  }
}
