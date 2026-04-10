import 'package:flutter/foundation.dart';
import '../core/errors/exceptions.dart';
import '../features/tickets/models/ticket_model.dart';
import '../features/tickets/models/ticket_category_model.dart';
import '../features/tickets/models/ticket_status_model.dart';
import '../features/tickets/models/ticket_rating_model.dart';
import '../features/tickets/models/comment_model.dart';
import '../features/tickets/repositories/ticket_repository.dart';

/// Ticket loading state enum
enum TicketState { initial, loading, loaded, error }

/// Ticket provider for state management
class TicketProvider extends ChangeNotifier {
  final TicketRepository _ticketRepository;

  // States
  TicketState _categoriesState = TicketState.initial;
  TicketState _statusesState = TicketState.initial;
  TicketState _ticketsState = TicketState.initial;
  TicketState _ticketDetailState = TicketState.initial;
  TicketState _createTicketState = TicketState.initial;
  TicketState _createCommentState = TicketState.initial;
  TicketState _recentTicketsState = TicketState.initial;
  TicketState _statsState = TicketState.initial;

  // Rating states
  TicketRating? _currentRating;
  bool _isRatingLoading = false;
  bool _isSubmittingRating = false;
  bool _hasRated = false;
  bool _isRatingChecked = false;

  // Data
  List<TicketCategory> _categories = [];
  List<TicketStatus> _statuses = [];
  List<Ticket> _rawTickets = []; // Raw tickets from API
  List<Ticket> _recentTickets = [];
  Ticket? _selectedTicket;
  TicketDetailResponse? _ticketDetailResponse;

  // Stats - stores ticket counts by status (loaded once, updated on ticket changes)
  Map<String, int> _statusCounts = {
    'all': 0,
    'open': 0,
    'in_progress': 0,
    'pending': 0,
    'resolved': 0,
    'closed': 0,
  };

  // Stats - stores ticket counts by priority
  Map<String, int> _priorityCounts = {
    'low': 0,
    'medium': 0,
    'high': 0,
    'critical': 0,
  };

  // Stats - stores ticket counts by category
  Map<String, int> _categoryCounts = {};

  // Pagination
  int _currentPage = 1;
  int _totalTickets = 0;
  bool _hasMoreTickets = true;

  // Filters
  int? _filterStatusId;
  String? _filterStatusName;
  String? _filterPriority;
  String? _searchQuery;

  // Error message
  String? _errorMessage;

  TicketProvider(this._ticketRepository);

  // Getters - States
  TicketState get categoriesState => _categoriesState;
  TicketState get statusesState => _statusesState;
  TicketState get ticketsState => _ticketsState;
  TicketState get ticketDetailState => _ticketDetailState;
  TicketState get createTicketState => _createTicketState;
  TicketState get createCommentState => _createCommentState;
  TicketState get recentTicketsState => _recentTicketsState;
  TicketState get statsState => _statsState;

  // Getters - Data
  List<TicketCategory> get categories => _categories;
  List<TicketStatus> get statuses => _statuses;

  /// Returns tickets with client-side filtering applied
  /// - Excludes 'closed' tickets when viewing "All" (no status filter)
  /// - Applies search filter if search query is present
  List<Ticket> get tickets {
    var filteredTickets = _rawTickets.toList();

    // Exclude closed tickets when no specific status filter is applied (All mode)
    if (_filterStatusId == null) {
      filteredTickets = filteredTickets.where((ticket) {
        final statusName = ticket.status?.name.toLowerCase() ?? '';
        return statusName != 'closed';
      }).toList();
    }

    // Apply search filter if present
    if (_searchQuery != null && _searchQuery!.trim().isNotEmpty) {
      final searchLower = _searchQuery!.toLowerCase().trim();
      filteredTickets = filteredTickets.where((ticket) {
        final subjectMatch = ticket.subject.toLowerCase().contains(searchLower);
        final descriptionMatch = ticket.description.toLowerCase().contains(
          searchLower,
        );
        return subjectMatch || descriptionMatch;
      }).toList();
    }

    return filteredTickets;
  }

  List<Ticket> get recentTickets => _recentTickets;
  Ticket? get selectedTicket => _selectedTicket;
  TicketDetailResponse? get ticketDetailResponse => _ticketDetailResponse;
  Map<String, int> get statusCounts => _statusCounts;
  Map<String, int> get priorityCounts => _priorityCounts;
  Map<String, int> get categoryCounts => _categoryCounts;

  // Getters - Pagination
  int get currentPage => _currentPage;
  int get totalTickets => _totalTickets;
  bool get hasMoreTickets => _hasMoreTickets;

  // Getters - Filters
  int? get filterStatusId => _filterStatusId;
  String? get filterPriority => _filterPriority;
  String? get searchQuery => _searchQuery;

  // Getters - Error
  String? get errorMessage => _errorMessage;

  // Loading states
  bool get isCategoriesLoading => _categoriesState == TicketState.loading;
  bool get isStatusesLoading => _statusesState == TicketState.loading;
  bool get isTicketsLoading => _ticketsState == TicketState.loading;
  bool get isTicketDetailLoading => _ticketDetailState == TicketState.loading;
  bool get isCreatingTicket => _createTicketState == TicketState.loading;
  bool get isCreatingComment => _createCommentState == TicketState.loading;
  bool get isRecentTicketsLoading => _recentTicketsState == TicketState.loading;
  bool get isStatsLoading => _statsState == TicketState.loading;

  // Getters - Rating
  TicketRating? get currentRating => _currentRating;
  bool get isRatingLoading => _isRatingLoading;
  bool get isSubmittingRating => _isSubmittingRating;
  bool get hasRated => _hasRated;
  bool get isRatingChecked => _isRatingChecked;

  /// Load categories for dropdown
  Future<void> loadCategories() async {
    if (_categoriesState == TicketState.loading) return;

    _categoriesState = TicketState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _categories = await _ticketRepository.getActiveCategories();
      _categoriesState = TicketState.loaded;
    } on NetworkException catch (e) {
      _errorMessage = e.message;
      _categoriesState = TicketState.error;
    } on ServerException catch (e) {
      _errorMessage = e.message;
      _categoriesState = TicketState.error;
    } catch (e) {
      _errorMessage = 'Failed to load categories';
      _categoriesState = TicketState.error;
    }
    notifyListeners();
  }

  /// Load statuses for filtering
  Future<void> loadStatuses() async {
    if (_statusesState == TicketState.loading) return;

    _statusesState = TicketState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _statuses = await _ticketRepository.getActiveStatuses();
      _statusesState = TicketState.loaded;
    } on NetworkException catch (e) {
      _errorMessage = e.message;
      _statusesState = TicketState.error;
    } on ServerException catch (e) {
      _errorMessage = e.message;
      _statusesState = TicketState.error;
    } catch (e) {
      _errorMessage = 'Failed to load statuses';
      _statusesState = TicketState.error;
    }
    notifyListeners();
  }

  /// Load tickets with pagination and filters
  Future<void> loadTickets({bool refresh = false}) async {
    if (_ticketsState == TicketState.loading && !refresh) return;

    if (refresh) {
      _currentPage = 1;
      _rawTickets = [];
      _hasMoreTickets = true;
    }

    _ticketsState = TicketState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _ticketRepository.getTickets(
        page: _currentPage,
        limit: 10,
        statusId: _filterStatusId,
        statusName: _filterStatusName,
        priority: _filterPriority,
        search: _searchQuery,
      );

      if (refresh) {
        _rawTickets = response.tickets;
      } else {
        _rawTickets = [..._rawTickets, ...response.tickets];
      }

      _totalTickets = response.total;
      _hasMoreTickets = _rawTickets.length < _totalTickets;
      _ticketsState = TicketState.loaded;
    } on NetworkException catch (e) {
      _errorMessage = e.message;
      _ticketsState = TicketState.error;
    } on ServerException catch (e) {
      _errorMessage = e.message;
      _ticketsState = TicketState.error;
    } catch (e) {
      _errorMessage = 'Failed to load tickets';
      _ticketsState = TicketState.error;
    }
    notifyListeners();
  }

  /// Load more tickets (pagination)
  Future<void> loadMoreTickets() async {
    if (!_hasMoreTickets || _ticketsState == TicketState.loading) return;

    _currentPage++;
    await loadTickets();
  }

  /// Refresh tickets (pull to refresh)
  Future<void> refreshTickets() async {
    await loadTickets(refresh: true);
  }

  /// Load ticket detail by ID with comments
  /// Comments are fetched from ms-chat service endpoint which includes firstname field
  /// Ticket detail loads gracefully even if comments fail (e.g., offline)
  Future<void> loadTicketDetail(int ticketId) async {
    _ticketDetailState = TicketState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Load ticket detail (has cache fallback)
      final ticketResponse = await _ticketRepository.getTicketById(ticketId);

      // Try to load comments separately — they may fail offline (ms-chat service)
      CommentsResponse? commentsResponse;
      try {
        commentsResponse = await _ticketRepository.getTicketComments(ticketId);
      } catch (_) {
        // Comments unavailable (offline / ms-chat down) — continue with empty
        debugPrint(
          '[TicketProvider] Comments unavailable offline, showing ticket only',
        );
      }

      _ticketDetailResponse = TicketDetailResponse(
        ticket: ticketResponse.ticket,
        comments:
            commentsResponse?.comments.map((c) => c.toJson()).toList() ?? [],
        totalComments: commentsResponse?.total ?? 0,
      );
      _selectedTicket = _ticketDetailResponse?.ticket;
      _ticketDetailState = TicketState.loaded;
    } on NetworkException catch (e) {
      _errorMessage = e.message;
      _ticketDetailState = TicketState.error;
    } on ServerException catch (e) {
      _errorMessage = e.message;
      _ticketDetailState = TicketState.error;
    } on UnauthorizedException catch (e) {
      _errorMessage = e.message;
      _ticketDetailState = TicketState.error;
    } catch (e) {
      _errorMessage = 'Failed to load ticket detail';
      _ticketDetailState = TicketState.error;
    }
    notifyListeners();
  }

  /// Load recent tickets for home screen (limited to 3)
  Future<void> loadRecentTickets() async {
    if (_recentTicketsState == TicketState.loading) return;

    _recentTicketsState = TicketState.loading;
    notifyListeners();

    try {
      final response = await _ticketRepository.getTickets(page: 1, limit: 3);

      _recentTickets = response.tickets;
      _recentTicketsState = TicketState.loaded;
    } on NetworkException catch (e) {
      _errorMessage = e.message;
      _recentTicketsState = TicketState.error;
    } on ServerException catch (e) {
      _errorMessage = e.message;
      _recentTicketsState = TicketState.error;
    } catch (e) {
      _errorMessage = 'Failed to load recent tickets';
      _recentTicketsState = TicketState.error;
    }
    notifyListeners();
  }

  /// Load ticket statistics (counts by status, priority, and category)
  /// This loads all tickets without filter to get accurate counts
  Future<void> loadTicketStats() async {
    if (_statsState == TicketState.loading) return;

    _statsState = TicketState.loading;
    notifyListeners();

    try {
      // Load all tickets without filter to get accurate counts
      final response = await _ticketRepository.getTickets(
        page: 1,
        limit: 1000, // Load enough to get all tickets for counting
      );

      // Initialize status counts
      final statusCounts = <String, int>{
        'all': 0,
        'open': 0,
        'in_progress': 0,
        'pending': 0,
        'resolved': 0,
        'closed': 0,
      };

      // Initialize priority counts
      final priorityCounts = <String, int>{
        'low': 0,
        'medium': 0,
        'high': 0,
        'critical': 0,
      };

      // Initialize category counts (dynamic based on tickets)
      final categoryCounts = <String, int>{};

      // Count tickets by status, priority, and category
      for (final ticket in response.tickets) {
        // Count by status
        final statusName = ticket.status?.name.toLowerCase() ?? '';
        if (statusCounts.containsKey(statusName)) {
          statusCounts[statusName] = (statusCounts[statusName] ?? 0) + 1;
        }

        // Count by priority
        final priorityValue = ticket.priority.value;
        if (priorityCounts.containsKey(priorityValue)) {
          priorityCounts[priorityValue] =
              (priorityCounts[priorityValue] ?? 0) + 1;
        }

        // Count by category
        final categoryName = ticket.category?.name ?? 'Uncategorized';
        categoryCounts[categoryName] = (categoryCounts[categoryName] ?? 0) + 1;
      }

      // 'All' count excludes closed tickets
      statusCounts['all'] =
          (statusCounts['open'] ?? 0) +
          (statusCounts['in_progress'] ?? 0) +
          (statusCounts['pending'] ?? 0) +
          (statusCounts['resolved'] ?? 0);

      _statusCounts = statusCounts;
      _priorityCounts = priorityCounts;
      _categoryCounts = categoryCounts;
      _statsState = TicketState.loaded;
    } on NetworkException catch (e) {
      _errorMessage = e.message;
      _statsState = TicketState.error;
    } on ServerException catch (e) {
      _errorMessage = e.message;
      _statsState = TicketState.error;
    } catch (e) {
      _errorMessage = 'Failed to load ticket statistics';
      _statsState = TicketState.error;
    }
    notifyListeners();
  }

  /// Load home screen data (stats + recent tickets)
  Future<void> loadHomeData() async {
    await Future.wait([loadTicketStats(), loadRecentTickets()]);
  }

  /// Create new ticket
  Future<Ticket?> createTicket({
    required String subject,
    required String description,
    required int categoryId,
    required String priority,
    String? attachmentPath,
  }) async {
    _createTicketState = TicketState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      String? uploadedFilePath;

      // Upload attachment if provided
      if (attachmentPath != null && attachmentPath.isNotEmpty) {
        uploadedFilePath = await _ticketRepository.uploadFile(attachmentPath);
      }

      final ticket = await _ticketRepository.createTicket(
        subject: subject,
        description: description,
        categoryId: categoryId,
        priority: priority,
        attachmentUrl: uploadedFilePath,
      );

      _createTicketState = TicketState.loaded;

      // Add new ticket to the beginning of the list
      _rawTickets = [ticket, ..._rawTickets];
      _totalTickets++;

      // Update status counts (new tickets are always 'open')
      _statusCounts['all'] = (_statusCounts['all'] ?? 0) + 1;
      _statusCounts['open'] = (_statusCounts['open'] ?? 0) + 1;

      // Update priority counts
      final ticketPriorityValue = ticket.priority.value;
      _priorityCounts[ticketPriorityValue] =
          (_priorityCounts[ticketPriorityValue] ?? 0) + 1;

      // Update category counts
      final categoryName = ticket.category?.name ?? 'Uncategorized';
      _categoryCounts[categoryName] = (_categoryCounts[categoryName] ?? 0) + 1;

      notifyListeners();
      return ticket;
    } on NetworkException catch (e) {
      _errorMessage = e.message;
      _createTicketState = TicketState.error;
    } on ServerException catch (e) {
      _errorMessage = e.message;
      _createTicketState = TicketState.error;
    } on ValidationException catch (e) {
      _errorMessage = e.message;
      _createTicketState = TicketState.error;
    } on SessionRefreshedException catch (e) {
      // Token was refreshed but FormData upload couldn't be retried
      // Show a friendly message so user knows to just try again
      _errorMessage = e.message;
      _createTicketState = TicketState.error;
    } catch (e) {
      _errorMessage = 'Failed to create ticket';
      _createTicketState = TicketState.error;
    }
    notifyListeners();
    return null;
  }

  /// Create a comment on a ticket
  /// Content and attachmentUrl are both optional, but at least one must be provided
  Future<Comment?> createComment({
    required int ticketId,
    String? content,
    String? attachmentUrl,
  }) async {
    _createCommentState = TicketState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final comment = await _ticketRepository.createComment(
        ticketId: ticketId,
        content: content,
        attachmentUrl: attachmentUrl,
      );

      _createCommentState = TicketState.loaded;

      // Add comment to ticketDetailResponse if viewing same ticket
      if (_ticketDetailResponse != null &&
          _ticketDetailResponse!.ticket.id == ticketId) {
        final updatedComments = [
          ..._ticketDetailResponse!.comments,
          comment.toJson(),
        ];
        _ticketDetailResponse = TicketDetailResponse(
          ticket: _ticketDetailResponse!.ticket,
          comments: updatedComments,
          totalComments: _ticketDetailResponse!.totalComments + 1,
        );
      }

      notifyListeners();
      return comment;
    } on NetworkException catch (e) {
      _errorMessage = e.message;
      _createCommentState = TicketState.error;
    } on ServerException catch (e) {
      _errorMessage = e.message;
      _createCommentState = TicketState.error;
    } on ValidationException catch (e) {
      _errorMessage = e.message;
      _createCommentState = TicketState.error;
    } catch (e) {
      _errorMessage = 'Failed to send message';
      _createCommentState = TicketState.error;
    }
    notifyListeners();
    return null;
  }

  /// Upload attachment for comment
  /// Returns the URL path to use in comment or WebSocket message
  Future<String?> uploadCommentAttachment({
    required int ticketId,
    required String filePath,
  }) async {
    _errorMessage = null;

    try {
      final url = await _ticketRepository.uploadCommentAttachment(
        ticketId: ticketId,
        filePath: filePath,
      );
      return url;
    } on NetworkException catch (e) {
      _errorMessage = e.message;
    } on ServerException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to upload attachment';
    }
    notifyListeners();
    return null;
  }

  /// Get chat file URL for viewing/downloading
  String getChatFileUrl(String filename) {
    return _ticketRepository.getChatFileUrl(filename);
  }

  /// Set filter status
  void setFilterStatus(int? statusId, {String? statusName}) {
    if (_filterStatusId != statusId) {
      _filterStatusId = statusId;
      _filterStatusName = statusName;
      loadTickets(refresh: true);
    }
  }

  /// Set filter priority
  void setFilterPriority(String? priority) {
    if (_filterPriority != priority) {
      _filterPriority = priority;
      loadTickets(refresh: true);
    }
  }

  /// Set search query (client-side filtering)
  void setSearchQuery(String? query) {
    final normalizedQuery = query?.trim().isEmpty == true
        ? null
        : query?.trim();
    if (_searchQuery != normalizedQuery) {
      _searchQuery = normalizedQuery;
      // No need to reload from API - client-side filtering is applied in getter
      notifyListeners();
    }
  }

  /// Clear all filters
  void clearFilters() {
    _filterStatusId = null;
    _filterPriority = null;
    _searchQuery = null;
    loadTickets(refresh: true);
  }

  /// Reset filters and load tickets (used when screen initializes)
  void resetAndLoadTickets() {
    _filterStatusId = null;
    _filterPriority = null;
    _searchQuery = null;
    loadTickets(refresh: true);
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear selected ticket
  void clearSelectedTicket() {
    _selectedTicket = null;
    _ticketDetailResponse = null;
    _ticketDetailState = TicketState.initial;
    clearRatingState();
    notifyListeners();
  }

  /// Get file download URL
  String getFileUrl(String filename) {
    return _ticketRepository.getFileUrl(filename);
  }

  /// Get ticket counts by status (returns pre-loaded stats)
  Map<String, int> getTicketCountsByStatus() {
    return _statusCounts;
  }

  /// Refresh status counts (call after creating/updating/deleting tickets)
  Future<void> refreshStatusCounts() async {
    await loadTicketStats();
  }

  // ============================================================
  // Methods for infinite_scroll_pagination support
  // ============================================================

  /// Fetch a specific page of tickets (used by PagingController)
  /// Returns TicketListResponse directly without updating internal state
  Future<TicketListResponse> fetchTicketsPage({
    required int page,
    required int limit,
  }) async {
    return await _ticketRepository.getTickets(
      page: page,
      limit: limit,
      statusId: _filterStatusId,
      statusName: _filterStatusName,
      priority: _filterPriority,
      search: _searchQuery,
    );
  }

  /// Set filter status without triggering reload (used with PagingController)
  /// The PagingController will handle refreshing the list
  void setFilterStatusForPaging(int? statusId, {String? statusName}) {
    _filterStatusId = statusId;
    _filterStatusName = statusName;
  }

  /// Set search query for paging (without notifying listeners)
  void setSearchQueryForPaging(String? query) {
    _searchQuery = query?.trim().isEmpty == true ? null : query?.trim();
  }

  /// Set filter priority for paging (without notifying listeners)
  void setFilterPriorityForPaging(String? priority) {
    _filterPriority = priority;
  }

  // ============================================================
  // Rating methods
  // ============================================================

  /// Load existing rating for a ticket
  /// Called when entering ticket detail screen
  Future<void> loadTicketRating(int ticketId) async {
    _isRatingLoading = true;
    _isRatingChecked = false;
    _currentRating = null;
    _hasRated = false;
    notifyListeners();

    try {
      final rating = await _ticketRepository.getTicketRating(ticketId);
      _currentRating = rating;
      _hasRated = rating != null;
    } catch (e) {
      _hasRated = false;
    }

    _isRatingLoading = false;
    _isRatingChecked = true;
    notifyListeners();
  }

  /// Submit a rating for a closed ticket
  /// Returns true if successful, false otherwise
  Future<bool> submitTicketRating({
    required int ticketId,
    required int rating,
    String? comment,
  }) async {
    _isSubmittingRating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _ticketRepository.submitRating(
        ticketId: ticketId,
        rating: rating,
        comment: comment,
      );
      _currentRating = result;
      _hasRated = true;
      _isSubmittingRating = false;
      notifyListeners();
      return true;
    } on NetworkException {
      _errorMessage =
          'No internet connection. Please check your network and try again.';
    } on ServerException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Something went wrong. Please try again later.';
    }

    _isSubmittingRating = false;
    notifyListeners();
    return false;
  }

  /// Clear rating state (called when leaving ticket detail)
  void clearRatingState() {
    _currentRating = null;
    _isRatingLoading = false;
    _isSubmittingRating = false;
    _hasRated = false;
    _isRatingChecked = false;
  }
}
