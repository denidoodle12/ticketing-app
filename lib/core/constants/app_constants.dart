class AppConstants {
  // App Info
  static const String appName = 'EnigTickets';
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
  static const int maxProfilePictureSizeMB = 2; // 2MB

  // Allowed roles for this app (end-user app)
  static const String allowedRole = 'user';

  // Delays
  static const int splashDurationMs = 2000; // 2 seconds
}
