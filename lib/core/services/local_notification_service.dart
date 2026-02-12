import 'dart:convert';
import 'package:flutter/services.dart';
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
  ByteArrayAndroidBitmap? _appLogoBitmap;

  /// Callback when notification is tapped
  static Function(String?)? onNotificationTap;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Pre-load app logo for large icon
    await _loadAppLogo();

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

  /// Load app logo from assets for use as large icon
  Future<void> _loadAppLogo() async {
    try {
      final byteData = await rootBundle.load(
        'assets/images/logos/app_logo.png',
      );
      _appLogoBitmap = ByteArrayAndroidBitmap(byteData.buffer.asUint8List());
    } catch (_) {
      // Fallback: logo not available, will use default
      _appLogoBitmap = null;
    }
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

    final androidDetails = AndroidNotificationDetails(
      'ticketing_notifications',
      'Ticketing Notifications',
      channelDescription: 'Notifications for ticket updates and system alerts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      color: const Color(0xFF1E3A8A), // primaryDark accent color
      icon: '@mipmap/ic_launcher',
      largeIcon:
          _appLogoBitmap ??
          const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(
        notification.message,
        contentTitle: _getNotificationTitle(notification),
        summaryText: 'Ticketing App',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
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

  /// Get appropriate title based on notification type (clean, no emoji)
  String _getNotificationTitle(NotificationItem notification) {
    switch (notification.type) {
      case NotificationType.statusChange:
        return 'Status Ticket Diperbarui';
      case NotificationType.assignment:
        return 'Ticket Ditugaskan';
      case NotificationType.overdue:
        return 'Ticket Overdue!';
      case NotificationType.warning:
        return 'Peringatan SLA';
      case NotificationType.autoClose:
        return 'Ticket Ditutup Otomatis';
      case NotificationType.newComment:
        return 'Komentar Baru';
      case NotificationType.unknown:
        return notification.title;
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
