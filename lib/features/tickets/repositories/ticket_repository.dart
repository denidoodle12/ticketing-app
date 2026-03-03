import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/errors/exceptions.dart';
import '../datasources/ticket_remote_datasource.dart';
import '../datasources/ticket_mock_datasource.dart';
import '../datasources/ticket_local_datasource.dart';
import '../models/ticket_model.dart';
import '../models/ticket_category_model.dart';
import '../models/ticket_status_model.dart';
import '../models/ticket_rating_model.dart';
import '../models/comment_model.dart';

class TicketRepository {
  final TicketRemoteDatasource? _remoteDatasource;
  final TicketMockDatasource? _mockDatasource;
  final TicketLocalDatasource? _localDatasource;

  TicketRepository({
    TicketRemoteDatasource? remoteDatasource,
    TicketMockDatasource? mockDatasource,
    TicketLocalDatasource? localDatasource,
  }) : _remoteDatasource = remoteDatasource,
       _mockDatasource = mockDatasource,
       _localDatasource = localDatasource;

  bool get _useMock => _mockDatasource != null;

  /// Check if an exception is a network-related error
  /// DioException wraps our NetworkException inside its .error property
  bool _isNetworkError(dynamic e) {
    if (e is NetworkException) return true;
    if (e is DioException) {
      return e.error is NetworkException ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.unknown;
    }
    return false;
  }

  /// Get active categories for ticket creation dropdown
  /// Cache-first: fetch from API → cache locally → fallback to cache on network error
  Future<List<TicketCategory>> getActiveCategories() async {
    try {
      if (_useMock) {
        return await _mockDatasource!.getActiveCategories();
      }
      final categories = await _remoteDatasource!.getActiveCategories();
      // Cache on success
      await _localDatasource?.cacheCategories(categories);
      return categories;
    } on NetworkException {
      // Fallback to cache
      final cached = await _localDatasource?.getCachedCategories();
      if (cached != null && cached.isNotEmpty) {
        debugPrint(
          '[TicketRepository] Using cached categories (${cached.length} items)',
        );
        return cached;
      }
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      // DioException wraps NetworkException — check and fallback
      if (_isNetworkError(e)) {
        final cached = await _localDatasource?.getCachedCategories();
        if (cached != null && cached.isNotEmpty) {
          debugPrint(
            '[TicketRepository] Using cached categories (${cached.length} items)',
          );
          return cached;
        }
        throw NetworkException(
          'No internet connection. Please check your network.',
        );
      }
      throw ServerException('Failed to load categories: $e');
    }
  }

  /// Get active statuses for filtering tickets
  /// Cache-first: fetch from API → cache locally → fallback to cache on network error
  Future<List<TicketStatus>> getActiveStatuses() async {
    try {
      if (_useMock) {
        return await _mockDatasource!.getActiveStatuses();
      }
      final statuses = await _remoteDatasource!.getActiveStatuses();
      await _localDatasource?.cacheStatuses(statuses);
      return statuses;
    } on NetworkException {
      final cached = await _localDatasource?.getCachedStatuses();
      if (cached != null && cached.isNotEmpty) {
        debugPrint(
          '[TicketRepository] Using cached statuses (${cached.length} items)',
        );
        return cached;
      }
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      if (_isNetworkError(e)) {
        final cached = await _localDatasource?.getCachedStatuses();
        if (cached != null && cached.isNotEmpty) {
          debugPrint(
            '[TicketRepository] Using cached statuses (${cached.length} items)',
          );
          return cached;
        }
        throw NetworkException(
          'No internet connection. Please check your network.',
        );
      }
      throw ServerException('Failed to load statuses: $e');
    }
  }

  /// Get paginated list of tickets (customer sees only own tickets)
  /// Cache-first: fetch from API → cache → fallback to cache on network error
  Future<TicketListResponse> getTickets({
    int page = 1,
    int limit = 10,
    int? statusId,
    String? statusName,
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
      final response = await _remoteDatasource!.getTickets(
        page: page,
        limit: limit,
        statusId: statusId,
        priority: priority,
        search: search,
      );
      // Cache tickets on success
      if (response.tickets.isNotEmpty) {
        await _localDatasource?.cacheTickets(response.tickets);
      }
      return response;
    } on NetworkException {
      return _getTicketsFromCache(
        page: page,
        limit: limit,
        statusId: statusId,
        statusName: statusName,
        priority: priority,
        search: search,
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      if (_isNetworkError(e)) {
        return _getTicketsFromCache(
          page: page,
          limit: limit,
          statusId: statusId,
          statusName: statusName,
          priority: priority,
          search: search,
        );
      }
      throw ServerException('Failed to load tickets: $e');
    }
  }

  /// Helper: get tickets from local cache, returns empty list for filtered queries
  /// Only throws NetworkException when cache is completely unavailable
  Future<TicketListResponse> _getTicketsFromCache({
    required int page,
    required int limit,
    int? statusId,
    String? statusName,
    String? priority,
    String? search,
  }) async {
    final cached = await _localDatasource?.getCachedTickets(
      page: page,
      limit: limit,
      statusId: statusId,
      statusName: statusName,
      priority: priority,
      search: search,
    );
    if (cached != null) {
      debugPrint(
        '[TicketRepository] Using cached tickets (${cached.tickets.length} items)',
      );
      return cached;
    }
    // No local datasource at all
    throw NetworkException(
      'No internet connection. Please check your network.',
    );
  }

  /// Get single ticket by ID with comments
  /// Cache-first: fetch from API → fallback to cached ticket on network error
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
      final response = await _remoteDatasource!.getTicketById(id);
      // Cache the ticket on success
      await _localDatasource?.cacheTickets([response.ticket]);
      return response;
    } on NetworkException {
      // Fallback to cached ticket
      final cachedTicket = await _localDatasource?.getCachedTicketById(id);
      if (cachedTicket != null) {
        debugPrint('[TicketRepository] Using cached ticket #$id');
        return TicketDetailResponse(
          ticket: cachedTicket,
          comments: [],
          totalComments: 0,
        );
      }
      rethrow;
    } on ServerException {
      rethrow;
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      if (_isNetworkError(e)) {
        final cachedTicket = await _localDatasource?.getCachedTicketById(id);
        if (cachedTicket != null) {
          debugPrint('[TicketRepository] Using cached ticket #$id');
          return TicketDetailResponse(
            ticket: cachedTicket,
            comments: [],
            totalComments: 0,
          );
        }
        throw NetworkException(
          'No internet connection. Please check your network.',
        );
      }
      throw ServerException('Failed to load ticket: $e');
    }
  }

  /// Check if local cache has any data (for smart connectivity decisions)
  Future<bool> hasCache() async {
    return await _localDatasource?.hasCache() ?? false;
  }

  /// Get the local datasource reference (for provider-level cache operations)
  TicketLocalDatasource? get localDatasource => _localDatasource;

  /// Get ticket comments from ms-chat service (includes firstname field)
  Future<CommentsResponse> getTicketComments(
    int ticketId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      if (_useMock) {
        return CommentsResponse(
          comments: [],
          total: 0,
          page: page,
          limit: limit,
        );
      }
      return await _remoteDatasource!.getTicketComments(
        ticketId,
        page: page,
        limit: limit,
      );
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to load comments: $e');
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
  /// Content and attachment are both optional, but at least one must be provided
  Future<Comment> createComment({
    required int ticketId,
    String? content,
    String? attachmentUrl,
  }) async {
    try {
      if (_useMock) {
        throw ServerException('Mock createComment not implemented');
      }
      return await _remoteDatasource!.createComment(
        ticketId: ticketId,
        content: content,
        attachmentUrl: attachmentUrl,
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

  /// Upload attachment for comment
  Future<String> uploadCommentAttachment({
    required int ticketId,
    required String filePath,
  }) async {
    try {
      if (_useMock) {
        throw ServerException('Mock uploadCommentAttachment not implemented');
      }
      return await _remoteDatasource!.uploadCommentAttachment(
        ticketId: ticketId,
        filePath: filePath,
      );
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to upload attachment: $e');
    }
  }

  /// Get chat file URL
  String getChatFileUrl(String filename) {
    if (_useMock) {
      return _mockDatasource!.getFileUrl(filename);
    }
    return _remoteDatasource!.getChatFileUrl(filename);
  }

  /// Submit a rating for a closed ticket
  Future<TicketRating> submitRating({
    required int ticketId,
    required int rating,
    String? comment,
  }) async {
    try {
      if (_useMock) {
        throw ServerException('Mock submitRating not implemented');
      }
      return await _remoteDatasource!.submitRating(
        ticketId: ticketId,
        rating: rating,
        comment: comment,
      );
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      if (e is DioException && e.response != null) {
        final statusCode = e.response!.statusCode;
        final data = e.response!.data;
        // Extract error message from backend response
        String message = 'Failed to submit rating';
        if (data is Map<String, dynamic>) {
          message = data['error'] ?? data['message'] ?? message;
        }
        if (statusCode == 400 || statusCode == 403 || statusCode == 409) {
          throw ServerException(message);
        }
      }
      throw ServerException('Failed to submit rating: $e');
    }
  }

  /// Get existing rating for a ticket
  /// Returns null if ticket has not been rated yet
  Future<TicketRating?> getTicketRating(int ticketId) async {
    try {
      if (_useMock) {
        return null;
      }
      return await _remoteDatasource!.getTicketRating(ticketId);
    } on NetworkException {
      return null; // Gracefully handle offline
    } on ServerException {
      return null;
    } catch (e) {
      debugPrint('[TicketRepository] Error loading rating: $e');
      return null;
    }
  }
}
