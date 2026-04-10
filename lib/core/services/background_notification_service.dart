import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background notification service that runs SSE in a foreground service
/// This keeps the SSE connection alive even when the app is minimized
class BackgroundNotificationService {
  static final BackgroundNotificationService _instance =
      BackgroundNotificationService._internal();
  static BackgroundNotificationService get instance => _instance;

  BackgroundNotificationService._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();

  static const String _tokenKey = 'sse_access_token';
  static const String _refreshTokenKey = 'sse_refresh_token';

  /// Initialize the background service
  Future<void> initialize() async {
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

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await notificationsPlugin.initialize(initSettings);

  // SSE connection variables
  HttpClient? sseClient;
  StreamSubscription? sseSubscription;
  String? accessToken;
  String? refreshToken;
  String currentEvent = '';
  String currentData = '';
  int notificationIdCounter = 100;

  // Auto-reconnect variables
  bool shouldReconnect = true;
  int reconnectAttempts = 0;
  const maxReconnectAttempts = 50;
  Timer? reconnectTimer;

  // SSE URL
  const baseUrl = 'https://magang.damarbrawijaya.my.id';
  const sseEndpoint = '/notifications/stream';
  const authRefreshEndpoint = '/auth/refresh';

  /// Try to refresh the access token using the refresh token
  Future<String?> refreshAccessToken() async {
    if (refreshToken == null || refreshToken!.isEmpty) return null;

    try {
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 10);

      final uri = Uri.parse('$baseUrl$authRefreshEndpoint');
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
          accessToken = newToken;
          // Persist the new token so reconnects use the fresh one
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('sse_access_token', newToken);
          // Sync token back to main isolate so FlutterSecureStorage stays updated
          service.invoke('tokenSynced', {'token': newToken});
          return newToken;
        }
      }
      httpClient.close();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Connect to SSE stream
  Future<void> connectSSE() async {
    if (accessToken == null || accessToken!.isEmpty) return;

    try {
      sseClient?.close(force: true);
      sseSubscription?.cancel();

      sseClient = HttpClient();
      sseClient!.idleTimeout = const Duration(minutes: 30);
      sseClient!.connectionTimeout = const Duration(seconds: 30);

      final uri = Uri.parse('$baseUrl$sseEndpoint');
      final request = await sseClient!.getUrl(uri);
      request.headers.set('Authorization', 'Bearer $accessToken');
      request.headers.set('Accept', 'text/event-stream');
      request.headers.set('Cache-Control', 'no-cache');
      request.headers.set('Connection', 'keep-alive');

      final response = await request.close();

      if (response.statusCode == 200) {
        reconnectAttempts = 0;

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'Ticketing App',
            content: 'Notification active',
          );
        }

        sseSubscription = response
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                if (line.startsWith(':')) return;

                if (line.isEmpty) {
                  if (currentEvent.isNotEmpty && currentData.isNotEmpty) {
                    _processSSEEvent(
                      currentEvent,
                      currentData,
                      notificationsPlugin,
                      service,
                      notificationIdCounter++,
                    );
                  }
                  currentEvent = '';
                  currentData = '';
                  return;
                }

                if (line.startsWith('event:')) {
                  currentEvent = line.substring(6).trim();
                } else if (line.startsWith('data:')) {
                  currentData = line.substring(5).trim();
                }
              },
              onError: (_) {
                // SSE error — schedule reconnect with current token
                // (which may have been updated by main app's proactive refresh)
                // If token is expired, connectSSE()'s 401 handler will refresh
                _scheduleReconnect(
                  reconnectTimer,
                  reconnectAttempts,
                  maxReconnectAttempts,
                  shouldReconnect,
                  connectSSE,
                  service,
                  (t) => reconnectTimer = t,
                  () => reconnectAttempts++,
                );
              },
              onDone: () {
                // SSE stream closed by server — schedule reconnect
                // The proactive timer in main app pushes fresh tokens via updateToken,
                // so the local accessToken variable should already be up-to-date.
                // Only connectSSE()'s 401 handler refreshes as a last resort.
                _scheduleReconnect(
                  reconnectTimer,
                  reconnectAttempts,
                  maxReconnectAttempts,
                  shouldReconnect,
                  connectSSE,
                  service,
                  (t) => reconnectTimer = t,
                  () => reconnectAttempts++,
                );
              },
              cancelOnError: false,
            );
      } else if (response.statusCode == 401) {
        // Token expired — try to refresh (last resort, only if proactive timer didn't push a new token)
        final newToken = await refreshAccessToken();
        if (newToken != null) {
          // Successfully refreshed — reconnect with new token
          reconnectAttempts = 0;
          connectSSE();
        } else {
          // Refresh failed — session expired, stop reconnecting
          shouldReconnect = false;
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: 'Ticketing App',
              content: 'Session expired',
            );
          }
        }
      } else {
        _scheduleReconnect(
          reconnectTimer,
          reconnectAttempts,
          maxReconnectAttempts,
          shouldReconnect,
          connectSSE,
          service,
          (t) => reconnectTimer = t,
          () => reconnectAttempts++,
        );
      }
    } catch (_) {
      _scheduleReconnect(
        reconnectTimer,
        reconnectAttempts,
        maxReconnectAttempts,
        shouldReconnect,
        connectSSE,
        service,
        (t) => reconnectTimer = t,
        () => reconnectAttempts++,
      );
    }
  }

  // Listen for token updates from UI isolate
  service.on('updateToken').listen((event) {
    if (event != null && event['token'] != null) {
      accessToken = event['token'] as String;
      if (event['refreshToken'] != null) {
        refreshToken = event['refreshToken'] as String;
      }
      connectSSE();
    }
  });

  // Listen for stop command
  service.on('stopService').listen((event) {
    shouldReconnect = false;
    reconnectTimer?.cancel();
    sseSubscription?.cancel();
    sseClient?.close(force: true);
    service.stopSelf();
  });

  // Auto-recover: load saved tokens on service start
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
  } catch (_) {}
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
      } catch (_) {}
      break;
    default:
      break;
  }
}

/// Schedule auto-reconnect with exponential backoff
void _scheduleReconnect(
  Timer? currentTimer,
  int attempts,
  int maxAttempts,
  bool shouldReconnect,
  Future<void> Function() connectFn,
  ServiceInstance service,
  void Function(Timer?) setTimer,
  void Function() incrementAttempts,
) {
  if (!shouldReconnect || attempts >= maxAttempts) {
    if (attempts >= maxAttempts) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Ticketing App',
          content: 'Connection lost',
        );
      }
    }
    return;
  }

  incrementAttempts();
  final delay = Duration(seconds: (2 * (attempts + 1)).clamp(2, 60));

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: 'Ticketing App',
      content: 'Reconnecting...',
    );
  }

  currentTimer?.cancel();
  setTimer(Timer(delay, () => connectFn()));
}
