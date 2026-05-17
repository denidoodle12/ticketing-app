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

  /// Stores payload from cold-launch notification tap (app was killed)
  /// MainScreen will consume this after setting up the tap handler.
  String? _pendingNotificationPayload;

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

    // Check if app was launched by tapping a notification (cold start)
    await _checkAppLaunchNotification();
  }

  /// Check if the app was launched from a notification tap (cold start).
  /// If so, store the payload for MainScreen to consume later.
  Future<void> _checkAppLaunchNotification() async {
    try {
      final launchDetails = await _flutterLocalNotificationsPlugin
          .getNotificationAppLaunchDetails();
      if (launchDetails != null &&
          launchDetails.didNotificationLaunchApp &&
          launchDetails.notificationResponse?.payload != null) {
        _pendingNotificationPayload =
            launchDetails.notificationResponse!.payload;
      }
    } catch (_) {}
  }

  /// Check and consume any pending notification payload from cold launch.
  /// Returns the payload if one exists, then clears it.
  String? consumePendingNotificationPayload() {
    final payload = _pendingNotificationPayload;
    _pendingNotificationPayload = null;
    return payload;
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

  /// Get appropriate title based on notification type (clean, English)
  String _getNotificationTitle(NotificationItem notification) {
    switch (notification.type) {
      case NotificationType.statusChange:
        return 'Ticket Status Updated';
      case NotificationType.assignment:
        return 'Ticket Assigned';
      case NotificationType.overdue:
        return 'Ticket Overdue!';
      case NotificationType.warning:
        return 'SLA Warning';
      case NotificationType.autoClose:
        return 'Ticket Auto-Closed';
      case NotificationType.newComment:
        return 'New Comment';
      case NotificationType.unknown:
        return notification.title;
    }
  }

  /// Show a tray notification from raw SSE JSON data.
  /// This is used when the main isolate receives notification events from
  /// the background service, so that the notification is shown by the main
  /// isolate's plugin instance (which has the tap handler registered).
  Future<void> showFromRawJson(Map<String, dynamic> json) async {
    if (!_isInitialized) {
      await initialize();
    }

    final title = json['title'] as String? ?? 'New Notification';
    final message = json['message'] as String? ?? '';
    final type = json['type'] as String? ?? 'unknown';
    final ticketId = json['ticket_id'];
    // Use the same display ID from background service to replace its notification
    final notifId = json['_display_notif_id'] as int?
        ?? json['id'] as int?
        ?? DateTime.now().millisecondsSinceEpoch % 100000;

    // Determine display title by type
    String notifTitle;
    switch (type) {
      case 'status_change':
        notifTitle = 'Ticket Status Updated';
        break;
      case 'assignment':
        notifTitle = 'Ticket Assigned';
        break;
      case 'overdue':
        notifTitle = 'Ticket Overdue!';
        break;
      case 'warning':
        notifTitle = 'SLA Warning';
        break;
      case 'auto_close':
        notifTitle = 'Ticket Auto-Closed';
        break;
      case 'new_comment':
        notifTitle = 'New Comment';
        break;
      default:
        notifTitle = title;
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
      color: const Color(0xFF1E3A8A),
      icon: '@mipmap/ic_launcher',
      largeIcon:
          _appLogoBitmap ??
          const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(
        message,
        contentTitle: notifTitle,
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
      'notification_id': notifId,
      'ticket_id': ticketId,
      'type': type,
    });

    await _flutterLocalNotificationsPlugin.show(
      notifId,
      notifTitle,
      message,
      notificationDetails,
      payload: payload,
    );
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
