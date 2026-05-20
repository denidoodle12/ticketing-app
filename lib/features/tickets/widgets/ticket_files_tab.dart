import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../models/comment_model.dart';
import '../../../shared/widgets/empty_state_widget.dart';
class TicketFilesTab extends StatelessWidget {
  final List<TicketAttachment> attachments;
  final String Function(String) getAttachmentUrl;
  final void Function(String imageUrl, String fileName) onImagePreview;
  final void Function(String url, String fileName) onFileOpen;
  final Map<String, String>? authHeaders;
  final bool isOffline;
  final bool isLoading;

  const TicketFilesTab({
    super.key,
    required this.attachments,
    required this.getAttachmentUrl,
    required this.onImagePreview,
    required this.onFileOpen,
    this.authHeaders,
    this.isOffline = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Show offline placeholder when device is offline — matches chat tab UX.
    // Without this, after going offline + back to list + reopen detail,
    // the attachments cache may be empty and we'd flash the wrong empty state.
    if (isOffline) {
      return _buildOfflinePlaceholder();
    }

    // Show loading while ticket detail is being refreshed (e.g. just came
    // back online). Prevents the "No Attachments" empty state from flashing
    // before the real list arrives.
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryDark),
      );
    }

    if (attachments.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      key: const PageStorageKey<String>('files'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File list
          ...attachments.map((attachment) => _buildFileItem(context, attachment)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOfflinePlaceholder() {
    return const Center(
      child: OfflineStateWidget(
        title: 'Attachments Unavailable Offline',
        description:
            'Files require an active internet connection to view and download.',
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: EmptyStateWidget(
        imagePath: 'assets/images/empty-states/empty-four.png',
        title: 'No Attachments',
        description: 'Files shared in this ticket will appear here.',
      ),
    );
  }

  Widget _buildFileItem(BuildContext context, TicketAttachment attachment) {
    final fullUrl = getAttachmentUrl(attachment.fileUrl);

    // Use a wider card with image preview for image attachments
    if (attachment.isImage) {
      return _buildImageFileCard(context, attachment, fullUrl);
    }
    return _buildDocumentFileCard(context, attachment);
  }

  /// Card layout for image attachments — shows a wide preview thumbnail
  Widget _buildImageFileCard(
    BuildContext context,
    TicketAttachment attachment,
    String fullUrl,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handlePreview(context, attachment),
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image preview
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 160,
                  child: CachedNetworkImage(
                    imageUrl: fullUrl,
                    httpHeaders: authHeaders,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.grey100,
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
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
                      color: AppColors.grey100,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            size: 32,
                            color: AppColors.grey300,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Preview unavailable',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Info row
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    // File type icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.image_rounded,
                        size: 18,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Name + date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attachment.fileName,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${attachment.extension.toUpperCase()} • ${attachment.formattedDate}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Download
                    _buildDownloadButton(context, attachment),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card layout for document attachments — compact row with icon
  Widget _buildDocumentFileCard(
    BuildContext context,
    TicketAttachment attachment,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handlePreview(context, attachment),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: [
                // File type icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _getFileBackgroundColor(attachment),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getFileIcon(attachment),
                    color: _getFileIconColor(attachment),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.fileName,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
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
                                fontSize: 11,
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
                // Download
                _buildDownloadButton(context, attachment),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildDownloadButton(BuildContext context, TicketAttachment attachment) {
    return IconButton(
      onPressed: () => _handleDownload(context, attachment),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.primaryDark.withAlpha(15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        fixedSize: const Size(38, 38),
      ),
      icon: Icon(
        Icons.download_rounded,
        size: 19,
        color: AppColors.primaryDark,
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
      return AppColors.primaryDark;
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
