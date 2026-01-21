import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/network/chat_websocket_service.dart';
import '../models/ticket_model.dart';
import '../models/comment_model.dart';
import 'chat_bubble.dart';

class TicketChatTab extends StatefulWidget {
  final List<Comment> comments;
  final Ticket ticket;
  final Function(String message, String? attachmentPath) onSendMessage;
  final WebSocketState connectionState;
  final bool isSending;

  const TicketChatTab({
    super.key,
    required this.comments,
    required this.ticket,
    required this.onSendMessage,
    this.connectionState = WebSocketState.disconnected,
    this.isSending = false,
  });

  @override
  State<TicketChatTab> createState() => _TicketChatTabState();
}

class _TicketChatTabState extends State<TicketChatTab> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (widget.isSending) return;

    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      widget.onSendMessage(message, null);
      _messageController.clear();

      // Scroll to bottom after sending
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// Scroll to bottom when new messages arrive
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
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
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.image_outlined,
                  color: AppColors.primary,
                ),
              ),
              title: const Text('Photo & Video'),
              subtitle: const Text('Share images or videos'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement image picker
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent300.withAlpha(77),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.insert_drive_file_outlined,
                  color: AppColors.accent700,
                ),
              ),
              title: const Text('Document'),
              subtitle: const Text('Share PDF, DOC, or other files'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement file picker
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning500.withAlpha(51),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.warning700,
                ),
              ),
              title: const Text('Camera'),
              subtitle: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement camera
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
    return Column(
      children: [
        // Connection status indicator
        _buildConnectionStatus(),

        // Chat messages list
        Expanded(
          child: widget.comments.isEmpty
              ? _buildEmptyState()
              : _buildChatList(),
        ),

        // Message input
        _buildMessageInput(),
      ],
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
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: AppColors.grey300,
          ),
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: groupedComments.length,
      itemBuilder: (context, index) {
        final item = groupedComments[index];

        if (item is String) {
          // Date separator
          return _buildDateSeparator(item);
        } else if (item is Comment) {
          return ChatBubble(comment: item);
        } else if (item is StatusChangeEvent) {
          return _buildStatusChangeIndicator(item);
        }

        return const SizedBox.shrink();
      },
    );
  }

  List<dynamic> _groupCommentsByDate(List<Comment> comments) {
    final List<dynamic> result = [];
    String? currentDate;

    // Add mock status change event after first comment
    bool statusChangeAdded = false;

    for (int i = 0; i < comments.length; i++) {
      final comment = comments[i];
      final dateGroup = comment.formattedDateGroup;

      // Add date separator if date changed
      if (dateGroup != currentDate) {
        currentDate = dateGroup;
        result.add(dateGroup);
      }

      result.add(comment);

      // Add status change indicator after first customer message (mock)
      if (!statusChangeAdded && comment.isFromCustomer && i == 0) {
        result.add(StatusChangeEvent(
          fromStatus: 'Open',
          toStatus: 'In Progress',
          changedAt: DateTime(2026, 1, 6, 11, 0),
        ));
        statusChangeAdded = true;
      }
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

  Widget _buildStatusChangeIndicator(StatusChangeEvent event) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sync,
                size: 14,
                color: AppColors.success500,
              ),
              const SizedBox(width: 6),
              Text(
                'Status changed: ${event.fromStatus} \u2192 ${event.toStatus}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '\u2022 ${event.formattedTime}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attachment button
            IconButton(
              onPressed: _handleAttachment,
              icon: Icon(
                Icons.attach_file,
                color: AppColors.textSecondary,
              ),
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
                  onSubmitted: (_) => _handleSend(),
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
                    : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: widget.isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                      ),
                    )
                  : IconButton(
                      onPressed: _handleSend,
                      icon: const Icon(
                        Icons.send,
                        color: AppColors.white,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
