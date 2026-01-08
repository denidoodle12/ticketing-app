import '../../../core/errors/exceptions.dart';
import '../datasources/ticket_remote_datasource.dart';
import '../models/ticket_model.dart';
import '../models/ticket_category_model.dart';
import '../models/ticket_status_model.dart';

class TicketRepository {
  final TicketRemoteDatasource _remoteDatasource;

  TicketRepository({TicketRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? TicketRemoteDatasource();

  /// Get active categories for ticket creation dropdown
  Future<List<TicketCategory>> getActiveCategories() async {
    try {
      return await _remoteDatasource.getActiveCategories();
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
      return await _remoteDatasource.getActiveStatuses();
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
      return await _remoteDatasource.getTickets(
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

  /// Get single ticket by ID
  Future<Ticket> getTicketById(int id) async {
    try {
      return await _remoteDatasource.getTicketById(id);
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
  Future<Ticket> createTicket({
    required String subject,
    required String description,
    required int categoryId,
    required String priority,
    String? attachmentPath,
  }) async {
    try {
      return await _remoteDatasource.createTicket(
        subject: subject,
        description: description,
        categoryId: categoryId,
        priority: priority,
        attachmentPath: attachmentPath,
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
      return await _remoteDatasource.uploadFile(filePath);
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
    return _remoteDatasource.getFileUrl(filename);
  }
}
