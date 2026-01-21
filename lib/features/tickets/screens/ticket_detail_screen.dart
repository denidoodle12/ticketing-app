import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/network/chat_websocket_service.dart';
import '../../../data/datasources/local/local_storage.dart';
import '../../../providers/ticket_provider.dart';
import '../models/ticket_model.dart';
import '../models/comment_model.dart';
import '../widgets/ticket_detail_tab.dart';
import '../widgets/ticket_chat_tab.dart';
import '../widgets/ticket_files_tab.dart';

class TicketDetailScreen extends StatefulWidget {
  final Ticket ticket;

  const TicketDetailScreen({
    super.key,
    required this.ticket,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Ticket _currentTicket;
  List<Comment> _comments = [];
  List<TicketAttachment> _attachments = [];

  // WebSocket service for real-time chat
  final ChatWebSocketService _webSocketService = ChatWebSocketService();
  WebSocketState _wsState = WebSocketState.disconnected;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentTicket = widget.ticket;

    // Setup WebSocket callbacks
    _webSocketService.onMessageReceived = _handleWebSocketMessage;
    _webSocketService.onStateChanged = _handleWebSocketStateChange;
    _webSocketService.onError = _handleWebSocketError;

    // Load ticket detail from API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTicketDetail();
    });
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTicketDetail() async {
    final provider = context.read<TicketProvider>();
    await provider.loadTicketDetail(widget.ticket.id);

    if (mounted && provider.ticketDetailResponse != null) {
      setState(() {
        _currentTicket = provider.ticketDetailResponse!.ticket;
        _comments = _parseComments(provider.ticketDetailResponse!.comments);
        _attachments = _extractAttachments(_comments, _currentTicket);
      });

      // Connect to WebSocket for real-time chat
      _connectWebSocket();
    }
  }

  /// Connect to WebSocket for real-time chat
  Future<void> _connectWebSocket() async {
    final localStorage = context.read<LocalStorage>();
    final token = await localStorage.getAccessToken();

    if (token != null && mounted) {
      await _webSocketService.connect(
        ticketId: _currentTicket.id,
        token: token,
      );
    }
  }

  /// Handle incoming message from WebSocket
  void _handleWebSocketMessage(Comment comment) {
    if (mounted) {
      // Check if comment already exists (avoid duplicates)
      final exists = _comments.any((c) => c.id == comment.id);
      if (!exists) {
        setState(() {
          _comments.add(comment);
          // Update attachments if comment has attachment
          if (comment.attachment != null && comment.attachment!.isNotEmpty) {
            _attachments.add(TicketAttachment(
              fileName: _getFileNameFromPath(comment.attachment!),
              fileUrl: comment.attachment!,
              fileSize: 0,
              uploadedAt: comment.createdAt,
              uploadedBy: comment.isFromAgent ? comment.displayName : 'You',
              isFromAgent: comment.isFromAgent,
            ));
          }
        });
      }
    }
  }

  /// Handle WebSocket state changes
  void _handleWebSocketStateChange(WebSocketState state) {
    if (mounted) {
      setState(() {
        _wsState = state;
      });
    }
  }

  /// Handle WebSocket errors
  void _handleWebSocketError(String error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chat connection error: $error'),
          backgroundColor: AppColors.warning500,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  List<Comment> _parseComments(List<dynamic> commentsJson) {
    return commentsJson
        .map((json) => Comment.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  List<TicketAttachment> _extractAttachments(List<Comment> comments, Ticket ticket) {
    final attachments = <TicketAttachment>[];

    // Add ticket attachment if exists
    if (ticket.attachment != null && ticket.attachment!.isNotEmpty) {
      attachments.add(TicketAttachment(
        fileName: _getFileNameFromPath(ticket.attachment!),
        fileUrl: ticket.attachment!,
        fileSize: 0,
        uploadedAt: ticket.createdAt ?? DateTime.now(),
        uploadedBy: 'You',
        isFromAgent: false,
      ));
    }

    // Add attachments from comments
    for (final comment in comments) {
      if (comment.attachment != null && comment.attachment!.isNotEmpty) {
        attachments.add(TicketAttachment(
          fileName: _getFileNameFromPath(comment.attachment!),
          fileUrl: comment.attachment!,
          fileSize: 0,
          uploadedAt: comment.createdAt,
          uploadedBy: comment.isFromAgent ? comment.displayName : 'You',
          isFromAgent: comment.isFromAgent,
        ));
      }
    }

    return attachments;
  }

  String _getFileNameFromPath(String path) {
    final parts = path.split('/');
    return parts.isNotEmpty ? parts.last : path;
  }

  String _getAssignedAgent() {
    if (_currentTicket.assignedTo != null) {
      return 'Agent #${_currentTicket.assignedTo}';
    }
    return 'Unassigned';
  }

  String _getUpdatedTimeAgo() {
    if (_currentTicket.updatedAt == null) return '';

    final now = DateTime.now();
    final difference = now.difference(_currentTicket.updatedAt!);

    if (difference.inDays > 0) {
      return 'Updated ${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return 'Updated ${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return 'Updated ${difference.inMinutes}m ago';
    } else {
      return 'Updated just now';
    }
  }

  void _showMoreOptions() {
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
              leading: const Icon(Icons.refresh),
              title: const Text('Refresh'),
              onTap: () {
                Navigator.pop(context);
                _loadTicketDetail();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share Ticket'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement share
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Consumer<TicketProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                // Header
                _buildHeader(),

                // Ticket Info (Subject + Meta)
                _buildTicketInfo(),

                // Tabs
                _buildTabBar(),

                // Tab Content
                Expanded(
                  child: provider.isTicketDetailLoading
                      ? const Center(child: CircularProgressIndicator())
                      : provider.ticketDetailState == TicketState.error
                          ? _buildErrorState(provider.errorMessage)
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                TicketDetailTab(ticket: _currentTicket),
                                TicketChatTab(
                                  comments: _comments,
                                  ticket: _currentTicket,
                                  onSendMessage: _handleSendMessage,
                                  connectionState: _wsState,
                                  isSending: _isSending,
                                ),
                                TicketFilesTab(attachments: _attachments),
                              ],
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error500.withAlpha(150),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load ticket',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Unknown error',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadTicketDetail,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.white,
      child: Row(
        children: [
          // Back button with rounded square background
          _buildActionButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Ticket Details',
                style: AppTextStyles.h5.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          // More options button with rounded square background
          _buildActionButton(
            icon: Icons.more_vert,
            onTap: _showMoreOptions,
          ),
        ],
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: AppColors.primaryDark,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildTicketInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject - Large bold text
          Text(
            _currentTicket.subject,
            style: AppTextStyles.h4.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),

          // Meta info: Agent and Updated time
          Row(
            children: [
              // Agent/Unassigned
              Icon(
                Icons.person_outline,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                _getAssignedAgent(),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 20),
              // Updated time
              Icon(
                Icons.access_time,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                _getUpdatedTimeAgo(),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: AppColors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primaryDark,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryDark,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            labelStyle: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: AppTextStyles.bodyMedium,
            tabs: [
              const Tab(text: 'Details'),
              Tab(text: 'Chat (${_comments.length})'),
              Tab(text: 'Files (${_attachments.length})'),
            ],
          ),
        ),
        // Bottom shadow divider
        Container(
          height: 8,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(15),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSendMessage(String message, String? attachmentPath) async {
    if (_isSending) return;

    // Get provider before async operations
    final provider = context.read<TicketProvider>();

    setState(() {
      _isSending = true;
    });

    bool sent = false;

    // Try WebSocket first if connected
    if (_webSocketService.isConnected) {
      sent = await _webSocketService.sendMessage(message);
    }

    // Fallback to REST API if WebSocket fails or not connected
    if (!sent && mounted) {
      final comment = await provider.createComment(
        ticketId: _currentTicket.id,
        content: message,
      );

      if (comment != null && mounted) {
        setState(() {
          _comments.add(comment);
          // Update attachments if comment has attachment
          if (comment.attachment != null && comment.attachment!.isNotEmpty) {
            _attachments.add(TicketAttachment(
              fileName: _getFileNameFromPath(comment.attachment!),
              fileUrl: comment.attachment!,
              fileSize: 0,
              uploadedAt: comment.createdAt,
              uploadedBy: 'You',
              isFromAgent: false,
            ));
          }
        });
      } else if (mounted && provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage!),
            backgroundColor: AppColors.error500,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isSending = false;
      });
    }
  }
}
