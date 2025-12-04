class AppConstants {
  // App Info
  static const String appName = 'Ticketing App';
  static const String appVersion = '0.1.0';

  // Environment
  static const bool useMockData = true; // Switch to false when API ready

  // Pagination
  static const int defaultPageSize = 10;
  static const int defaultPage = 1;

  // Timeouts
  static const int connectionTimeoutMs = 30000; // 30 seconds
  static const int receiveTimeoutMs = 30000; // 30 seconds

  // Validation
  static const int minPasswordLength = 6;
  static const int maxNameLength = 100;

  // Delays
  static const int splashDurationMs = 2000; // 2 seconds
}
