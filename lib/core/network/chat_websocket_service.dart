import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_config.dart';
import '../../features/tickets/models/comment_model.dart';

/// WebSocket connection state
enum WebSocketState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Chat WebSocket service for real-time messaging
class ChatWebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  // State management
  WebSocketState _state = WebSocketState.disconnected;
  int? _currentTicketId;
  String? _token;

  // Callbacks
  Function(Comment)? onMessageReceived;
  Function(WebSocketState)? onStateChanged;
  Function(String)? onError;

  // Reconnection settings
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  Timer? _reconnectTimer;

  // Getters
  WebSocketState get state => _state;
  bool get isConnected => _state == WebSocketState.connected;
  int? get currentTicketId => _currentTicketId;

  /// Get WebSocket URL from base URL
  String _getWebSocketUrl(int ticketId, String token) {
    // Convert https:// to wss:// or http:// to ws://
    String wsUrl = ApiConfig.baseUrl;
    if (wsUrl.startsWith('https://')) {
      wsUrl = wsUrl.replaceFirst('https://', 'wss://');
    } else if (wsUrl.startsWith('http://')) {
      wsUrl = wsUrl.replaceFirst('http://', 'ws://');
    }
    return '$wsUrl/ws/tickets/$ticketId?token=$token';
  }

  /// Connect to WebSocket for a specific ticket
  Future<void> connect({
    required int ticketId,
    required String token,
  }) async {
    // Don't reconnect if already connected to same ticket
    if (_state == WebSocketState.connected && _currentTicketId == ticketId) {
      return;
    }

    // Disconnect existing connection if any
    await disconnect();

    _currentTicketId = ticketId;
    _token = token;
    _reconnectAttempts = 0;

    await _establishConnection();
  }

  /// Establish WebSocket connection
  Future<void> _establishConnection() async {
    if (_currentTicketId == null || _token == null) return;

    _updateState(WebSocketState.connecting);

    try {
      final url = _getWebSocketUrl(_currentTicketId!, _token!);
      debugPrint('ChatWebSocket: Connecting to $url');

      _channel = WebSocketChannel.connect(Uri.parse(url));

      // Wait for connection to be ready
      await _channel!.ready;

      _updateState(WebSocketState.connected);
      _reconnectAttempts = 0;
      debugPrint('ChatWebSocket: Connected successfully');

      // Listen for messages
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );
    } catch (e) {
      debugPrint('ChatWebSocket: Connection error - $e');
      _updateState(WebSocketState.error);
      onError?.call('Failed to connect: $e');
      _scheduleReconnect();
    }
  }

  /// Handle incoming messages
  void _handleMessage(dynamic data) {
    try {
      debugPrint('ChatWebSocket: Received message - $data');

      final json = jsonDecode(data as String) as Map<String, dynamic>;

      // Check if it's a valid comment message
      if (json.containsKey('id') && json.containsKey('content')) {
        final comment = Comment.fromJson(json);
        onMessageReceived?.call(comment);
      }
    } catch (e) {
      debugPrint('ChatWebSocket: Error parsing message - $e');
    }
  }

  /// Handle WebSocket errors
  void _handleError(dynamic error) {
    debugPrint('ChatWebSocket: Error - $error');
    _updateState(WebSocketState.error);
    onError?.call(error.toString());
    _scheduleReconnect();
  }

  /// Handle WebSocket connection closed
  void _handleDone() {
    debugPrint('ChatWebSocket: Connection closed');
    if (_state != WebSocketState.disconnected) {
      _updateState(WebSocketState.disconnected);
      _scheduleReconnect();
    }
  }

  /// Send a message through WebSocket
  Future<bool> sendMessage(String content) async {
    if (_channel == null || _state != WebSocketState.connected) {
      debugPrint('ChatWebSocket: Cannot send - not connected');
      return false;
    }

    try {
      final message = jsonEncode({
        'type': 'message',
        'content': content,
      });

      _channel!.sink.add(message);
      debugPrint('ChatWebSocket: Message sent - $content');
      return true;
    } catch (e) {
      debugPrint('ChatWebSocket: Error sending message - $e');
      onError?.call('Failed to send message: $e');
      return false;
    }
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('ChatWebSocket: Max reconnect attempts reached');
      onError?.call('Unable to reconnect after $_maxReconnectAttempts attempts');
      return;
    }

    if (_currentTicketId == null || _token == null) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_state != WebSocketState.connected &&
          _state != WebSocketState.connecting) {
        _reconnectAttempts++;
        debugPrint('ChatWebSocket: Reconnect attempt $_reconnectAttempts');
        _updateState(WebSocketState.reconnecting);
        _establishConnection();
      }
    });
  }

  /// Update connection state
  void _updateState(WebSocketState newState) {
    if (_state != newState) {
      _state = newState;
      onStateChanged?.call(newState);
    }
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    debugPrint('ChatWebSocket: Disconnecting');

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;

    _currentTicketId = null;
    _token = null;
    _reconnectAttempts = 0;

    _updateState(WebSocketState.disconnected);
  }

  /// Dispose the service
  void dispose() {
    disconnect();
    onMessageReceived = null;
    onStateChanged = null;
    onError = null;
  }
}
