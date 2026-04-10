import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/storage_keys.dart';
import '../constants/api_endpoints.dart';

/// Centralized token refresh service.
///
/// - Provides `refreshToken()` for manual refresh (WebSocket, SSE, etc.)
/// - Runs a proactive refresh timer to refresh tokens BEFORE they expire
/// - Uses a mutex to prevent simultaneous refresh calls
class TokenRefreshService {
  static final TokenRefreshService _instance = TokenRefreshService._internal();
  static TokenRefreshService get instance => _instance;
  TokenRefreshService._internal();

  final _secureStorage = const FlutterSecureStorage();

  /// Mutex to prevent multiple simultaneous refresh calls
  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  /// Proactive refresh timer
  Timer? _refreshTimer;

  /// Token lifetime in seconds (default 900s = 15 min, updated from login response)
  int _tokenLifetimeSeconds = 900;

  /// Callback to notify listeners when token is refreshed (e.g., background SSE service)
  void Function(String newToken)? onTokenRefreshed;

  /// Callback when session is truly expired (refresh token invalid)
  /// Used to trigger auto-logout and redirect to login screen
  void Function()? onSessionExpired;

  /// Start proactive token refresh timer.
  /// Call this after login or after any successful token refresh.
  /// Schedules refresh to happen 2 minutes before token expiry.
  void startProactiveRefresh({int? tokenLifetimeSeconds}) {
    _refreshTimer?.cancel();

    if (tokenLifetimeSeconds != null) {
      _tokenLifetimeSeconds = tokenLifetimeSeconds;
    }

    // Refresh 120 seconds before expiry (or at half-life if token lasts < 4 min)
    final refreshInSeconds = _tokenLifetimeSeconds > 240
        ? _tokenLifetimeSeconds - 120
        : _tokenLifetimeSeconds ~/ 2;

    _refreshTimer = Timer(Duration(seconds: refreshInSeconds), () async {
      final newToken = await refreshToken();
      if (newToken != null) {
        // Successfully refreshed — schedule next refresh
        startProactiveRefresh();
      } else {
        // Refresh token is expired — session is truly over
        onSessionExpired?.call();
      }
    });
  }

  /// Stop the proactive refresh timer (call on logout)
  void stopProactiveRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Refresh the access token using the stored refresh token.
  /// Returns the new access token, or null if refresh failed.
  /// Thread-safe: multiple callers will share the same refresh result.
  Future<String?> refreshToken() async {
    // If already refreshing, wait for the result
    if (_isRefreshing && _refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    try {
      final refreshTokenValue = await _secureStorage.read(
        key: StorageKeys.refreshToken,
      );

      if (refreshTokenValue == null || refreshTokenValue.isEmpty) {
        _refreshCompleter!.complete(null);
        return null;
      }

      // Use a fresh Dio instance WITHOUT interceptors to avoid infinite loop
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiEndpoints.authBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final response = await dio.post(
        ApiEndpoints.authRefresh,
        data: {'refresh_token': refreshTokenValue},
      );

      final responseData = response.data as Map<String, dynamic>;
      final data = responseData['data'] as Map<String, dynamic>?;
      final newAccessToken = data?['access_token'] as String?;
      final expiresIn = data?['expires_in'] as int?;

      if (newAccessToken != null) {
        // Save the new access token
        await _secureStorage.write(
          key: StorageKeys.accessToken,
          value: newAccessToken,
        );

        // Update token lifetime if provided
        if (expiresIn != null) {
          _tokenLifetimeSeconds = expiresIn;
        }

        // Notify listeners (e.g., SSE background service)
        onTokenRefreshed?.call(newAccessToken);

        _refreshCompleter!.complete(newAccessToken);
        return newAccessToken;
      } else {
        _refreshCompleter!.complete(null);
        return null;
      }
    } catch (e) {
      // Refresh failed — token is truly expired
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  /// Clear tokens (call on logout)
  Future<void> clearTokens() async {
    stopProactiveRefresh();
    await _secureStorage.delete(key: StorageKeys.accessToken);
    await _secureStorage.delete(key: StorageKeys.refreshToken);
  }
}
