import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../features/notifications/models/notification_model.dart';

/// Service for handling local notifications (phone tray notifications)
class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  static LocalNotificationService get instance => _instance;

  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Callback when notification is tapped
  static Function(String?)? onNotificationTap;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );

    _isInitialized = true;
  }

  /// Handle notification tap
  void _onNotificationResponse(NotificationResponse response) {
    if (onNotificationTap != null) {
      onNotificationTap!(response.payload);
    }
  }

  /// Handle background notification tap
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    if (onNotificationTap != null) {
      onNotificationTap!(response.payload);
    }
  }

  /// Request notification permission (for Android 13+)
  Future<bool> requestPermission() async {
    final androidPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }

    return true;
  }

  /// Show notification for a new NotificationItem from SSE
  Future<void> showNotification(NotificationItem notification) async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'ticketing_notifications',
      'Ticketing Notifications',
      channelDescription: 'Notifications for ticket updates and system alerts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'notification_id': notification.id,
      'ticket_id': notification.ticketId,
      'type': notification.type.name,
    });

    await _flutterLocalNotificationsPlugin.show(
      notification.id,
      _getNotificationTitle(notification),
      notification.message,
      notificationDetails,
      payload: payload,
    );
  }

  /// Get appropriate title based on notification type
  String _getNotificationTitle(NotificationItem notification) {
    switch (notification.type) {
      case NotificationType.statusChange:
        return '📋 Status Ticket Diperbarui';
      case NotificationType.assignment:
        return '👤 Ticket Ditugaskan';
      case NotificationType.overdue:
        return '⏰ Ticket Overdue!';
      case NotificationType.warning:
        return '⚠️ Peringatan SLA';
      case NotificationType.autoClose:
        return '✅ Ticket Ditutup Otomatis';
      case NotificationType.newComment:
        return '💬 Komentar Baru';
      case NotificationType.unknown:
        return '🔔 ${notification.title}';
    }
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}
