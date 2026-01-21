import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
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

  // Mock data for now - will be replaced with API integration
  List<Comment> _comments = [];
  List<TicketAttachment> _attachments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMockData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadMockData() {
    // Mock comments data
    _comments = [
      Comment(
        id: 1,
        ticketId: widget.ticket.id,
        userId: 1,
        userName: 'customer@test.com',
        userRole: 'customer',
        content: 'I forgot my password and cannot reset it through the normal process.',
        createdAt: DateTime(2026, 1, 6, 10, 30),
      ),
      Comment(
        id: 2,
        ticketId: widget.ticket.id,
        userId: 5,
        userName: 'John Agent',
        userRole: 'agent',
        content: 'Hi, thank you for contacting us. I\'ll help you reset your password. Can you confirm your registered email address?',
        createdAt: DateTime(2026, 1, 6, 11, 5),
      ),
      Comment(
        id: 3,
        ticketId: widget.ticket.id,
        userId: 1,
        userName: 'customer@test.com',
        userRole: 'customer',
        content: 'Yes, my email is john@company.com',
        createdAt: DateTime(2026, 1, 6, 11, 8),
      ),
      Comment(
        id: 4,
        ticketId: widget.ticket.id,
        userId: 5,
        userName: 'John Agent',
        userRole: 'agent',
        content: 'I\'ve sent a password reset link to your email. Please check and let me know.',
        attachment: 'password_reset_guide.pdf',
        createdAt: DateTime(2026, 1, 6, 11, 15),
      ),
      Comment(
        id: 5,
        ticketId: widget.ticket.id,
        userId: 1,
        userName: 'customer@test.com',
        userRole: 'customer',
        content: 'I still can\'t login, here\'s the error screenshot. It says \'Token Expired\'.',
        attachment: 'screenshot.png',
        createdAt: DateTime(2026, 1, 6, 11, 20),
      ),
    ];

    // Mock attachments data
    _attachments = [
      TicketAttachment(
        fileName: 'screenshot.png',
        fileUrl: '/uploads/screenshot.png',
        fileSize: 245 * 1024,
        uploadedAt: DateTime(2026, 1, 6, 10, 30),
        uploadedBy: 'You',
        isFromAgent: false,
      ),
      TicketAttachment(
        fileName: 'password_reset_guide.pdf',
        fileUrl: '/uploads/password_reset_guide.pdf',
        fileSize: (1.2 * 1024 * 1024).toInt(),
        uploadedAt: DateTime(2026, 1, 6, 11, 15),
        uploadedBy: 'John Agent',
        isFromAgent: true,
      ),
      TicketAttachment(
        fileName: 'error_log.txt',
        fileUrl: '/uploads/error_log.txt',
        fileSize: 56 * 1024,
        uploadedAt: DateTime(2026, 1, 6, 11, 30),
        uploadedBy: 'You',
        isFromAgent: false,
      ),
    ];

    setState(() {
      _isLoading = false;
    });
  }

  String _getAssignedAgent() {
    // TODO: Get from API - for now return mock data
    return 'Unassigned';
  }

  String _getUpdatedTimeAgo() {
    if (widget.ticket.updatedAt == null) return '';

    final now = DateTime.now();
    final difference = now.difference(widget.ticket.updatedAt!);

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
                // TODO: Implement refresh
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
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Ticket Info (Subject + Meta)
            _buildTicketInfo(),

            // Tabs
            _buildTabBar(),

            // Tab Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        TicketDetailTab(ticket: widget.ticket),
                        TicketChatTab(
                          comments: _comments,
                          ticket: widget.ticket,
                          onSendMessage: _handleSendMessage,
                        ),
                        TicketFilesTab(attachments: _attachments),
                      ],
                    ),
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
            widget.ticket.subject,
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

  void _handleSendMessage(String message, String? attachmentPath) {
    // TODO: Implement send message via API
    final newComment = Comment(
      id: _comments.length + 1,
      ticketId: widget.ticket.id,
      userId: 1,
      userName: 'customer@test.com',
      userRole: 'customer',
      content: message,
      attachment: attachmentPath,
      createdAt: DateTime.now(),
    );

    setState(() {
      _comments.add(newComment);
    });
  }
}
