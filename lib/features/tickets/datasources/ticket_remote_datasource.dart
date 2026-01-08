import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../models/ticket_model.dart';
import '../models/ticket_category_model.dart';
import '../models/ticket_status_model.dart';

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
    final meta = response.data['meta'] as Map<String, dynamic>?;

    final tickets = data
        .map((json) => Ticket.fromJson(json as Map<String, dynamic>))
        .toList();

    return TicketListResponse(
      tickets: tickets,
      currentPage: meta?['current_page'] as int? ?? page,
      totalPages: meta?['total_pages'] as int? ?? 1,
      totalItems: meta?['total_items'] as int? ?? tickets.length,
      hasNext: meta?['has_next'] as bool? ?? false,
      hasPrev: meta?['has_prev'] as bool? ?? false,
    );
  }

  /// Get single ticket by ID
  Future<Ticket> getTicketById(int id) async {
    final response = await _dio.get(ApiEndpoints.ticketById(id));
    return Ticket.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Create new ticket
  Future<Ticket> createTicket({
    required String subject,
    required String description,
    required int categoryId,
    required String priority,
    String? attachmentPath,
  }) async {
    // If there's an attachment, upload it first
    String? uploadedFilename;
    if (attachmentPath != null) {
      uploadedFilename = await uploadFile(attachmentPath);
    }

    final data = {
      'subject': subject,
      'description': description,
      'category_id': categoryId,
      'priority': priority,
      if (uploadedFilename != null) 'attachment': uploadedFilename,
    };

    final response = await _dio.post(ApiEndpoints.tickets, data: data);
    return Ticket.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Upload file attachment
  Future<String> uploadFile(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });

    final response = await _dio.post(
      ApiEndpoints.upload,
      data: formData,
    );

    return response.data['data']['filename'] as String;
  }

  /// Get file download URL
  String getFileUrl(String filename) {
    return '${ApiEndpoints.ticketBaseUrl}${ApiEndpoints.downloadFile(filename)}';
  }
}

/// Response model for paginated ticket list
class TicketListResponse {
  final List<Ticket> tickets;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final bool hasNext;
  final bool hasPrev;

  TicketListResponse({
    required this.tickets,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.hasNext,
    required this.hasPrev,
  });
}
