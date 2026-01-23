import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../models/ticket_model.dart';
import '../models/ticket_category_model.dart';
import '../models/ticket_status_model.dart';
import '../models/comment_model.dart';

class TicketRemoteDatasource {
  Dio get _dio => DioClient.userInstance;

  /// Get active ticket categories for dropdown
  Future<List<TicketCategory>> getActiveCategories() async {
    final response = await _dio.get(ApiEndpoints.ticketCategoriesActive);
    final data = response.data['data'] as List<dynamic>;
    return data
        .map((json) => TicketCategory.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get active ticket statuses for filter/display
  Future<List<TicketStatus>> getActiveStatuses() async {
    final response = await _dio.get(ApiEndpoints.ticketStatusesActive);
    final data = response.data['data'] as List<dynamic>;
    return data
        .map((json) => TicketStatus.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get tickets with optional filters (customer only sees own tickets)
  Future<TicketListResponse> getTickets({
    int page = 1,
    int limit = 10,
    int? statusId,
    String? priority,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };

    if (statusId != null) queryParams['status_id'] = statusId;
    if (priority != null) queryParams['priority'] = priority;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await _dio.get(
      ApiEndpoints.tickets,
      queryParameters: queryParams,
    );

    final data = response.data['data'] as List<dynamic>;
    // Try both 'pagination' (API contract) and 'meta' (alternative) for compatibility
    final pagination = response.data['pagination'] as Map<String, dynamic>? ??
        response.data['meta'] as Map<String, dynamic>?;

    final tickets = data
        .map((json) => Ticket.fromJson(json as Map<String, dynamic>))
        .toList();

    // Calculate hasNext based on current data
    final total = pagination?['total'] as int? ??
        pagination?['total_items'] as int? ??
        tickets.length;
    final currentPage = pagination?['page'] as int? ??
        pagination?['current_page'] as int? ??
        page;
    final pageLimit = pagination?['limit'] as int? ?? limit;
    final hasNext = pagination?['has_next'] as bool? ??
        (currentPage * pageLimit < total);

    return TicketListResponse(
      tickets: tickets,
      total: total,
      page: currentPage,
      limit: pageLimit,
      hasNext: hasNext,
      hasPrev: pagination?['has_prev'] as bool? ?? (currentPage > 1),
    );
  }

  /// Get single ticket by ID with comments
  Future<TicketDetailResponse> getTicketById(int id) async {
    final response = await _dio.get(ApiEndpoints.ticketById(id));
    return TicketDetailResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Create new ticket
  /// Note: attachmentUrl is the URL returned from uploadFile(), not a file path
  Future<Ticket> createTicket({
    required String subject,
    required String description,
    required int categoryId,
    required String priority,
    String? attachmentUrl,
  }) async {
    final data = {
      'subject': subject,
      'description': description,
      'category_id': categoryId,
      'priority': priority,
      if (attachmentUrl != null) 'attachment': attachmentUrl,
    };

    final response = await _dio.post(ApiEndpoints.tickets, data: data);
    return Ticket.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Upload file attachment
  /// Returns the URL path to use in ticket (e.g., /uploads/xxx.png)
  Future<String> uploadFile(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });

    final response = await _dio.post(
      ApiEndpoints.upload,
      data: formData,
    );

    // Return the url field which includes /uploads/ prefix
    return response.data['data']['url'] as String;
  }

  /// Get file download URL
  String getFileUrl(String filename) {
    return '${ApiEndpoints.ticketBaseUrl}${ApiEndpoints.downloadFile(filename)}';
  }

  /// Create a comment on a ticket
  /// Content and attachment are both optional, but at least one must be provided
  Future<Comment> createComment({
    required int ticketId,
    String? content,
    String? attachmentUrl,
  }) async {
    final data = <String, dynamic>{};
    if (content != null && content.isNotEmpty) {
      data['content'] = content;
    }
    if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
      data['attachment'] = attachmentUrl;
    }

    final response = await _dio.post(
      ApiEndpoints.ticketComments(ticketId),
      data: data,
    );
    return Comment.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Upload attachment for comment
  /// Returns the URL path to use in comment (e.g., /chat-uploads/xxx.pdf)
  Future<String> uploadCommentAttachment({
    required int ticketId,
    required String filePath,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });

    final response = await _dio.post(
      ApiEndpoints.ticketCommentsUpload(ticketId),
      data: formData,
    );

    return response.data['data']['url'] as String;
  }

  /// Get chat file URL for viewing/downloading
  String getChatFileUrl(String filename) {
    return '${ApiEndpoints.ticketBaseUrl}${ApiEndpoints.chatUploads(filename)}';
  }
}
