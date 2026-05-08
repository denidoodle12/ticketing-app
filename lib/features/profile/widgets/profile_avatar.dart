import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final VoidCallback? onTap;
  final bool showEditIcon;
  final String? heroTag;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 80,
    this.onTap,
    this.showEditIcon = false,
    this.heroTag,
  });

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar = Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary100,
              border: Border.all(color: AppColors.primaryDark, width: 2),
            ),
            child: ClipOval(
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildInitials();
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    )
                  : _buildInitials(),
            ),
          ),
          if (showEditIcon)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: size * 0.18,
                  color: AppColors.white,
                ),
              ),
            ),
        ],
      );

    // Wrap with Hero if heroTag is provided
    if (heroTag != null) {
      avatar = Hero(
        tag: heroTag!,
        child: avatar,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: avatar,
    );
  }

  Widget _buildInitials() {
    return Center(
      child: Text(
        _initials,
        style: AppTextStyles.h2.copyWith(
          color: AppColors.primary500,
          fontSize: size * 0.35,
        ),
      ),
    );
  }
}
