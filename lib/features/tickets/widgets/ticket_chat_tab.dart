import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/network/chat_websocket_service.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/toast_helper.dart';
import '../models/ticket_model.dart';
import '../models/comment_model.dart';
import 'chat_bubble.dart';

class TicketChatTab extends StatefulWidget {
  final List<Comment> comments;
  final Ticket ticket;
  final Function(String message, String? attachmentPath) onSendMessage;
  final WebSocketState connectionState;
  final bool isSending;
  final String Function(String)? getAttachmentUrl;
  final void Function(String)? onAttachmentTap;
  final Map<String, String>? authHeaders;

  const TicketChatTab({
    super.key,
    required this.comments,
    required this.ticket,
    required this.onSendMessage,
    this.connectionState = WebSocketState.disconnected,
    this.isSending = false,
    this.getAttachmentUrl,
    this.onAttachmentTap,
    this.authHeaders,
  });

  @override
  State<TicketChatTab> createState() => _TicketChatTabState();
}

class _TicketChatTabState extends State<TicketChatTab> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  // Selected attachment
  String? _selectedAttachmentPath;
  String? _selectedAttachmentName;

  // Track keyboard state
  double _previousBottomInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Listen to text changes to update send button state
    _messageController.addListener(_onTextChanged);
    // Listen to focus changes to scroll when keyboard appears
    _focusNode.addListener(_onFocusChanged);
    // Initial scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Handle keyboard visibility changes
    final bottomInset = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;
    if (bottomInset > _previousBottomInset) {
      // Keyboard appeared - scroll to bottom
      _scrollToBottom();
    }
    _previousBottomInset = bottomInset;
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      // When input gains focus, scroll to bottom after keyboard animation
      Future.delayed(const Duration(milliseconds: 300), () {
        _scrollToBottom();
      });
    }
  }

  void _onTextChanged() {
    // Trigger rebuild to update send button state
    setState(() {});
  }

  /// Check if send button should be enabled
  /// Returns true if there's a non-empty message OR an attachment
  bool get _canSend {
    final message = _messageController.text.trim();
    return message.isNotEmpty || _selectedAttachmentPath != null;
  }

  void _handleSend() {
    if (widget.isSending) return;

    final message = _messageController.text.trim();
    final attachmentPath = _selectedAttachmentPath;

    // At least message or attachment must be present
    if (message.isEmpty && attachmentPath == null) return;

    widget.onSendMessage(message, attachmentPath);
    _messageController.clear();

    // Clear selected attachment
    setState(() {
      _selectedAttachmentPath = null;
      _selectedAttachmentName = null;
    });

    // Scroll to bottom after sending (with reverse: true, bottom is position 0)
    _scrollToBottom();
  }

  void _clearAttachment() {
    setState(() {
      _selectedAttachmentPath = null;
      _selectedAttachmentName = null;
    });
  }

  bool _validateFile(String? path, int? size, String? name) {
    if (path == null || name == null) return false;

    // Check file type
    final typeError = Validators.fileType(name);
    if (typeError != null) {
      ToastHelper.showError(
        context,
        'Attachment Error',
        description: typeError,
      );
      return false;
    }

    // Check file size
    final sizeError = Validators.fileSize(size, maxSizeInMB: 5);
    if (sizeError != null) {
      ToastHelper.showError(
        context,
        'Attachment Error',
        description: sizeError,
      );
      return false;
    }

    return true;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.length();
        if (_validateFile(image.path, bytes, image.name)) {
          setState(() {
            _selectedAttachmentPath = image.path;
            _selectedAttachmentName = image.name;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: Validators.allowedFileExtensions,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (_validateFile(file.path, file.size, file.name)) {
          setState(() {
            _selectedAttachmentPath = file.path;
            _selectedAttachmentName = file.name;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo != null) {
        final bytes = await photo.length();
        if (_validateFile(photo.path, bytes, photo.name)) {
          setState(() {
            _selectedAttachmentPath = photo.path;
            _selectedAttachmentName = photo.name;
          });
        }
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
    }
  }

  /// Scroll to bottom (newest messages) - with reverse: true, this is position 0
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void didUpdateWidget(TicketChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll when new messages arrive
    if (widget.comments.length > oldWidget.comments.length) {
      _scrollToBottom();
    }
  }

  void _handleAttachment() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Pilih Lampiran',
                style: AppTextStyles.h6.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Photo & Video option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.image_outlined, color: AppColors.primaryDark),
              ),
              title: Text(
                'Photo & Video',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Share images (jpg, png, gif)',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            // Document option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.insert_drive_file_outlined,
                  color: AppColors.primaryDark,
                ),
              ),
              title: Text(
                'Document',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'PDF, DOC, TXT, ZIP (max 5MB)',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
            // Camera option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primaryDark,
                ),
              ),
              title: Text(
                'Camera',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Take a photo',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          // Connection status indicator
          _buildConnectionStatus(),

          // Chat messages list (Expanded to fill available space)
          Expanded(
            child: widget.comments.isEmpty
                ? _buildEmptyState()
                : _buildChatList(),
          ),

          // Message input (fixed at bottom, SafeArea handles keyboard)
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    Color bgColor;
    Color textColor;
    String statusText;
    IconData icon;

    switch (widget.connectionState) {
      case WebSocketState.connected:
        bgColor = AppColors.success500.withAlpha(25);
        textColor = AppColors.success500;
        statusText = 'Connected';
        icon = Icons.wifi;
        break;
      case WebSocketState.connecting:
      case WebSocketState.reconnecting:
        bgColor = AppColors.warning500.withAlpha(25);
        textColor = AppColors.warning500;
        statusText = widget.connectionState == WebSocketState.connecting
            ? 'Connecting...'
            : 'Reconnecting...';
        icon = Icons.sync;
        break;
      case WebSocketState.error:
        bgColor = AppColors.error500.withAlpha(25);
        textColor = AppColors.error500;
        statusText = 'Connection error';
        icon = Icons.wifi_off;
        break;
      case WebSocketState.disconnected:
        bgColor = AppColors.grey200;
        textColor = AppColors.textSecondary;
        statusText = 'Offline mode';
        icon = Icons.wifi_off;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: bgColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: AppTextStyles.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.grey300),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation with the agent',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    // Group comments by date
    final groupedComments = _groupCommentsByDate(widget.comments);
    // Reverse for bottom-to-top scrolling
    final reversedItems = groupedComments.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: reversedItems.length,
      itemBuilder: (context, index) {
        final item = reversedItems[index];

        if (item is String) {
          // Date separator
          return _buildDateSeparator(item);
        } else if (item is Comment) {
          return ChatBubble(
            comment: item,
            getAttachmentUrl: widget.getAttachmentUrl,
            onAttachmentTap: widget.onAttachmentTap,
            authHeaders: widget.authHeaders,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  List<dynamic> _groupCommentsByDate(List<Comment> comments) {
    final List<dynamic> result = [];
    String? currentDate;

    for (final comment in comments) {
      final dateGroup = comment.formattedDateGroup;

      // Add date separator if date changed
      if (dateGroup != currentDate) {
        currentDate = dateGroup;
        result.add(dateGroup);
      }

      result.add(comment);
    }

    return result;
  }

  Widget _buildDateSeparator(String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          date,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Attachment preview (if file selected)
            if (_selectedAttachmentPath != null) _buildAttachmentPreview(),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment button
                IconButton(
                  onPressed: _handleAttachment,
                  icon: Icon(Icons.attach_file, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),

                // Message text field
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: AppColors.grey100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Send button
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.isSending
                        ? AppColors.primary.withAlpha(150)
                        : _canSend
                        ? AppColors.primary
                        : AppColors.grey300,
                    shape: BoxShape.circle,
                  ),
                  child: widget.isSending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.white,
                            ),
                          ),
                        )
                      : IconButton(
                          onPressed: _canSend ? _handleSend : null,
                          icon: Icon(
                            Icons.send,
                            color: _canSend
                                ? AppColors.white
                                : AppColors.grey400,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    final fileName = _selectedAttachmentName ?? 'Unknown file';
    final extension = fileName.split('.').last.toLowerCase();
    final isImage = [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
    ].contains(extension);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // File icon or image thumbnail
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isImage ? AppColors.primary100 : AppColors.grey200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: isImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      io.File(_selectedAttachmentPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.image,
                          color: AppColors.primary,
                          size: 24,
                        );
                      },
                    ),
                  )
                : Icon(
                    _getFileIcon(extension),
                    color: _getFileIconColor(extension),
                    size: 24,
                  ),
          ),
          const SizedBox(width: 12),

          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  extension.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Remove button
          IconButton(
            onPressed: _clearAttachment,
            icon: Icon(Icons.close, color: AppColors.textSecondary, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
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
}
