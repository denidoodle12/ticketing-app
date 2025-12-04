import 'package:flutter/foundation.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';

/// Auth state enum
enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Auth provider for state management
class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthState _state = AuthState.initial;
  User? _currentUser;
  String? _errorMessage;

  AuthProvider(this._authRepository);

  // Getters
  AuthState get state => _state;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;

  /// Check authentication status (called on splash screen)
  Future<void> checkAuthStatus() async {
    _setState(AuthState.loading);

    try {
      final isLoggedIn = await _authRepository.isLoggedIn();

      if (isLoggedIn) {
        _currentUser = await _authRepository.getCurrentUser();
        _setState(AuthState.authenticated);
      } else {
        _setState(AuthState.unauthenticated);
      }
    } catch (e) {
      _setError('Failed to check auth status');
      _setState(AuthState.unauthenticated);
    }
  }

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    _setState(AuthState.loading);

    try {
      final result = await _authRepository.login(email, password);

      if (result.isSuccess) {
        _currentUser = result.data;
        _setState(AuthState.authenticated);
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
      _setState(AuthState.unauthenticated);
    } catch (e) {
      _setError('Failed to logout');
      _setState(AuthState.error);
    }
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
}
