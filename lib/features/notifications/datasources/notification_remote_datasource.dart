import 'package:dio/dio.dart';
import '../../../core/constants/api_config.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_interceptor.dart';
import '../models/notification_model.dart';

/// Remote datasource for notification API calls
class NotificationRemoteDatasource {
  late final Dio _dio;

  NotificationRemoteDatasource() {
    _dio = _createDio();
  }

  Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(
          milliseconds: AppConstants.connectionTimeoutMs,
        ),
        receiveTimeout: const Duration(
          milliseconds: AppConstants.receiveTimeoutMs,
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(ApiInterceptor());
    return dio;
  }

  /// Get paginated notification list
  /// [page] - Page number (1-indexed)
  /// [limit] - Items per page
  Future<NotificationListResponse> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.notifications,
        queryParameters: {'page': page, 'limit': limit},
      );

      return NotificationListResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get(ApiEndpoints.notificationsUnreadCount);
      final data = UnreadCountResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      return data.count;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Mark a single notification as read
  Future<void> markAsRead(int notificationId) async {
    try {
      await _dio.put(ApiEndpoints.notificationRead(notificationId));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _dio.put(ApiEndpoints.notificationsReadAll);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    final message =
        e.response?.data?['message'] ?? e.message ?? 'Unknown error';
    return Exception(message);
  }
}
