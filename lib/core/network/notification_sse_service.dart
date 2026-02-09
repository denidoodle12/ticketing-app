import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';
import '../constants/api_endpoints.dart';
import '../../features/notifications/models/notification_model.dart';

/// Service for handling Server-Sent Events (SSE) connection for real-time notifications
class NotificationSSEService {
  static NotificationSSEService? _instance;
  static NotificationSSEService get instance {
    _instance ??= NotificationSSEService._();
    return _instance!;
  }

  NotificationSSEService._();

  http.Client? _client;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  String? _accessToken;

  // Stream controllers
  final _notificationController =
      StreamController<NotificationItem>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  /// Stream of incoming notifications
  Stream<NotificationItem> get notificationStream =>
      _notificationController.stream;

  /// Stream of connection state changes
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  /// Current connection state
  bool get isConnected => _isConnected;

  /// Connect to SSE stream with the given access token
  Future<void> connect(String accessToken) async {
    if (_isConnected) {
      debugPrint('[SSE] Already connected, skipping...');
      return;
    }

    _accessToken = accessToken;
    await _startConnection();
  }

  Future<void> _startConnection() async {
    if (_accessToken == null) {
      debugPrint('[SSE] No access token available');
      return;
    }

    try {
      _client = http.Client();

      final url = '${ApiConfig.baseUrl}${ApiEndpoints.notificationsStream}';
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $_accessToken';
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      debugPrint('[SSE] Connecting to: $url');

      final response = await _client!.send(request);

      if (response.statusCode == 200) {
        _isConnected = true;
        _connectionStateController.add(true);
        debugPrint('[SSE] Connected successfully');

        // Listen to the stream
        _subscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              _handleSSELine,
              onError: (error) {
                debugPrint('[SSE] Stream error: $error');
                _handleDisconnect();
              },
              onDone: () {
                debugPrint('[SSE] Stream closed');
                _handleDisconnect();
              },
              cancelOnError: false,
            );
      } else {
        debugPrint(
          '[SSE] Connection failed with status: ${response.statusCode}',
        );
        _handleDisconnect();
      }
    } catch (e) {
      debugPrint('[SSE] Connection error: $e');
      _handleDisconnect();
    }
  }

  String _currentEvent = '';
  String _currentData = '';

  void _handleSSELine(String line) {
    if (line.isEmpty) {
      // Empty line = end of event, process it
      if (_currentEvent.isNotEmpty && _currentData.isNotEmpty) {
        _processEvent(_currentEvent, _currentData);
      }
      _currentEvent = '';
      _currentData = '';
      return;
    }

    if (line.startsWith('event:')) {
      _currentEvent = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      _currentData = line.substring(5).trim();
    }
  }

  void _processEvent(String event, String data) {
    debugPrint('[SSE] Event: $event, Data: $data');

    switch (event) {
      case 'connected':
        debugPrint('[SSE] Connection confirmed by server');
        break;
      case 'notification':
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final notification = NotificationItem.fromJson(json);
          _notificationController.add(notification);
          debugPrint('[SSE] Received notification: ${notification.title}');
        } catch (e) {
          debugPrint('[SSE] Failed to parse notification: $e');
        }
        break;
      default:
        debugPrint('[SSE] Unknown event type: $event');
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _connectionStateController.add(false);
    _subscription?.cancel();
    _client?.close();
    _client = null;
    _subscription = null;
  }

  /// Disconnect from SSE stream
  void disconnect() {
    debugPrint('[SSE] Disconnecting...');
    _handleDisconnect();
    _accessToken = null;
  }

  /// Reconnect to SSE stream (e.g., after network recovery)
  Future<void> reconnect() async {
    if (_accessToken != null) {
      disconnect();
      await Future.delayed(const Duration(seconds: 1));
      await _startConnection();
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _notificationController.close();
    _connectionStateController.close();
    _instance = null;
  }
}
