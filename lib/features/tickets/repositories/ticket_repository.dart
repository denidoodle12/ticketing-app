import '../../../core/errors/exceptions.dart';
import '../datasources/ticket_remote_datasource.dart';
import '../datasources/ticket_mock_datasource.dart';
import '../models/ticket_model.dart';
import '../models/ticket_category_model.dart';
import '../models/ticket_status_model.dart';
import '../models/comment_model.dart';

class TicketRepository {
  final TicketRemoteDatasource? _remoteDatasource;
  final TicketMockDatasource? _mockDatasource;

  TicketRepository({
    TicketRemoteDatasource? remoteDatasource,
    TicketMockDatasource? mockDatasource,
  })  : _remoteDatasource = remoteDatasource,
        _mockDatasource = mockDatasource;

  bool get _useMock => _mockDatasource != null;

  /// Get active categories for ticket creation dropdown
  Future<List<TicketCategory>> getActiveCategories() async {
    try {
      if (_useMock) {
        return await _mockDatasource!.getActiveCategories();
      }
      return await _remoteDatasource!.getActiveCategories();
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to load categories: $e');
    }
  }

  /// Get active statuses for filtering tickets
  Future<List<TicketStatus>> getActiveStatuses() async {
    try {
      if (_useMock) {
        return await _mockDatasource!.getActiveStatuses();
      }
      return await _remoteDatasource!.getActiveStatuses();
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to load statuses: $e');
    }
  }

  /// Get paginated list of tickets (customer sees only own tickets)
  Future<TicketListResponse> getTickets({
    int page = 1,
    int limit = 10,
    int? statusId,
    String? priority,
    String? search,
  }) async {
    try {
      if (_useMock) {
        return await _mockDatasource!.getTickets(
          page: page,
          limit: limit,
          statusId: statusId,
          priority: priority,
          search: search,
        );
      }
      return await _remoteDatasource!.getTickets(
        page: page,
        limit: limit,
        statusId: statusId,
        priority: priority,
        search: search,
      );
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to load tickets: $e');
    }
  }

  /// Get single ticket by ID with comments
  Future<TicketDetailResponse> getTicketById(int id) async {
    try {
      if (_useMock) {
        final ticket = await _mockDatasource!.getTicketById(id);
        return TicketDetailResponse(
          ticket: ticket,
          comments: [],
          totalComments: 0,
        );
      }
      return await _remoteDatasource!.getTicketById(id);
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to load ticket: $e');
    }
  }

  /// Create new ticket
  /// Note: attachmentUrl should be the URL returned from uploadFile(), not a file path
  Future<Ticket> createTicket({
    required String subject,
    required String description,
    required int categoryId,
    required String priority,
    String? attachmentUrl,
  }) async {
    try {
      if (_useMock) {
        return await _mockDatasource!.createTicket(
          subject: subject,
          description: description,
          categoryId: categoryId,
          priority: priority,
          attachmentPath: attachmentUrl,
        );
      }
      return await _remoteDatasource!.createTicket(
        subject: subject,
        description: description,
        categoryId: categoryId,
        priority: priority,
        attachmentUrl: attachmentUrl,
      );
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on ValidationException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to create ticket: $e');
    }
  }

  /// Upload file and get filename
  Future<String> uploadFile(String filePath) async {
    try {
      if (_useMock) {
        return await _mockDatasource!.uploadFile(filePath);
      }
      return await _remoteDatasource!.uploadFile(filePath);
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to upload file: $e');
    }
  }

  /// Get file download URL
  String getFileUrl(String filename) {
    if (_useMock) {
      return _mockDatasource!.getFileUrl(filename);
    }
    return _remoteDatasource!.getFileUrl(filename);
  }

  /// Create a comment on a ticket
  Future<Comment> createComment({
    required int ticketId,
    required String content,
  }) async {
    try {
      if (_useMock) {
        throw ServerException('Mock createComment not implemented');
      }
      return await _remoteDatasource!.createComment(
        ticketId: ticketId,
        content: content,
      );
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on ValidationException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to create comment: $e');
    }
  }
}
