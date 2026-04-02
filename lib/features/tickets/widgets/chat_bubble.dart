import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/api_config.dart';
import '../models/comment_model.dart';

class ChatBubble extends StatelessWidget {
  final Comment comment;
  final String Function(String)? getAttachmentUrl;
  final void Function(String)? onAttachmentTap;
  final Map<String, String>? authHeaders;

  const ChatBubble({
    super.key,
    required this.comment,
    this.getAttachmentUrl,
    this.onAttachmentTap,
    this.authHeaders,
  });

  @override
  Widget build(BuildContext context) {
    final isFromUser = comment.isFromUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isFromUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Agent name (only for agent messages)
          if (!isFromUser) ...[
            Padding(
              padding: const EdgeInsets.only(left: 44, bottom: 4),
              child: Text(
                comment.displayName,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],

          Row(
            mainAxisAlignment: isFromUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Agent avatar (left side)
              if (!isFromUser) ...[
                _buildAvatar(isAgent: true),
                const SizedBox(width: 8),
              ],

              // Message bubble
              Flexible(child: _buildMessageBubble(context, isFromUser)),

              // User avatar (right side)
              if (isFromUser) ...[
                const SizedBox(width: 8),
                _buildAvatar(isAgent: false),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({required bool isAgent}) {
    final profilePicture = comment.profilePicture;
    final hasProfilePicture =
        profilePicture != null && profilePicture.isNotEmpty;

    // Build full URL for profile picture
    String? profilePictureUrl;
    if (hasProfilePicture) {
      if (profilePicture.startsWith('http')) {
        profilePictureUrl = profilePicture;
      } else {
        profilePictureUrl = '${ApiConfig.baseUrl}$profilePicture';
      }
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isAgent ? AppColors.grey200 : AppColors.primary100,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(40),
            blurRadius: 4,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: hasProfilePicture
            ? CachedNetworkImage(
                imageUrl: profilePictureUrl!,
                httpHeaders: authHeaders,
                fit: BoxFit.cover,
                width: 32,
                height: 32,
                placeholder: (context, url) => _buildDefaultAvatarIcon(isAgent),
                errorWidget: (context, url, error) =>
                    _buildDefaultAvatarIcon(isAgent),
              )
            : _buildDefaultAvatarIcon(isAgent),
      ),
    );
  }

  Widget _buildDefaultAvatarIcon(bool isAgent) {
    return Center(
      child: isAgent
          ? Icon(Icons.support_agent, size: 18, color: AppColors.textSecondary)
          : Icon(Icons.person, size: 18, color: AppColors.primary),
    );
  }

  Widget _buildMessageBubble(BuildContext context, bool isFromUser) {
    // Fix: Check both null AND empty string (API returns "" for no attachment)
    final hasAttachment =
        comment.attachment != null && comment.attachment!.isNotEmpty;
    final isImage = hasAttachment && _isImageFile(comment.attachment!);

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      decoration: BoxDecoration(
        color: isFromUser ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isFromUser ? 16 : 4),
          bottomRight: Radius.circular(isFromUser ? 4 : 16),
        ),
        border: isFromUser ? null : Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(26),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isFromUser ? 16 : 4),
          bottomRight: Radius.circular(isFromUser ? 4 : 16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Attachment preview (if any)
            if (hasAttachment) ...[
              if (isImage)
                _buildImageAttachment(isFromUser)
              else
                _buildFileAttachment(isFromUser),
            ],

            // Message content (only show if content is not empty)
            Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: hasAttachment ? 8 : 12,
                bottom: 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (comment.content.isNotEmpty) ...[
                    Text(
                      comment.content,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isFromUser
                            ? AppColors.white
                            : AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    comment.formattedTime,
                    style: AppTextStyles.caption.copyWith(
                      color: isFromUser
                          ? AppColors.white.withAlpha(179)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageAttachment(bool isFromUser) {
    final attachmentPath = comment.attachment ?? '';
    final fullUrl = getAttachmentUrl?.call(attachmentPath) ?? attachmentPath;

    return GestureDetector(
      onTap: () => onAttachmentTap?.call(attachmentPath),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 200),
        color: AppColors.grey200,
        child: Stack(
          children: [
            // Network image
            CachedNetworkImage(
              imageUrl: fullUrl,
              httpHeaders: authHeaders,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (context, url) => Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withAlpha(77),
                      AppColors.accent.withAlpha(128),
                    ],
                  ),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.grey300, AppColors.grey200],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image,
                        size: 48,
                        color: AppColors.textSecondary.withAlpha(150),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Fullscreen overlay icon
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.black.withAlpha(128),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.fullscreen, size: 16, color: AppColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileAttachment(bool isFromUser) {
    final attachmentPath = comment.attachment ?? '';
    // Extract filename from path (e.g., /chat-uploads/file.pdf -> file.pdf)
    final fileName = attachmentPath.split('/').last;
    final extension = fileName.split('.').last.toLowerCase();

    return GestureDetector(
      onTap: () => onAttachmentTap?.call(attachmentPath),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isFromUser
              ? AppColors.white.withAlpha(38)
              : AppColors.grey100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isFromUser
                    ? AppColors.white.withAlpha(51)
                    : _getFileBackgroundColor(extension),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getFileIcon(extension),
                size: 24,
                color: isFromUser
                    ? AppColors.white
                    : _getFileIconColor(extension),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isFromUser
                          ? AppColors.white
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        extension.toUpperCase(),
                        style: AppTextStyles.caption.copyWith(
                          color: isFromUser
                              ? AppColors.white.withAlpha(179)
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.download_rounded,
                        size: 14,
                        color: isFromUser
                            ? AppColors.white.withAlpha(179)
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Tap to open',
                        style: AppTextStyles.caption.copyWith(
                          color: isFromUser
                              ? AppColors.white.withAlpha(179)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.article;
      case 'zip':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(String extension) {
    switch (extension) {
      case 'pdf':
        return AppColors.error500;
      case 'doc':
      case 'docx':
        return AppColors.primary;
      case 'txt':
        return AppColors.textSecondary;
      case 'zip':
        return AppColors.warning500;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getFileBackgroundColor(String extension) {
    switch (extension) {
      case 'pdf':
        return AppColors.error100;
      case 'doc':
      case 'docx':
        return AppColors.primary100;
      case 'zip':
        return AppColors.warning500.withAlpha(30);
      default:
        return AppColors.grey200;
    }
  }

  bool _isImageFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);
  }
}
