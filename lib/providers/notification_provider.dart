import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/services/background_notification_service.dart';
import '../features/notifications/models/notification_model.dart';
import '../features/notifications/repositories/notification_repository.dart';

/// Provider for notification state management
class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _repository;
  final BackgroundNotificationService _backgroundService =
      BackgroundNotificationService.instance;

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
  StreamSubscription? _backgroundNotificationSubscription;

  NotificationProvider(this._repository);

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

  /// Listen to notifications from background service
  void listenToBackgroundService() {
    _backgroundNotificationSubscription?.cancel();

    _backgroundNotificationSubscription = _backgroundService
        .on('newNotification')
        .listen((event) {
          if (event != null) {
            try {
              final notification = NotificationItem.fromJson(
                Map<String, dynamic>.from(event),
              );

              _notifications.insert(0, notification);
              if (!notification.isRead) {
                _unreadCount++;
              }

              notifyListeners();
            } catch (_) {}
          }
        });

    _isConnected = true;
    notifyListeners();
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
    } catch (_) {
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
    } catch (_) {
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(int notificationId) async {
    try {
      await _repository.markAsRead(notificationId);

      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllAsRead();

      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Refresh notifications and unread count
  Future<void> refresh() async {
    await Future.wait([fetchNotifications(), fetchUnreadCount()]);
  }

  /// Clear all state (for logout)
  void clear() {
    _backgroundNotificationSubscription?.cancel();
    _backgroundService.stopService();
    _notifications = [];
    _unreadCount = 0;
    _currentPage = 1;
    _hasMore = true;
    _error = null;
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _backgroundNotificationSubscription?.cancel();
    super.dispose();
  }
}
