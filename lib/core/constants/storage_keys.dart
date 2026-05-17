class StorageKeys {
  // Secure Storage Keys (untuk token & data sensitive)
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';

  // Shared Preferences Keys (untuk cache & preferences)
  static const String userId = 'user_id';
  static const String userEmail = 'user_email';
  static const String userUsername = 'user_username';
  static const String userName = 'user_name';
  static const String userLastName = 'user_last_name';
  static const String userFullName = 'user_full_name'; // Legacy, kept for backward compatibility
  static const String userPhoneNumber = 'user_phone_number';
  static const String userProfilePicture = 'user_profile_picture';
  static const String userRole = 'user_role';
  static const String userAvatarUrl = 'user_avatar_url';
  static const String userIsFirstLogin = 'user_is_first_login';

  // App Preferences
  static const String isFirstLaunch = 'is_first_launch';
  static const String isDarkMode = 'is_dark_mode';
  static const String hasCompletedOnboarding = 'has_completed_onboarding';

  // Search
  static const String recentSearches = 'recent_searches';
  static const String recentArticleSearches = 'recent_article_searches';
}
