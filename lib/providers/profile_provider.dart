import 'package:flutter/foundation.dart';
import '../features/auth/models/user_model.dart';
import '../features/profile/repositories/profile_repository.dart';
import '../data/datasources/local/local_storage.dart';

enum ProfileState { initial, loading, loaded, error }

class ProfileProvider extends ChangeNotifier {
  final ProfileRepository _repository;
  final LocalStorage? _localStorage;

  /// Callback to sync user data with AuthProvider
  void Function(User)? onUserUpdated;

  ProfileState _state = ProfileState.initial;
  User? _user;
  String? _errorMessage;
  bool _isUpdating = false;

  ProfileProvider(this._repository, {LocalStorage? localStorage})
      : _localStorage = localStorage;

  // Getters
  ProfileState get state => _state;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ProfileState.loading;
  bool get isUpdating => _isUpdating;

  /// Load user profile from API
  Future<void> loadProfile() async {
    _setState(ProfileState.loading);

    final result = await _repository.getProfile();

    if (result.isSuccess) {
      _user = result.data;
      _setState(ProfileState.loaded);
    } else {
      _setError(result.failure!.message);
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? name,
    String? lastName,
    String? phoneNumber,
  }) async {
    _isUpdating = true;
    notifyListeners();

    final result = await _repository.updateProfile(
      name: name,
      lastName: lastName,
      phoneNumber: phoneNumber,
    );

    _isUpdating = false;

    if (result.isSuccess) {
      _user = result.data;
      await _syncUserData(_user!);
      notifyListeners();
      return true;
    } else {
      _setError(result.failure!.message);
      return false;
    }
  }

  /// Upload profile picture
  Future<bool> uploadProfilePicture(String filePath) async {
    _isUpdating = true;
    notifyListeners();

    final result = await _repository.uploadProfilePicture(filePath);

    _isUpdating = false;

    if (result.isSuccess) {
      _user = result.data;
      await _syncUserData(_user!);
      notifyListeners();
      return true;
    } else {
      _setError(result.failure!.message);
      return false;
    }
  }

  /// Sync user data to local storage and notify callback
  Future<void> _syncUserData(User user) async {
    // Update local storage
    if (_localStorage != null) {
      await _localStorage.saveUserData(
        userId: user.id.toString(),
        email: user.email,
        username: user.username,
        fullName: user.name,
        role: user.role,
        isFirstLogin: user.isFirstLogin,
        lastName: user.lastName,
        phoneNumber: user.phoneNumber,
        profilePicture: user.profilePicture,
      );
    }

    // Notify AuthProvider via callback
    onUserUpdated?.call(user);
  }

  /// Set user from external source (e.g., after login)
  void setUser(User user) {
    _user = user;
    _setState(ProfileState.loaded);
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setState(ProfileState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _state = ProfileState.error;
    notifyListeners();
  }
}
