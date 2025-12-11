class ApiConfig {
  // Environment Mode
  static const bool useMockData = false; // Set to true for testing without backend

  // Base URLs for different services
  static const String authServiceUrl = 'http://10.10.100.116:8080';
  static const String userServiceUrl = 'http://10.10.100.116:8081';

  // Timeout configurations
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
