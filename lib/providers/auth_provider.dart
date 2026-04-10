import 'package:flutter/foundation.dart';
import '../features/auth/models/user_model.dart';
import '../features/auth/repositories/auth_repository.dart';
import '../core/services/token_refresh_service.dart';
import '../core/services/background_notification_service.dart';


/// Auth state enum
enum AuthState { initial, loading, authenticated, unauthenticated, error }

/// Auth provider for state management
class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  VoidCallback? _onLogoutCallback;

  AuthState _state = AuthState.initial;
  User? _currentUser;
  String? _errorMessage;

  AuthProvider(this._authRepository);

  /// Set a callback to be called on logout (e.g., to clear local cache)
  void setOnLogoutCallback(VoidCallback callback) {
    _onLogoutCallback = callback;
  }

  // Getters
  AuthState get state => _state;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;
  bool get isFirstLogin => _currentUser?.isFirstLogin ?? false;

  /// Check authentication status (called on splash screen)
  Future<void> checkAuthStatus() async {
    _setState(AuthState.loading);

    try {
      final isLoggedIn = await _authRepository.isLoggedIn();

      if (isLoggedIn) {
        _currentUser = await _authRepository.getCurrentUser();
        _setState(AuthState.authenticated);
        // Start proactive token refresh for returning users
        TokenRefreshService.instance.startProactiveRefresh();
        setupSessionExpiredHandler();
      } else {
        _setState(AuthState.unauthenticated);
      }
    } catch (e) {
      _setError('Failed to check auth status');
      _setState(AuthState.unauthenticated);
    }
  }

  /// Login with identifier (email or username) and password
  Future<bool> login(String identifier, String password) async {
    _setState(AuthState.loading);

    try {
      final result = await _authRepository.login(identifier, password);

      if (result.isSuccess) {
        _currentUser = result.data;
        _setState(AuthState.authenticated);
        setupSessionExpiredHandler();
        return true;
      } else {
        final errorMsg = result.failure!.message;
        _setError(errorMsg);
        _setState(AuthState.error);
        return false;
      }
    } catch (e) {
      _setError('An unexpected error occurred: ${e.toString()}');
      _setState(AuthState.error);
      return false;
    }
  }

  /// Register new user
  Future<bool> register(String name, String email, String password) async {
    _setState(AuthState.loading);

    try {
      final result = await _authRepository.register(name, email, password);

      if (result.isSuccess) {
        // Registration successful, but not logged in yet
        _setState(AuthState.unauthenticated);
        return true;
      } else {
        _setError(result.failure!.message);
        _setState(AuthState.error);
        return false;
      }
    } catch (e) {
      _setError('An unexpected error occurred');
      _setState(AuthState.error);
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    _setState(AuthState.loading);

    try {
      await _authRepository.logout();
      _currentUser = null;
      // Stop proactive token refresh
      TokenRefreshService.instance.stopProactiveRefresh();
      TokenRefreshService.instance.onSessionExpired = null;
      // Stop background SSE service
      await BackgroundNotificationService.instance.stopService();
      // Clear local cache on logout
      _onLogoutCallback?.call();
      _setState(AuthState.unauthenticated);
    } catch (e) {
      _setError('Failed to logout');
      _setState(AuthState.error);
    }
  }

  /// Force logout when refresh token is expired (auto-redirect to login).
  /// Unlike regular logout(), this skips the server API call because
  /// tokens are already invalid on the server side.
  Future<void> forceLogout() async {
    _currentUser = null;
    // Stop all token-related services
    TokenRefreshService.instance.stopProactiveRefresh();
    TokenRefreshService.instance.onSessionExpired = null;
    await TokenRefreshService.instance.clearTokens();
    // Stop background SSE service
    await BackgroundNotificationService.instance.stopService();
    // Clear local cache
    _onLogoutCallback?.call();
    _setState(AuthState.unauthenticated);
  }

  /// Setup handler for session expired events from TokenRefreshService.
  /// Call this after login or checkAuthStatus.
  void setupSessionExpiredHandler() {
    TokenRefreshService.instance.onSessionExpired = () {
      forceLogout();
    };
  }

  /// Change password
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    _setState(AuthState.loading);

    try {
      final result = await _authRepository.changePassword(
        oldPassword,
        newPassword,
      );

      if (result.isSuccess) {
        // Update current user's isFirstLogin to false
        if (_currentUser != null) {
          _currentUser = _currentUser!.copyWith(isFirstLogin: false);
        }
        _setState(AuthState.authenticated);
        return true;
      } else {
        _setError(result.failure!.message);
        _setState(AuthState.authenticated);
        return false;
      }
    } catch (e) {
      _setError('An unexpected error occurred: ${e.toString()}');
      _setState(AuthState.authenticated);
      return false;
    }
  }

  /// Set first login complete (updates local user state)
  void setFirstLoginComplete() {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(isFirstLogin: false);
      _authRepository.setFirstLoginComplete();
      notifyListeners();
    }
  }

  /// Update current user (called from ProfileProvider after profile update)
  void updateCurrentUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    if (_state == AuthState.error) {
      _setState(AuthState.unauthenticated);
    }
  }

  // Private helpers
  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  // ========== Forgot Password Flow ==========

  String? _resetToken;

  /// Get the stored reset token
  String? get resetToken => _resetToken;

  /// Request password reset - sends 4-digit code to email
  Future<bool> requestPasswordReset(String email) async {
    _setState(AuthState.loading);
    _errorMessage = null;

    try {
      final result = await _authRepository.requestPasswordReset(email);

      if (result.isSuccess) {
        _setState(AuthState.unauthenticated);
        return true;
      } else {
        _setError(result.failure!.message);
        _setState(AuthState.error);
        return false;
      }
    } catch (e) {
      _setError('An unexpected error occurred: ${e.toString()}');
      _setState(AuthState.error);
      return false;
    }
  }

  /// Verify reset token - check if 4-digit code is valid
  Future<bool> verifyResetToken(String token) async {
    _setState(AuthState.loading);
    _errorMessage = null;

    try {
      final result = await _authRepository.verifyResetToken(token);

      if (result.isSuccess && result.data == true) {
        // Store valid token for use in reset password step
        _resetToken = token;
        _setState(AuthState.unauthenticated);
        return true;
      } else {
        _setError(result.failure?.message ?? 'Invalid or expired code.');
        _setState(AuthState.error);
        return false;
      }
    } catch (e) {
      _setError('An unexpected error occurred: ${e.toString()}');
      _setState(AuthState.error);
      return false;
    }
  }

  /// Reset password using the 4-digit code
  Future<bool> resetPassword(String token, String newPassword) async {
    _setState(AuthState.loading);
    _errorMessage = null;

    try {
      final result = await _authRepository.resetPassword(token, newPassword);

      if (result.isSuccess) {
        // Clear stored token after successful reset
        _resetToken = null;
        _setState(AuthState.unauthenticated);
        return true;
      } else {
        _setError(result.failure!.message);
        _setState(AuthState.error);
        return false;
      }
    } catch (e) {
      _setError('An unexpected error occurred: ${e.toString()}');
      _setState(AuthState.error);
      return false;
    }
  }

  /// Clear reset token (call when user cancels flow)
  void clearResetToken() {
    _resetToken = null;
  }
}
