import 'api_config.dart';

class ApiEndpoints {
  // Base URLs (from ApiConfig)
  static String get authBaseUrl => ApiConfig.authServiceUrl;
  static String get userBaseUrl => ApiConfig.userServiceUrl;

  // Auth Service Endpoints (ms-auth: port 8080)
  static const String authLogin = '/auth/login';
  // Note: Register endpoint requires admin authentication (not for end-users)
  // static const String authRegister = '/auth/register';

  // User Service Endpoints (ms-user-management: port 8081)
  static const String userMe = '/users/me';
  static const String userMePermissions = '/users/me/permissions';

  // Future: Ticket Service Endpoints (Sprint 3+)
  // static const String tickets = '/tickets';
  // static String ticketById(String id) => '/tickets/$id';
}
