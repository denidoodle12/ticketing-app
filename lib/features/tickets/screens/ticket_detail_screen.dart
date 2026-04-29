import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/network/chat_websocket_service.dart';
import '../../../core/constants/api_config.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../core/services/token_refresh_service.dart';
import '../../../data/datasources/local/local_storage.dart';
import '../../../providers/ticket_provider.dart';
import '../models/ticket_model.dart';
import '../models/comment_model.dart';
import '../widgets/ticket_detail_tab.dart';
import '../widgets/ticket_chat_tab.dart';
import '../widgets/ticket_files_tab.dart';
import '../widgets/ticket_rating_bottom_sheet.dart';
import '../widgets/star_rating_widget.dart';

class TicketDetailScreen extends StatefulWidget {
  final Ticket ticket;

  const TicketDetailScreen({super.key, required this.ticket});

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
  bool _isOffline = false;
  bool _isRatingExpanded = false;

  // Connectivity listener for real-time online/offline detection
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Cached token for image loading (set when connecting WebSocket)
  String? _cachedToken;

  // Scroll controller for NestedScrollView (outer scroll)
  late ScrollController _nestedScrollController;

  // Track current tab to conditionally show ticket info
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _nestedScrollController = ScrollController();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _currentTicket = widget.ticket;

    // Setup WebSocket callbacks
    _webSocketService.onMessageReceived = _handleWebSocketMessage;
    _webSocketService.onStateChanged = _handleWebSocketStateChange;
    _webSocketService.onError = _handleWebSocketError;
    _webSocketService.onTokenRefreshNeeded = _getRefreshedToken;

    // Listen to connectivity changes for real-time offline/online switch
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChange,
    );

    // Load ticket detail from API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTicketDetail();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _webSocketService.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _nestedScrollController.dispose();
    super.dispose();
  }

  /// Handle tab changes — reset scroll on Chat/Files, restore on Details
  void _handleTabChange() {
    final newIndex = _tabController.index;
    if (newIndex == _currentTabIndex) return;

    setState(() {
      _currentTabIndex = newIndex;
    });

    // Reset outer scroll to top so tab content starts at the top
    if (_nestedScrollController.hasClients) {
      _nestedScrollController.jumpTo(0);
    }
  }

  /// Calculate expanded height for SliverAppBar based on rating visibility
  double _getExpandedHeight() {
    const toolbarHeight = 68.0;
    const ticketInfoHeight = 90.0;
    const ratingBannerHeight = 84.0;
    const ratingCommentHeight = 80.0;

    final statusName = _currentTicket.status?.name.toLowerCase() ?? '';
    final showRating = statusName == 'closed';

    if (showRating) {
      final baseHeight = toolbarHeight + ticketInfoHeight + ratingBannerHeight;
      // Add extra height when rating comment is expanded
      if (_isRatingExpanded) {
        return baseHeight + ratingCommentHeight;
      }
      return baseHeight;
    }
    return toolbarHeight + ticketInfoHeight;
  }

  Future<void> _loadTicketDetail() async {
    final provider = context.read<TicketProvider>();
    // Clear stale rating state immediately to prevent card flash
    provider.clearRatingState();
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

      // Load rating for closed tickets only
      final statusName = _currentTicket.status?.name.toLowerCase() ?? '';
      if (statusName == 'closed') {
        provider.loadTicketRating(_currentTicket.id);
      }

      // Connect to WebSocket for real-time chat
      _connectWebSocket();
    }
  }

   /// Connect to WebSocket for real-time chat
  /// Always reads fresh token from secure storage to handle token refresh
  Future<void> _connectWebSocket() async {
    // Check connectivity first — don't attempt WebSocket when offline
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _wsState = WebSocketState.disconnected;
        });
      }
      return;
    }

    setState(() => _isOffline = false);

    // Always read fresh token from secure storage
    // (Dio interceptor saves refreshed tokens here on 401)
    if (!mounted) return;
    final localStorage = context.read<LocalStorage>();
    final token = await localStorage.getAccessToken();
    _cachedToken = token;

    if (mounted) {
      await _webSocketService.connect(
        ticketId: _currentTicket.id,
        token: token ?? '',
      );
    }
  }

  /// Handle connectivity changes in real-time
  /// Switches between offline placeholder and live chat seamlessly
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final isNowOffline = results.contains(ConnectivityResult.none);

    if (isNowOffline && !_isOffline) {
      // Just went offline — pause WebSocket, show placeholder
      _webSocketService.pauseConnection();
      if (mounted) {
        setState(() {
          _isOffline = true;
          _wsState = WebSocketState.disconnected;
        });
      }
    } else if (!isNowOffline && _isOffline) {
      // Just came back online — refresh detail data + reconnect with fresh token
      if (mounted) {
        setState(() => _isOffline = false);
        _loadTicketDetail();
        // _connectWebSocket() will be called by _loadTicketDetail after loading
      }
    }
  }

  /// Get auth headers for image loading (synchronous using cached token)
  Map<String, String>? get _authHeaders {
    if (_cachedToken != null) {
      return {'Authorization': 'Bearer $_cachedToken'};
    }
    return null;
  }

  /// Get fresh auth headers for downloads — reads latest token from storage
  /// This ensures downloads work even if the cached token has been refreshed
  Future<Map<String, String>> _getFreshAuthHeaders() async {
    final localStorage = context.read<LocalStorage>();
    final token = await localStorage.getAccessToken();
    if (token != null) {
      _cachedToken = token;
    }
    return {'Authorization': 'Bearer ${token ?? _cachedToken ?? ""}'};
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
            _attachments.add(
              TicketAttachment(
                fileName: _getFileNameFromPath(comment.attachment!),
                fileUrl: comment.attachment!,
                fileSize: 0,
                uploadedAt: comment.createdAt,
                uploadedBy: comment.isFromAgent ? comment.displayName : 'You',
                isFromAgent: comment.isFromAgent,
              ),
            );
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
  /// When reconnect fails after max attempts, tries fresh token reconnect if online
  void _handleWebSocketError(String error) {
    // Detect offline from error message as extra safety net
    final isNetworkError =
        error.contains('SocketException') ||
        error.contains('Failed host lookup') ||
        error.contains('No address associated');
    if (isNetworkError && !_isOffline) {
      // WebSocket failed due to network — switch to offline mode
      _webSocketService.pauseConnection();
      if (mounted) {
        setState(() {
          _isOffline = true;
          _wsState = WebSocketState.disconnected;
        });
      }
      return;
    }

    // When max reconnect attempts exhausted, try one more time with fresh token
    if (error.contains('Unable to reconnect') && !_isOffline) {
      _retryWithFreshToken();
      return;
    }

    if (mounted && !_isOffline) {
      ToastHelper.showWarning(
        context,
        'Chat connection error',
        description: error,
      );
    }
  }

  /// Attempt to reconnect WebSocket with a fresh token
  /// Called when max reconnect attempts fail (likely due to expired token)
  Future<void> _retryWithFreshToken() async {
    // Check if device is actually online first
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _wsState = WebSocketState.disconnected;
        });
      }
      return;
    }

    // Device is online — reconnect with fresh token
    _connectWebSocket();
  }

  /// Get a fresh token for WS reconnection by actually refreshing it.
  /// Uses TokenRefreshService to call /auth/refresh endpoint.
  /// This ensures the WebSocket reconnects with a valid, non-expired token.
  Future<String?> _getRefreshedToken() async {
    // Try to refresh the token via the centralized service
    final newToken = await TokenRefreshService.instance.refreshToken();
    if (newToken != null) {
      _cachedToken = newToken;
      // Restart proactive refresh timer after successful refresh
      TokenRefreshService.instance.startProactiveRefresh();
      return newToken;
    }

    // Refresh failed — fall back to stored token (may still work if recently refreshed by another component)
    if (!mounted) return _cachedToken;
    final localStorage = context.read<LocalStorage>();
    final token = await localStorage.getAccessToken();
    if (token != null) {
      _cachedToken = token;
    }
    return token;
  }

  List<Comment> _parseComments(List<dynamic> commentsJson) {
    return commentsJson
        .map((json) => Comment.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  List<TicketAttachment> _extractAttachments(
    List<Comment> comments,
    Ticket ticket,
  ) {
    final attachments = <TicketAttachment>[];

    // Add ticket attachment if exists
    if (ticket.attachment != null && ticket.attachment!.isNotEmpty) {
      attachments.add(
        TicketAttachment(
          fileName: _getFileNameFromPath(ticket.attachment!),
          fileUrl: ticket.attachment!,
          fileSize: 0,
          uploadedAt: ticket.createdAt ?? DateTime.now(),
          uploadedBy: 'You',
          isFromAgent: false,
        ),
      );
    }

    // Add attachments from comments
    for (final comment in comments) {
      if (comment.attachment != null && comment.attachment!.isNotEmpty) {
        attachments.add(
          TicketAttachment(
            fileName: _getFileNameFromPath(comment.attachment!),
            fileUrl: comment.attachment!,
            fileSize: 0,
            uploadedAt: comment.createdAt,
            uploadedBy: comment.isFromAgent ? comment.displayName : 'You',
            isFromAgent: comment.isFromAgent,
          ),
        );
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
    final isImage = [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
    ].contains(extension);

    if (isImage) {
      // Show image viewer dialog
      _showImageViewer(fullUrl, fileName);
    } else {
      // Open file in browser for download
      _openFileInBrowser(fullUrl, fileName);
    }
  }

  void _showImageViewer(String imageUrl, String fileName) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _ImageViewerScreen(
            imageUrl: imageUrl,
            fileName: fileName,
            authHeaders: _authHeaders,
            onDownload: () => _openFileInBrowser(imageUrl, fileName),
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

  Future<void> _openFileInBrowser(String url, String fileName) async {
    // Show bottom sheet with options
    if (!mounted) return;

    final isImage = _isImageFile(fileName);

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
                fileName,
                style: AppTextStyles.h6.copyWith(color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Save option - dynamic based on file type
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isImage
                      ? Icons.photo_library_rounded
                      : Icons.download_rounded,
                  color: AppColors.primaryDark,
                ),
              ),
              title: Text(
                isImage ? 'Save to Gallery' : 'Save to Downloads',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                isImage
                    ? 'Save image to Gallery > Ticketing App'
                    : 'Save file to Downloads folder',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _downloadToDevice(url, fileName);
              },
            ),
            // Share option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.share_rounded, color: AppColors.primaryDark),
              ),
              title: Text(
                'Share',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Share to other apps',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _shareFile(url, fileName);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Check if file is an image based on extension
  bool _isImageFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);
  }

  /// Download file to device - images go to Gallery, others go to Downloads
  Future<void> _downloadToDevice(String url, String fileName) async {
    // Check connectivity before downloading
    if (_isOffline) {
      if (mounted) {
        ToastHelper.showError(
          context,
          'Failed to Download Attachment',
          description: 'No internet connection. Please check your network.',
        );
      }
      return;
    }

    final isImage = _isImageFile(fileName);

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
      if (isImage) {
        // For images: Save to Gallery
        await _saveImageToGallery(url, fileName);
      } else {
        // For other files: Save to Downloads folder
        await _saveFileToDownloads(url, fileName);
      }
    } on DioException catch (e) {
      _handleDownloadError(e);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ToastHelper.showError(context, 'Download failed', description: '$e');
      }
    }
  }

  /// Save image to device Gallery
  Future<void> _saveImageToGallery(String url, String fileName) async {
    // Request photos permission for gallery access
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), need photos permission
      // For older versions, storage permission
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted && mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ToastHelper.showWarning(
            context,
            'Permission required',
            description: 'Gallery permission required to save images',
          );
          return;
        }
      }
    }

    // Download to temp directory first
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/$fileName';

    // Download file with fresh auth headers
    final dio = Dio();
    final headers = await _getFreshAuthHeaders();
    await dio.download(url, tempPath, options: Options(headers: headers));

    // Save to gallery with album name
    await Gal.putImage(tempPath, album: 'Ticketing App');

    // Delete temp file
    final tempFile = File(tempPath);
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ToastHelper.showSuccess(
        context,
        'Image saved',
        description: 'Saved to Gallery > Ticketing App',
      );
    }
  }

  /// Save non-image files to Downloads folder
  Future<void> _saveFileToDownloads(String url, String fileName) async {
    // Request storage permission for Android
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        // Try manage external storage for Android 11+
        final manageStatus = await Permission.manageExternalStorage.request();
        if (!manageStatus.isGranted && mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ToastHelper.showWarning(
            context,
            'Permission required',
            description: 'Storage permission required to save files',
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

    // Download file with fresh auth headers using Dio
    final dio = Dio();
    final headers = await _getFreshAuthHeaders();
    await dio.download(url, finalPath, options: Options(headers: headers));

    // Hide download snackbar and show success
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ToastHelper.showSuccess(
        context,
        'Download complete',
        description: 'Saved to Downloads',
      );
    }
  }

  /// Share file to other apps
  Future<void> _shareFile(String url, String fileName) async {
    // Check connectivity before sharing
    if (_isOffline) {
      if (mounted) {
        ToastHelper.showError(
          context,
          'Failed to Share Attachment',
          description: 'No internet connection. Please check your network.',
        );
      }
      return;
    }

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

      // Download file with fresh auth headers using Dio
      final dio = Dio();
      final headers = await _getFreshAuthHeaders();
      await dio.download(
        url,
        filePath,
        options: Options(headers: headers),
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
        ToastHelper.showError(context, 'Share failed', description: '$e');
      }
    }
  }

  void _handleDownloadError(DioException e) {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      String description = 'Please check your connection and try again';

      if (e.response?.statusCode == 401) {
        description = 'Unauthorized: Please login again';
      } else if (e.response?.statusCode == 403) {
        description = 'Access denied to this file';
      } else if (e.response?.statusCode == 404) {
        description = 'File not found on the server';
      }

      ToastHelper.showError(
        context,
        'Download Failed',
        description: description,
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final isDetailsTab = _currentTabIndex == 0;
    final expandedHeight = isDetailsTab ? _getExpandedHeight() : 68.0;

    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Consumer<TicketProvider>(
          builder: (context, provider, child) {
            return RefreshIndicator(
              onRefresh: _loadTicketDetail,
              color: AppColors.primary600,
              child: NestedScrollView(
                controller: _nestedScrollController,
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                  // Collapsible header — ticket info only visible on Details tab
                  SliverAppBar(
                    pinned: true,
                    floating: false,
                    expandedHeight: expandedHeight,
                    toolbarHeight: 68,
                    backgroundColor: AppColors.white,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    automaticallyImplyLeading: false,
                    leadingWidth: 76,
                    leading: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Center(
                        child: _buildActionButton(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    title: Text(
                      'Ticket Details',
                      style: AppTextStyles.h5.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    centerTitle: true,
                    // Smooth white sliver overlay — content fades into white bg
                    flexibleSpace: isDetailsTab
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              final currentHeight = constraints.maxHeight;
                              const toolbarHeight = 68.0;
                              final collapsibleRange =
                                  expandedHeight - toolbarHeight;
                              // 1.0 = fully expanded, 0.0 = fully collapsed
                              final expandProgress = collapsibleRange > 0
                                  ? ((currentHeight - toolbarHeight) /
                                            collapsibleRange)
                                        .clamp(0.0, 1.0)
                                  : 0.0;

                              return Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  // White background — always visible
                                  Positioned.fill(
                                    child: Container(color: AppColors.white),
                                  ),
                                  // Content fades out smoothly as it collapses
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: toolbarHeight,
                                    child: Opacity(
                                      opacity: expandProgress,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildTicketInfo(),
                                          _buildRatingSection(provider),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          )
                        : null,
                  ),

                  // Pinned tab bar
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverTabBarDelegate(_buildTabBarWidget()),
                  ),
                ];
              },
              body: provider.isTicketDetailLoading
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
                          isOffline: _isOffline,
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

  // _buildHeader() — integrated into SliverAppBar leading/title/actions

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
          child: Icon(icon, color: AppColors.primaryDark, size: 22),
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
              // Agent name — only show after detail API loads (avoids flash)
              if (_currentTicket.assigneeInfo != null &&
                  _currentTicket.assigneeInfo!.name.isNotEmpty) ...[
                Icon(
                  Icons.person_outline,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _currentTicket.assigneeInfo!.name,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 20),
              ],
              // Updated time
              Icon(Icons.access_time, size: 18, color: AppColors.textSecondary),
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

  /// Build rating section based on ticket status and rating state
  Widget _buildRatingSection(TicketProvider provider) {
    final statusName = _currentTicket.status?.name.toLowerCase() ?? '';

    // Only show for closed tickets
    if (statusName != 'closed') {
      return const SizedBox.shrink();
    }

    // Loading or not yet checked — show loading (prevents card flash)
    if (provider.isRatingLoading || !provider.isRatingChecked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: AppColors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.secondary500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading rating...',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Already rated - show read-only
    if (provider.hasRated && provider.currentRating != null) {
      return _buildRatedBanner(provider);
    }

    // Not rated yet - show rate button
    return _buildRateButton();
  }

  /// Banner showing existing rating (read-only, expandable for comment)
  Widget _buildRatedBanner(TicketProvider provider) {
    final rating = provider.currentRating!;
    final hasComment =
        rating.comment != null && rating.comment!.trim().isNotEmpty;

    return GestureDetector(
      onTap: hasComment
          ? () => setState(() => _isRatingExpanded = !_isRatingExpanded)
          : null,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [AppColors.primary600, AppColors.primary500],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main row: icon, info, badge
              Row(
                children: [
                  // Star icon with frosted circle
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.white.withAlpha(38),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Rating info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You have rated this ticket',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.white.withAlpha(190),
                          ),
                        ),
                        const SizedBox(height: 4),
                        StarRatingWidget(
                          rating: rating.rating,
                          starSize: 20,
                          readOnly: true,
                        ),
                      ],
                    ),
                  ),
                  // Rating number badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withAlpha(38),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${rating.rating}/5',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Expand arrow (only if has comment)
                  if (hasComment) ...[
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _isRatingExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppColors.white.withAlpha(180),
                      ),
                    ),
                  ],
                ],
              ),

              // Expandable comment section
              if (_isRatingExpanded && hasComment) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Feedback',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.white.withAlpha(160),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rating.comment!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.white.withAlpha(220),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Button to open rating bottom sheet
  Widget _buildRateButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.primary600, AppColors.primary500],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showRatingBottomSheet,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Star icon with frosted circle
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.white.withAlpha(38),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: AppColors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rate This Ticket',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Share your experience with this service',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.white.withAlpha(190),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.white.withAlpha(180),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show the rating bottom sheet
  Future<void> _showRatingBottomSheet() async {
    final provider = context.read<TicketProvider>();

    final result = await TicketRatingBottomSheet.show(
      context,
      _currentTicket.id,
    );

    if (!mounted) return;

    if (result == true) {
      // Success — bottom sheet already showed animation, just reload rating
      provider.loadTicketRating(_currentTicket.id);
    } else if (result == false) {
      // Submission failed — show error from provider
      ToastHelper.showError(
        context,
        'Failed to submit rating',
        description: provider.errorMessage ?? 'Please try again later',
      );
    }
  }

  /// Build TabBar widget for SliverPersistentHeader
  TabBar _buildTabBarWidget() {
    return TabBar(
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
    );
  }

  Future<void> _handleSendMessage(
    String message,
    String? attachmentPath,
  ) async {
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
        ToastHelper.showError(
          context,
          provider.errorMessage ?? 'Failed to upload attachment',
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
            _attachments.add(
              TicketAttachment(
                fileName: _getFileNameFromPath(comment.attachment!),
                fileUrl: comment.attachment!,
                fileSize: 0,
                uploadedAt: comment.createdAt,
                uploadedBy: 'You',
                isFromAgent: false,
              ),
            );
          }
        });
      } else if (mounted && provider.errorMessage != null) {
        ToastHelper.showError(context, provider.errorMessage!);
      }
    }

    if (mounted) {
      setState(() {
        _isSending = false;
      });
    }
  }
}

/// SliverPersistentHeaderDelegate for pinning the TabBar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height + 8;

  @override
  double get maxExtent => tabBar.preferredSize.height + 8;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tabBar,
          Container(
            height: 8,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withAlpha(15), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) => true;
}

/// Premium full-screen image viewer with zoom/pan, auto-hiding UI,
/// and glassmorphism download bar.
class _ImageViewerScreen extends StatefulWidget {
  final String imageUrl;
  final String fileName;
  final Map<String, String>? authHeaders;
  final VoidCallback onDownload;

  const _ImageViewerScreen({
    required this.imageUrl,
    required this.fileName,
    required this.authHeaders,
    required this.onDownload,
  });

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen>
    with SingleTickerProviderStateMixin {
  bool _showOverlay = true;
  late final AnimationController _overlayController;
  late final Animation<double> _overlayAnimation;
  final TransformationController _transformController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _overlayAnimation = CurvedAnimation(
      parent: _overlayController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _overlayController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
      if (_showOverlay) {
        _overlayController.forward();
      } else {
        _overlayController.reverse();
      }
    });
  }

  void _handleDoubleTap() {
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
    } else {
      _transformController.value = Matrix4.diagonal3Values(2.5, 2.5, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Image viewer with zoom/pan
          GestureDetector(
            onTap: _toggleOverlay,
            onDoubleTap: _handleDoubleTap,
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl,
                  httpHeaders: widget.authHeaders,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.white.withAlpha(200),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading image...',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.white.withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                  errorWidget: (context, url, error) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.white.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 56,
                          color: AppColors.white.withAlpha(130),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Failed to load image',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.white.withAlpha(180),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to try again',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.white.withAlpha(100),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Top bar — back button + title
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _overlayAnimation,
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
                        'Image Preview',
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
          ),

          // Bottom bar — filename + download button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FadeTransition(
              opacity: _overlayAnimation,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Filename
                    Row(
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 18,
                          color: AppColors.white.withAlpha(180),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.fileName,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.white.withAlpha(200),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Download button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onDownload();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.download_rounded, size: 20),
                        label: Text(
                          'Download',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
