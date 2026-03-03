import 'api_config.dart';

class ApiEndpoints {
  // Base URLs (from ApiConfig)
  static String get authBaseUrl => ApiConfig.authServiceUrl;
  static String get userBaseUrl => ApiConfig.userServiceUrl;
  static String get ticketBaseUrl => ApiConfig.baseUrl;

  // Auth Service Endpoints (ms-auth: port 8080)
  static const String authLogin = '/auth/login';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';
  // Note: Register endpoint requires admin authentication (not for end-users)
  // static const String authRegister = '/auth/register';

  // User Service Endpoints (ms-user-management: port 8081)
  static const String userMe = '/users/me';
  static const String userMePermissions = '/users/me/permissions';
  static const String userMeChangePassword = '/users/me/change-password';
  static const String userMeProfilePicture = '/users/me/profile-picture';
  static String profilePicture(String filename) =>
      '/profile-pictures/$filename';

  // Ticket Service Endpoints (ms-ticket)
  // Categories
  static const String ticketCategoriesActive = '/ticket-categories/active';

  // Statuses
  static const String ticketStatusesActive = '/ticket-statuses/active';

  // Tickets
  static const String tickets = '/tickets';
  static String ticketById(int id) => '/tickets/$id';

  // Comments
  static String ticketComments(int ticketId) => '/tickets/$ticketId/comments';
  static String ticketCommentsUpload(int ticketId) =>
      '/tickets/$ticketId/comments/upload';

  // File Upload (Ticket attachments)
  static const String upload = '/upload';
  static String downloadFile(String filename) => '/uploads/$filename';

  // Chat Uploads (Comment attachments)
  static String chatUploads(String filename) => '/chat-uploads/$filename';

  // Dashboard Statistics
  static const String dashboardStats = '/dashboard/stats';

  // Notification Service Endpoints (ms-notification)
  // SSE Stream for real-time notifications
  static const String notificationsStream = '/notifications/stream';

  // Notification History (paginated)
  static const String notifications = '/notifications';

  // Unread count
  static const String notificationsUnreadCount = '/notifications/unread-count';

  // Mark single notification as read
  static String notificationRead(int id) => '/notifications/$id/read';

  // Mark all notifications as read
  static const String notificationsReadAll = '/notifications/read-all';

  // Ticket Rating
  static String ticketRating(int ticketId) => '/tickets/$ticketId/rating';
}
