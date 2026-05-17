class ApiConfig {
  // App Version
  static const String appVersion = '1.0.0';

  // Environment Mode
  static const bool useMockData = false; // Set to true for testing without backend

  // ──────────────────────────────────────────────────────
  // Base URL — Single Source of Truth
  // All services go through the API Gateway.
  // To switch environments, change ONLY this value.
  // ──────────────────────────────────────────────────────
  static const String baseUrl = 'https://magang.damarbrawijaya.my.id';

  // Service URLs (all routed through gateway)
  static const String authServiceUrl = baseUrl;
  static const String userServiceUrl = baseUrl;

  // Timeout configurations
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  
}
