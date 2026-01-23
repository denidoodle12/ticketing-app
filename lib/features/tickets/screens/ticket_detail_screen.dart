import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/network/chat_websocket_service.dart';
import '../../../core/constants/api_config.dart';
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

  // Cached token for image loading (set when connecting WebSocket)
  String? _cachedToken;

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
      // Cache token first before displaying comments (for image auth)
      final localStorage = context.read<LocalStorage>();
      _cachedToken = await localStorage.getAccessToken();

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
    // Use cached token if available, otherwise fetch from storage
    String? token = _cachedToken;
    if (token == null) {
      final localStorage = context.read<LocalStorage>();
      token = await localStorage.getAccessToken();
      _cachedToken = token;
    }

    if (token != null && mounted) {
      await _webSocketService.connect(
        ticketId: _currentTicket.id,
        token: token,
      );
    }
  }

  /// Get auth headers for image loading (synchronous using cached token)
  Map<String, String>? get _authHeaders {
    if (_cachedToken != null) {
      return {'Authorization': 'Bearer $_cachedToken'};
    }
    return null;
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

  /// Get full attachment URL for chat uploads and ticket attachments
  String _getAttachmentUrl(String attachmentPath) {
    // If already a full URL, return as is
    if (attachmentPath.startsWith('http://') ||
        attachmentPath.startsWith('https://')) {
      return attachmentPath;
    }

    // Chat uploads have path format: /chat-uploads/filename.ext
    if (attachmentPath.startsWith('/')) {
      return '${ApiConfig.baseUrl}$attachmentPath';
    }

    // Ticket attachments are just filenames, need /uploads/ prefix
    return '${ApiConfig.baseUrl}/uploads/$attachmentPath';
  }

  /// Handle attachment tap - open image viewer or download file
  Future<void> _handleAttachmentTap(String attachmentPath) async {
    final fullUrl = _getAttachmentUrl(attachmentPath);
    final fileName = _getFileNameFromPath(attachmentPath);
    final extension = fileName.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);

    if (isImage) {
      // Show image viewer dialog
      _showImageViewer(fullUrl, fileName);
    } else {
      // Open file in browser for download
      _openFileInBrowser(fullUrl, fileName);
    }
  }

  void _showImageViewer(String imageUrl, String fileName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            // Image viewer with auth headers
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  httpHeaders: _authHeaders,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    width: 300,
                    height: 300,
                    color: AppColors.black.withAlpha(200),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.white,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 300,
                    height: 200,
                    color: AppColors.black.withAlpha(200),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 64,
                          color: AppColors.white.withAlpha(150),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load image',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.black.withAlpha(150),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            // File name and download button at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.black.withAlpha(180),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        fileName,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _openFileInBrowser(imageUrl, fileName),
                      icon: const Icon(
                        Icons.download_rounded,
                        color: AppColors.white,
                        size: 18,
                      ),
                      label: Text(
                        'Download',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFileInBrowser(String url, String fileName) async {
    // Show bottom sheet with options
    if (!mounted) return;

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                fileName,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success500.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.download_rounded,
                  color: AppColors.success500,
                ),
              ),
              title: const Text('Save to Downloads'),
              subtitle: const Text('Save file to device storage'),
              onTap: () {
                Navigator.pop(context);
                _downloadToDevice(url, fileName);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.share_rounded,
                  color: AppColors.primary,
                ),
              ),
              title: const Text('Share'),
              subtitle: const Text('Share to other apps'),
              onTap: () {
                Navigator.pop(context);
                _shareFile(url, fileName);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Download file to device Downloads folder
  Future<void> _downloadToDevice(String url, String fileName) async {
    // Show downloading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Downloading $fileName...')),
            ],
          ),
          duration: const Duration(seconds: 60),
          backgroundColor: AppColors.primary,
        ),
      );
    }

    try {
      // Request storage permission for Android
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          // Try manage external storage for Android 11+
          final manageStatus = await Permission.manageExternalStorage.request();
          if (!manageStatus.isGranted && mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Storage permission required to save files'),
                backgroundColor: AppColors.warning500,
              ),
            );
            return;
          }
        }
      }

      // Get Downloads directory
      String downloadPath;
      if (Platform.isAndroid) {
        // Android Downloads folder
        downloadPath = '/storage/emulated/0/Download';
        // Create directory if not exists
        final dir = Directory(downloadPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      } else {
        // iOS - use app documents directory
        final docDir = await getApplicationDocumentsDirectory();
        downloadPath = docDir.path;
      }

      final filePath = '$downloadPath/$fileName';

      // Check if file already exists, add number suffix if needed
      String finalPath = filePath;
      int counter = 1;
      while (await File(finalPath).exists()) {
        final extension = fileName.contains('.')
            ? '.${fileName.split('.').last}'
            : '';
        final nameWithoutExt = fileName.contains('.')
            ? fileName.substring(0, fileName.lastIndexOf('.'))
            : fileName;
        finalPath = '$downloadPath/${nameWithoutExt}_($counter)$extension';
        counter++;
      }

      // Download file with auth headers using Dio
      final dio = Dio();
      await dio.download(
        url,
        finalPath,
        options: Options(
          headers: _authHeaders,
        ),
      );

      // Hide download snackbar and show success
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Download complete'),
                      Text(
                        'Saved to Downloads',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.white.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success500,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on DioException catch (e) {
      _handleDownloadError(e);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error500,
          ),
        );
      }
    }
  }

  /// Share file to other apps
  Future<void> _shareFile(String url, String fileName) async {
    // Show downloading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Preparing $fileName...')),
            ],
          ),
          duration: const Duration(seconds: 30),
          backgroundColor: AppColors.primary,
        ),
      );
    }

    try {
      // Download to temp directory first
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      // Download file with auth headers using Dio
      final dio = Dio();
      await dio.download(
        url,
        filePath,
        options: Options(
          headers: _authHeaders,
        ),
      );

      // Hide download snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      // Share the downloaded file
      final xFile = XFile(filePath);
      await Share.shareXFiles([xFile]);
    } on DioException catch (e) {
      _handleDownloadError(e);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error500,
          ),
        );
      }
    }
  }

  void _handleDownloadError(DioException e) {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      String errorMessage = 'Download failed';
      if (e.response?.statusCode == 401) {
        errorMessage = 'Unauthorized: Please login again';
      } else if (e.response?.statusCode == 403) {
        errorMessage = 'Access denied to this file';
      } else if (e.response?.statusCode == 404) {
        errorMessage = 'File not found';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.error500,
        ),
      );
    }
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
      resizeToAvoidBottomInset: false,
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
                                  getAttachmentUrl: _getAttachmentUrl,
                                  onAttachmentTap: _handleAttachmentTap,
                                  authHeaders: _authHeaders,
                                ),
                                TicketFilesTab(
                                  attachments: _attachments,
                                  getAttachmentUrl: _getAttachmentUrl,
                                  onImagePreview: _showImageViewer,
                                  onFileOpen: _openFileInBrowser,
                                  authHeaders: _authHeaders,
                                ),
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

    String? attachmentUrl;

    // Upload attachment first if provided
    if (attachmentPath != null && attachmentPath.isNotEmpty && mounted) {
      attachmentUrl = await provider.uploadCommentAttachment(
        ticketId: _currentTicket.id,
        filePath: attachmentPath,
      );

      if (attachmentUrl == null && mounted) {
        // Upload failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to upload attachment'),
            backgroundColor: AppColors.error500,
          ),
        );
        setState(() {
          _isSending = false;
        });
        return;
      }
    }

    bool sent = false;

    // Try WebSocket first if connected
    if (_webSocketService.isConnected) {
      sent = await _webSocketService.sendMessage(
        content: message.isNotEmpty ? message : null,
        attachment: attachmentUrl,
      );
    }

    // Fallback to REST API if WebSocket fails or not connected
    if (!sent && mounted) {
      final comment = await provider.createComment(
        ticketId: _currentTicket.id,
        content: message.isNotEmpty ? message : null,
        attachmentUrl: attachmentUrl,
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
