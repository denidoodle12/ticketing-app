class AppConstants {
  // App Info
  static const String appName = 'EnigTickets';
  static const String appTagline = 'Secure Enterprise Ticketing';
  static const String poweredBy = 'Powered by EnigmaCamp';
  static const String appVersion = '0.1.0';

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

  // Allowed roles for this app (end-user app)
  static const String allowedRole = 'customer';

  // Delays
  static const int splashDurationMs = 2000; // 2 seconds
}
