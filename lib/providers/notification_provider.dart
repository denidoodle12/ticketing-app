import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/network/notification_sse_service.dart';
import '../features/notifications/models/notification_model.dart';
import '../features/notifications/repositories/notification_repository.dart';

/// Provider for notification state management
class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _repository;
  final NotificationSSEService _sseService = NotificationSSEService.instance;

  // State
  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isConnected = false;

  // Stream subscriptions
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _connectionSubscription;

  NotificationProvider(this._repository) {
    _setupSSEListeners();
  }

  // Getters
  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasMore => _hasMore;
  bool get isConnected => _isConnected;

  /// Get unread notifications only
  List<NotificationItem> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  /// Get ticket-related notifications only
  List<NotificationItem> get ticketNotifications =>
      _notifications.where((n) => n.ticketId != null).toList();

  /// Get system notifications (without ticket_id)
  List<NotificationItem> get systemNotifications =>
      _notifications.where((n) => n.ticketId == null).toList();

  void _setupSSEListeners() {
    // Listen to new notifications from SSE
    _notificationSubscription = _sseService.notificationStream.listen((
      notification,
    ) {
      // Add new notification to the top of the list
      _notifications.insert(0, notification);
      if (!notification.isRead) {
        _unreadCount++;
      }
      notifyListeners();
    });

    // Listen to connection state changes
    _connectionSubscription = _sseService.connectionStateStream.listen((
      isConnected,
    ) {
      _isConnected = isConnected;
      notifyListeners();
    });
  }

  /// Connect to SSE stream
  Future<void> connect(String accessToken) async {
    await _sseService.connect(accessToken);
  }

  /// Disconnect from SSE stream
  void disconnect() {
    _sseService.disconnect();
  }

  /// Fetch initial notifications
  Future<void> fetchNotifications() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _currentPage = 1;
    notifyListeners();

    try {
      final response = await _repository.getNotifications(page: 1);
      _notifications = response.items;
      _hasMore = response.hasMore;
      _currentPage = 1;
    } catch (e) {
      _error = e.toString();
      debugPrint('[NotificationProvider] Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load more notifications (pagination)
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final response = await _repository.getNotifications(page: nextPage);
      _notifications.addAll(response.items);
      _hasMore = response.hasMore;
      _currentPage = nextPage;
    } catch (e) {
      debugPrint('[NotificationProvider] Error loading more: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Fetch unread count
  Future<void> fetchUnreadCount() async {
    try {
      _unreadCount = await _repository.getUnreadCount();
      notifyListeners();
    } catch (e) {
      debugPrint('[NotificationProvider] Error fetching unread count: $e');
      // Fallback: calculate from loaded notifications
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(int notificationId) async {
    try {
      await _repository.markAsRead(notificationId);

      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[NotificationProvider] Error marking as read: $e');
      rethrow;
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllAsRead();

      // Update local state
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('[NotificationProvider] Error marking all as read: $e');
      rethrow;
    }
  }

  /// Refresh notifications and unread count
  Future<void> refresh() async {
    await Future.wait([fetchNotifications(), fetchUnreadCount()]);
  }

  /// Clear all state (for logout)
  void clear() {
    disconnect();
    _notifications = [];
    _unreadCount = 0;
    _currentPage = 1;
    _hasMore = true;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _connectionSubscription?.cancel();
    _sseService.dispose();
    super.dispose();
  }
}
