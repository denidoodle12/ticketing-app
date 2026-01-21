import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../models/comment_model.dart';

class TicketFilesTab extends StatelessWidget {
  final List<TicketAttachment> attachments;

  const TicketFilesTab({
    super.key,
    required this.attachments,
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
          Text(
            'All Attachments (${attachments.length})',
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
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
          Icon(
            Icons.folder_open_outlined,
            size: 64,
            color: AppColors.grey300,
          ),
          const SizedBox(height: 16),
          Text(
            'No attachments',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Files shared in this ticket will appear here',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(BuildContext context, TicketAttachment attachment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // File icon
          _buildFileIcon(attachment),
          const SizedBox(width: 12),

          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${attachment.formattedSize} \u2022 ${attachment.formattedDate} \u2022 ${attachment.formattedTime}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Uploaded by ${attachment.uploadedBy}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(
                icon: Icons.visibility_outlined,
                onTap: () => _handlePreview(context, attachment),
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.download_outlined,
                onTap: () => _handleDownload(context, attachment),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileIcon(TicketAttachment attachment) {
    IconData icon;
    Color iconColor;
    Color bgColor;

    if (attachment.isImage) {
      icon = Icons.image_outlined;
      iconColor = AppColors.primary;
      bgColor = AppColors.primary100;
    } else if (attachment.isPdf) {
      icon = Icons.picture_as_pdf_outlined;
      iconColor = AppColors.error500;
      bgColor = AppColors.error100;
    } else {
      icon = Icons.insert_drive_file_outlined;
      iconColor = AppColors.textSecondary;
      bgColor = AppColors.grey100;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: iconColor,
        size: 24,
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  void _handlePreview(BuildContext context, TicketAttachment attachment) {
    if (attachment.isImage) {
      // TODO: Open image viewer
      _showSnackBar(context, 'Opening preview: ${attachment.fileName}');
    } else if (attachment.isPdf) {
      // TODO: Open PDF viewer
      _showSnackBar(context, 'Opening PDF: ${attachment.fileName}');
    } else {
      _showSnackBar(context, 'Preview not available for this file type');
    }
  }

  void _handleDownload(BuildContext context, TicketAttachment attachment) {
    // TODO: Implement file download
    _showSnackBar(context, 'Downloading: ${attachment.fileName}');
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
