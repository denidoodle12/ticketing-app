import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../native/ca_bundle.dart';
import '../native/native_sse.dart';

/// Background notification service that runs SSE in a foreground service
/// using native C++ (libcurl) for rock-solid long-lived connections.
///
/// Architecture:
///   main isolate → flutter_background_service → background isolate
///   background isolate → NativeSse (FFI) → libjavaloader.so worker thread
///   native worker → SSE stream → NativeCallable.listener → Dart callback
class BackgroundNotificationService {
  static final BackgroundNotificationService _instance =
      BackgroundNotificationService._internal();
  static BackgroundNotificationService get instance => _instance;

  BackgroundNotificationService._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();

  static const String _tokenKey = 'sse_access_token';
  static const String _refreshTokenKey = 'sse_refresh_token';

  // SSE configuration
  static const String _baseUrl = 'https://magang.damarbrawijaya.my.id';
  static const String _sseEndpoint = '/notifications/stream';

  /// Initialize the background service
  Future<void> initialize() async {
    // Silent channel for foreground service notification (not visible to user)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'sse_bg_silent',
      'Background Service',
      description: 'Keeps notification connection active',
      importance: Importance.none,
      enableVibration: false,
      playSound: false,
      showBadge: false,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        autoStartOnBoot: true,
        isForegroundMode: true,
        foregroundServiceNotificationId: 888,
        initialNotificationTitle: '',
        initialNotificationContent: '',
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
        notificationChannelId: 'sse_bg_silent',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  /// Start the background service with access token and refresh token
  Future<void> startService(String accessToken, {String? refreshToken}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    if (refreshToken != null) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }

    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('updateToken', {
        'token': accessToken,
        if (refreshToken != null) 'refreshToken': refreshToken,
      });
      return;
    }

    await _service.startService();
    await Future.delayed(const Duration(seconds: 1));
    _service.invoke('updateToken', {
      'token': accessToken,
      if (refreshToken != null) 'refreshToken': refreshToken,
    });
  }

  /// Stop the background service
  Future<void> stopService() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    _service.invoke('stopService');
  }

  /// Listen to notification events from background service
  Stream<Map<String, dynamic>?> on(String method) {
    return _service.on(method);
  }

  /// Check if service is running
  Future<bool> isRunning() async {
    return await _service.isRunning();
  }
}

// ============================================================
// BACKGROUND ISOLATE - runs in a separate Dart isolate
// ============================================================

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // ── Initialize local notifications ──
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await notificationsPlugin.initialize(initSettings);

  // Pre-create the notification channel with Importance.max
  // so popups actually appear (auto-created channels default to LOW)
  const AndroidNotificationChannel notifChannel = AndroidNotificationChannel(
    'ticketing_notifications',
    'Ticketing Notifications',
    description: 'Notifications for ticket updates and system alerts',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );
  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(notifChannel);

  // ── Variables ──
  String? accessToken;
  String? refreshToken;
  int notificationIdCounter = 100;
  final sse = NativeSse.instance;

  // ── Extract CA bundle ──
  String? caBundlePath;
  try {
    caBundlePath = await CaBundle.ensureExtracted();
    debugPrint('[BgService] CA bundle at: $caBundlePath');
  } catch (e) {
    debugPrint('[BgService] CA bundle extraction failed: $e');
  }

  // ── SSE connect function ──
  void connectSSE() {
    if (accessToken == null || accessToken!.isEmpty) {
      debugPrint('[BgService] no token; skipping SSE connect');
      return;
    }

    const sseUrl =
        '${BackgroundNotificationService._baseUrl}${BackgroundNotificationService._sseEndpoint}';

    sse.start(
      url: sseUrl,
      token: accessToken!,
      caBundlePath: caBundlePath ?? '',
      onEvent: (String event, String data) {
        debugPrint('[BgService] SSE event: $event (data_len=${data.length})');
        _processSSEEvent(
          event,
          data,
          notificationsPlugin,
          service,
          notificationIdCounter++,
        );
      },
      onStatus: (NativeSseStatus status, String? info) {
        debugPrint('[BgService] SSE status: ${status.name} info=$info');

        if (service is AndroidServiceInstance) {
          switch (status) {
            case NativeSseStatus.connected:
              service.setForegroundNotificationInfo(
                title: 'Ticketing App',
                content: 'Notification active',
              );
              break;
            case NativeSseStatus.connecting:
            case NativeSseStatus.reconnecting:
              service.setForegroundNotificationInfo(
                title: 'Ticketing App',
                content: 'Reconnecting...',
              );
              break;
            case NativeSseStatus.unauthorized:
              // Token expired — try refresh
              _handleUnauthorized(
                service,
                refreshToken,
                (newToken) {
                  accessToken = newToken;
                  sse.updateToken(newToken);
                },
              );
              break;
            case NativeSseStatus.disconnected:
            case NativeSseStatus.fatal:
              service.setForegroundNotificationInfo(
                title: 'Ticketing App',
                content: 'Connection lost',
              );
              break;
          }
        }
      },
    );
  }

  // ── Listen for token updates from UI isolate ──
  service.on('updateToken').listen((event) {
    if (event != null && event['token'] != null) {
      accessToken = event['token'] as String;
      if (event['refreshToken'] != null) {
        refreshToken = event['refreshToken'] as String;
      }

      if (sse.isRunning) {
        sse.updateToken(accessToken!);
      } else {
        connectSSE();
      }
    }
  });

  // ── Listen for stop command ──
  service.on('stopService').listen((event) {
    debugPrint('[BgService] stop requested');
    sse.stop();
    service.stopSelf();
  });

  // ── Auto-recover: load saved tokens on service start ──
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('sse_access_token');
    final savedRefreshToken = prefs.getString('sse_refresh_token');
    if (savedRefreshToken != null && savedRefreshToken.isNotEmpty) {
      refreshToken = savedRefreshToken;
    }
    if (savedToken != null && savedToken.isNotEmpty) {
      accessToken = savedToken;
      connectSSE();
    }
  } catch (e) {
    debugPrint('[BgService] auto-recover failed: $e');
  }
}

/// Handle 401 unauthorized — try to refresh the access token
Future<void> _handleUnauthorized(
  ServiceInstance service,
  String? refreshToken,
  void Function(String newToken) onSuccess,
) async {
  if (refreshToken == null || refreshToken.isEmpty) {
    debugPrint('[BgService] no refresh token; cannot recover from 401');
    return;
  }

  try {
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 10);

    const refreshUrl =
        '${BackgroundNotificationService._baseUrl}/auth/refresh';
    final uri = Uri.parse(refreshUrl);
    final request = await httpClient.postUrl(uri);
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Accept', 'application/json');
    request.write(jsonEncode({'refresh_token': refreshToken}));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>?;
      final newToken = data?['access_token'] as String?;

      if (newToken != null) {
        // Persist and sync back
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('sse_access_token', newToken);
        service.invoke('tokenSynced', {'token': newToken});
        onSuccess(newToken);
        debugPrint('[BgService] token refreshed successfully');
      }
    }
    httpClient.close();
  } catch (e) {
    debugPrint('[BgService] token refresh failed: $e');
  }
}

/// Process SSE events and show local notifications
void _processSSEEvent(
  String event,
  String data,
  FlutterLocalNotificationsPlugin notificationsPlugin,
  ServiceInstance service,
  int notificationId,
) {
  switch (event) {
    case 'connected':
      debugPrint('[BgService] SSE connected event received');
      break;
    case 'notification':
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final title = json['title'] as String? ?? 'New Notification';
        final message = json['message'] as String? ?? '';
        final type = json['type'] as String? ?? 'unknown';
        final ticketId = json['ticket_id'];

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

        notificationsPlugin.show(
          notificationId,
          notifTitle,
          message,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'ticketing_notifications',
              'Ticketing Notifications',
              channelDescription:
                  'Notifications for ticket updates and system alerts',
              importance: Importance.high,
              priority: Priority.high,
              showWhen: true,
              enableVibration: true,
              playSound: true,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: jsonEncode({
            'notification_id': json['id'],
            'ticket_id': ticketId,
            'type': type,
          }),
        );

        service.invoke('newNotification', json);
        debugPrint(
            '[BgService] notification shown: $notifTitle - $message');
      } catch (e) {
        debugPrint('[BgService] failed to process notification event: $e');
      }
      break;
    default:
      debugPrint('[BgService] unhandled SSE event: $event');
      break;
  }
}

