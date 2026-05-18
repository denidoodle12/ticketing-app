class AppConstants {
  // App Info
  static const String appName = 'Tixcora';
  static const String appTagline = 'Secure Enterprise Ticketing';
  static const String poweredBy = 'Powered by EnigmaCamp';
  // Note: App version is now dynamic, use AppInfo.version instead

  // Environment
  static const bool useMockData = false; // Switch to false when API ready

  // Pagination
  static const int defaultPageSize = 10;
  static const int defaultPage = 1;

  // Timeouts
  static const int connectionTimeoutMs = 30000; // 30 seconds
  static const int receiveTimeoutMs = 30000; // 30 seconds

  // Validation
  static const int minPasswordLength = 8;
  static const int maxNameLength = 100;
  static const int maxPhoneNumberLength = 20;
  static const int maxProfilePictureSizeMB = 2; // 2MB (API contract limit)
  static const int maxAttachmentSizeMB = 5; // 5MB (API contract limit for ticket attachments)
  static const int maxChatAttachmentSizeMB = 5; // 5MB (API contract limit for chat attachments)

  // Allowed roles for this app (end-user level roles)
  // Primary validation: by role_level from backend (role_level < 2 = end-user)
  // End-user roles (level 1) can login. Agent (level 2+) and above are blocked.
  static const int maxAllowedRoleLevel = 1;

  // Fallback: by role name (if role_level is not available from backend)
  static const Set<String> allowedRoles = {
    'user',
    'end_user',
    'employee',
    'client',
    'customer',
  };

  // Delays
  static const int splashDurationMs = 2000; // 2 seconds
}
