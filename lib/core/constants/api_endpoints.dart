class ApiEndpoints {
  // Base URLs
  static const String authBaseUrl = 'http://localhost:8080';
  static const String userBaseUrl = 'http://localhost:8081';
  static const String ticketBaseUrl = 'http://localhost:8082'; // Future use

  // Auth Service Endpoints
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authResetPassword = '/auth/reset-password';

  // User Service Endpoints
  static const String userMe = '/users/me';
  static String userById(String id) => '/users/$id';

  // Master Data Endpoints
  static const String categories = '/categories';
  static const String departments = '/departments';
  static const String priorities = '/priorities';

  // Future: Ticket Service Endpoints (Sprint 3+)
  // static const String tickets = '/tickets';
  // static String ticketById(String id) => '/tickets/$id';
}
