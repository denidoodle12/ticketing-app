import 'package:flutter/foundation.dart';
import '../features/auth/models/user_model.dart';
import '../features/profile/repositories/profile_repository.dart';

enum ProfileState { initial, loading, loaded, error }

class ProfileProvider extends ChangeNotifier {
  final ProfileRepository _repository;

  ProfileState _state = ProfileState.initial;
  User? _user;
  String? _errorMessage;
  bool _isUpdating = false;

  ProfileProvider(this._repository);

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
      notifyListeners();
      return true;
    } else {
      _setError(result.failure!.message);
      return false;
    }
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
