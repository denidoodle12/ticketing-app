import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../models/comment_model.dart';

class TicketFilesTab extends StatelessWidget {
  final List<TicketAttachment> attachments;
  final String Function(String) getAttachmentUrl;
  final void Function(String imageUrl, String fileName) onImagePreview;
  final void Function(String url, String fileName) onFileOpen;
  final Map<String, String>? authHeaders;

  const TicketFilesTab({
    super.key,
    required this.attachments,
    required this.getAttachmentUrl,
    required this.onImagePreview,
    required this.onFileOpen,
    this.authHeaders,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.attach_file_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'All Attachments',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${attachments.length}',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // File list
          ...attachments.map((attachment) => _buildFileItem(context, attachment)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.grey100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 40,
              color: AppColors.grey300,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No attachments',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Files shared in this ticket will appear here',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(BuildContext context, TicketAttachment attachment) {
    final fullUrl = getAttachmentUrl(attachment.fileUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handlePreview(context, attachment),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail or File icon
                _buildThumbnail(attachment, fullUrl),
                const SizedBox(width: 12),

                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // File name
                      Text(
                        attachment.fileName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // File meta info
                      Row(
                        children: [
                          _buildMetaChip(
                            attachment.extension.toUpperCase(),
                            _getFileTypeColor(attachment),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${attachment.formattedDate} • ${attachment.formattedTime}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Uploaded by
                      Row(
                        children: [
                          Icon(
                            attachment.isFromAgent
                                ? Icons.support_agent
                                : Icons.person_outline,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              attachment.uploadedBy,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Download button
                _buildDownloadButton(context, attachment),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(TicketAttachment attachment, String fullUrl) {
    if (attachment.isImage) {
      // Image thumbnail
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 56,
          child: CachedNetworkImage(
            imageUrl: fullUrl,
            httpHeaders: authHeaders,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: AppColors.grey100,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary.withAlpha(150),
                    ),
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: AppColors.primary100,
              child: Icon(
                Icons.image_outlined,
                color: AppColors.primary,
                size: 24,
              ),
            ),
          ),
        ),
      );
    }

    // Document icon
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: _getFileBackgroundColor(attachment),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getFileIcon(attachment),
        color: _getFileIconColor(attachment),
        size: 28,
      ),
    );
  }

  Widget _buildMetaChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDownloadButton(BuildContext context, TicketAttachment attachment) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleDownload(context, attachment),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.download_rounded,
            size: 20,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(TicketAttachment attachment) {
    switch (attachment.extension) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'txt':
        return Icons.article_rounded;
      case 'zip':
        return Icons.folder_zip_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileIconColor(TicketAttachment attachment) {
    switch (attachment.extension) {
      case 'pdf':
        return AppColors.error500;
      case 'doc':
      case 'docx':
        return const Color(0xFF2B579A); // Word blue
      case 'txt':
        return AppColors.textSecondary;
      case 'zip':
        return AppColors.warning700;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getFileBackgroundColor(TicketAttachment attachment) {
    switch (attachment.extension) {
      case 'pdf':
        return AppColors.error100;
      case 'doc':
      case 'docx':
        return const Color(0xFF2B579A).withAlpha(25);
      case 'txt':
        return AppColors.grey100;
      case 'zip':
        return AppColors.warning500.withAlpha(25);
      default:
        return AppColors.grey100;
    }
  }

  Color _getFileTypeColor(TicketAttachment attachment) {
    if (attachment.isImage) {
      return AppColors.primary;
    }
    return _getFileIconColor(attachment);
  }

  void _handlePreview(BuildContext context, TicketAttachment attachment) {
    final fullUrl = getAttachmentUrl(attachment.fileUrl);

    if (attachment.isImage) {
      onImagePreview(fullUrl, attachment.fileName);
    } else {
      // For non-image files, open in browser/external app
      onFileOpen(fullUrl, attachment.fileName);
    }
  }

  void _handleDownload(BuildContext context, TicketAttachment attachment) {
    final fullUrl = getAttachmentUrl(attachment.fileUrl);
    onFileOpen(fullUrl, attachment.fileName);
  }
}
