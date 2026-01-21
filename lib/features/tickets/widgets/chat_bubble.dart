import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../models/comment_model.dart';

class ChatBubble extends StatelessWidget {
  final Comment comment;

  const ChatBubble({
    super.key,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    final isFromCustomer = comment.isFromCustomer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isFromCustomer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Agent name (only for agent messages)
          if (!isFromCustomer) ...[
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
            mainAxisAlignment:
                isFromCustomer ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Agent avatar (left side)
              if (!isFromCustomer) ...[
                _buildAvatar(isAgent: true),
                const SizedBox(width: 8),
              ],

              // Message bubble
              Flexible(
                child: _buildMessageBubble(context, isFromCustomer),
              ),

              // Customer avatar (right side)
              if (isFromCustomer) ...[
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
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isAgent ? AppColors.grey200 : AppColors.primary100,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isAgent
            ? Icon(
                Icons.support_agent,
                size: 18,
                color: AppColors.textSecondary,
              )
            : Icon(
                Icons.person,
                size: 18,
                color: AppColors.primary,
              ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, bool isFromCustomer) {
    final hasAttachment = comment.attachment != null;
    final isImage = hasAttachment && _isImageFile(comment.attachment!);

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      decoration: BoxDecoration(
        color: isFromCustomer ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isFromCustomer ? 16 : 4),
          bottomRight: Radius.circular(isFromCustomer ? 4 : 16),
        ),
        border: isFromCustomer
            ? null
            : Border.all(color: AppColors.border),
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
          bottomLeft: Radius.circular(isFromCustomer ? 16 : 4),
          bottomRight: Radius.circular(isFromCustomer ? 4 : 16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Attachment preview (if any)
            if (hasAttachment) ...[
              if (isImage)
                _buildImageAttachment(isFromCustomer)
              else
                _buildFileAttachment(isFromCustomer),
            ],

            // Message content
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
                  Text(
                    comment.content,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isFromCustomer
                          ? AppColors.white
                          : AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        comment.formattedTime,
                        style: AppTextStyles.caption.copyWith(
                          color: isFromCustomer
                              ? AppColors.white.withAlpha(179)
                              : AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      if (isFromCustomer) ...[
                        const SizedBox(width: 4),
                        Text(
                          '\u2022 Read',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.white.withAlpha(179),
                            fontSize: 11,
                          ),
                        ),
                      ],
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

  Widget _buildImageAttachment(bool isFromCustomer) {
    return Container(
      width: double.infinity,
      height: 160,
      color: AppColors.grey200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Placeholder image
          Container(
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
            child: Center(
              child: Icon(
                Icons.image,
                size: 48,
                color: AppColors.white.withAlpha(179),
              ),
            ),
          ),
          // Overlay for image preview indication
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.black.withAlpha(128),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.fullscreen,
                size: 16,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileAttachment(bool isFromCustomer) {
    final fileName = comment.attachment ?? 'Unknown file';
    final extension = fileName.split('.').last.toLowerCase();
    final isPdf = extension == 'pdf';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFromCustomer
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
              color: isFromCustomer
                  ? AppColors.white.withAlpha(51)
                  : (isPdf ? AppColors.error100 : AppColors.grey200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
              size: 24,
              color: isFromCustomer
                  ? AppColors.white
                  : (isPdf ? AppColors.error500 : AppColors.textSecondary),
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
                    color: isFromCustomer
                        ? AppColors.white
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '1.2 MB', // Mock size
                  style: AppTextStyles.caption.copyWith(
                    color: isFromCustomer
                        ? AppColors.white.withAlpha(179)
                        : AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isImageFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);
  }
}
