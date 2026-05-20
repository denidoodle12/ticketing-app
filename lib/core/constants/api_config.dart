class ApiConfig {
  // App Version
  static const String appVersion = '1.0.0';

  // Environment Mode
  static const bool useMockData =
      false; // Set to true for testing without backend

  // ──────────────────────────────────────────────────────
  // Base URL — Single Source of Truth
  // All services go through the API Gateway.
  //
  // Configurable at compile-time via --dart-define so we don't have to
  // edit & commit code every time we point at a different environment.
  // Default = production. Override examples:
  //
  // Notes:
  // - String.fromEnvironment is evaluated at compile-time, NOT runtime,
  //   so the value is baked into the binary (no .env file at runtime).
  // - Must be `const` to satisfy the const constructor below.
  // ──────────────────────────────────────────────────────
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://prod.damarbrawijaya.my.id',
  );

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
