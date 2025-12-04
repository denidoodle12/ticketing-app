import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';

class LocalStorage {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  LocalStorage(this._secureStorage, this._prefs);

  // ==================== TOKEN MANAGEMENT ====================

  /// Save access and refresh tokens
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(
      key: StorageKeys.accessToken,
      value: accessToken,
    );
    await _secureStorage.write(
      key: StorageKeys.refreshToken,
      value: refreshToken,
    );
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: StorageKeys.accessToken);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: StorageKeys.refreshToken);
  }

  /// Clear all tokens
  Future<void> clearTokens() async {
    await _secureStorage.delete(key: StorageKeys.accessToken);
    await _secureStorage.delete(key: StorageKeys.refreshToken);
  }

  /// Check if user has valid token
  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ==================== USER DATA ====================

  /// Save user data
  Future<void> saveUserData({
    required String userId,
    required String email,
    required String fullName,
    required String role,
    String? avatarUrl,
  }) async {
    await _prefs.setString(StorageKeys.userId, userId);
    await _prefs.setString(StorageKeys.userEmail, email);
    await _prefs.setString(StorageKeys.userFullName, fullName);
    await _prefs.setString(StorageKeys.userRole, role);
    if (avatarUrl != null) {
      await _prefs.setString(StorageKeys.userAvatarUrl, avatarUrl);
    }
  }

  /// Get user ID
  String? getUserId() {
    return _prefs.getString(StorageKeys.userId);
  }

  /// Get user email
  String? getUserEmail() {
    return _prefs.getString(StorageKeys.userEmail);
  }

  /// Get user full name
  String? getUserFullName() {
    return _prefs.getString(StorageKeys.userFullName);
  }

  /// Get user role
  String? getUserRole() {
    return _prefs.getString(StorageKeys.userRole);
  }

  /// Get user avatar URL
  String? getUserAvatarUrl() {
    return _prefs.getString(StorageKeys.userAvatarUrl);
  }

  /// Clear user data
  Future<void> clearUserData() async {
    await _prefs.remove(StorageKeys.userId);
    await _prefs.remove(StorageKeys.userEmail);
    await _prefs.remove(StorageKeys.userFullName);
    await _prefs.remove(StorageKeys.userRole);
    await _prefs.remove(StorageKeys.userAvatarUrl);
  }

  // ==================== APP PREFERENCES ====================

  /// Check if first launch
  bool isFirstLaunch() {
    return _prefs.getBool(StorageKeys.isFirstLaunch) ?? true;
  }

  /// Set first launch completed
  Future<void> setFirstLaunchCompleted() async {
    await _prefs.setBool(StorageKeys.isFirstLaunch, false);
  }

  /// Get dark mode preference
  bool isDarkMode() {
    return _prefs.getBool(StorageKeys.isDarkMode) ?? false;
  }

  /// Set dark mode preference
  Future<void> setDarkMode(bool isDark) async {
    await _prefs.setBool(StorageKeys.isDarkMode, isDark);
  }

  // ==================== CLEAR ALL ====================

  /// Clear all storage (logout)
  Future<void> clearAll() async {
    await clearTokens();
    await clearUserData();
    // Keep app preferences like isDarkMode
  }
}
