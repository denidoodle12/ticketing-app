import '../datasources/notification_remote_datasource.dart';
import '../models/notification_model.dart';

/// Repository for notification operations
abstract class NotificationRepository {
  /// Get paginated notification list
  Future<NotificationListResponse> getNotifications({int page, int limit});

  /// Get unread notification count
  Future<int> getUnreadCount();

  /// Mark a notification as read
  Future<void> markAsRead(int notificationId);

  /// Mark all notifications as read
  Future<void> markAllAsRead();
}

/// Implementation of NotificationRepository
class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDatasource _remoteDatasource;

  NotificationRepositoryImpl({NotificationRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? NotificationRemoteDatasource();

  @override
  Future<NotificationListResponse> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    return await _remoteDatasource.getNotifications(page: page, limit: limit);
  }

  @override
  Future<int> getUnreadCount() async {
    return await _remoteDatasource.getUnreadCount();
  }

  @override
  Future<void> markAsRead(int notificationId) async {
    await _remoteDatasource.markAsRead(notificationId);
  }

  @override
  Future<void> markAllAsRead() async {
    await _remoteDatasource.markAllAsRead();
  }
}
