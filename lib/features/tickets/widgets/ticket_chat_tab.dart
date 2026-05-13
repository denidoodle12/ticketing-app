import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/chat_websocket_service.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/toast_helper.dart';
import '../models/ticket_model.dart';
import '../models/comment_model.dart';
import 'chat_bubble.dart';
import '../../../shared/widgets/empty_state_widget.dart';

class TicketChatTab extends StatefulWidget {
  final List<Comment> comments;
  final Ticket ticket;
  final Function(String message, String? attachmentPath) onSendMessage;
  final WebSocketState connectionState;
  final bool isSending;
  final bool isOffline;
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
    this.isOffline = false,
    this.getAttachmentUrl,
    this.onAttachmentTap,
    this.authHeaders,
  });

  @override
  State<TicketChatTab> createState() => _TicketChatTabState();
}

class _TicketChatTabState extends State<TicketChatTab>
    with WidgetsBindingObserver {
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
    final bottomInset = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .viewInsets
        .bottom;
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

  /// Check if ticket is closed (status is final)
  bool get _isTicketClosed {
    return widget.ticket.status?.isFinal == true;
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
    final sizeError = Validators.fileSize(size, maxSizeInMB: AppConstants.maxChatAttachmentSizeMB);
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
                style: AppTextStyles.h6.copyWith(color: AppColors.textPrimary),
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
    // Show offline placeholder when device is offline
    if (widget.isOffline) {
      return _buildOfflinePlaceholder();
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          // Chat messages list (Expanded to fill available space)
          Expanded(
            child: widget.comments.isEmpty
                ? _buildEmptyState()
                : _buildChatList(),
          ),

          // Message input (fixed at bottom, SafeArea handles keyboard)
          // Hide input when ticket is closed (status is final)
          if (!_isTicketClosed)
            _buildMessageInput()
          else
            _buildClosedTicketBanner(),
        ],
      ),
    );
  }

  /// Build offline placeholder for chat tab
  Widget _buildOfflinePlaceholder() {
    return const Center(
      child: OfflineStateWidget(
        title: 'Chat Unavailable Offline',
        description:
            'Chat requires an active internet connection to view and send messages.',
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Center(
              child: EmptyStateWidget(
                imagePath: 'assets/images/empty-states/empty-three.png',
                title: 'No Messages Yet',
                description:
                    'Send a message to start the conversation with the agent.',
              ),
            ),
          ),
        );
      },
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

  Widget _buildClosedTicketBanner() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.grey100,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              'This ticket has been closed',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocalImagePreview() {
    if (_selectedAttachmentPath == null) return;
    final file = io.File(_selectedAttachmentPath!);
    final fileName = _selectedAttachmentName ?? 'Image';

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          final mediaQuery = MediaQuery.of(context);
          final topPadding = mediaQuery.padding.top;
          final bottomPadding = mediaQuery.padding.bottom;

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
                // Top bar
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
                // Bottom filename
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
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
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
          GestureDetector(
            onTap: isImage ? _showLocalImagePreview : null,
            child: Container(
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
