import 'package:flutter/foundation.dart';
import '../core/errors/exceptions.dart';
import '../features/tickets/models/ticket_model.dart';
import '../features/tickets/models/ticket_category_model.dart';
import '../features/tickets/models/ticket_status_model.dart';
import '../features/tickets/repositories/ticket_repository.dart';

/// Ticket loading state enum
enum TicketState {
  initial,
  loading,
  loaded,
  error,
}

/// Ticket provider for state management
class TicketProvider extends ChangeNotifier {
  final TicketRepository _ticketRepository;

  // States
  TicketState _categoriesState = TicketState.initial;
  TicketState _statusesState = TicketState.initial;
  TicketState _ticketsState = TicketState.initial;
  TicketState _ticketDetailState = TicketState.initial;
  TicketState _createTicketState = TicketState.initial;
  TicketState _recentTicketsState = TicketState.initial;
  TicketState _statsState = TicketState.initial;

  // Data
  List<TicketCategory> _categories = [];
  List<TicketStatus> _statuses = [];
  List<Ticket> _rawTickets = []; // Raw tickets from API
  List<Ticket> _recentTickets = [];
  Ticket? _selectedTicket;

  // Stats
  Map<String, int> _ticketStats = {
    'all': 0,
    'open': 0,
    'in_progress': 0,
    'resolved': 0,
  };

  // Pagination
  int _currentPage = 1;
  int _totalTickets = 0;
  bool _hasMoreTickets = true;

  // Filters
  int? _filterStatusId;
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
  TicketState get recentTicketsState => _recentTicketsState;
  TicketState get statsState => _statsState;

  // Getters - Data
  List<TicketCategory> get categories => _categories;
  List<TicketStatus> get statuses => _statuses;

  /// Returns tickets with client-side search filtering applied
  /// This ensures search works even if backend doesn't support search param
  List<Ticket> get tickets {
    if (_searchQuery == null || _searchQuery!.trim().isEmpty) {
      return _rawTickets;
    }

    final searchLower = _searchQuery!.toLowerCase().trim();
    return _rawTickets.where((ticket) {
      final subjectMatch = ticket.subject.toLowerCase().contains(searchLower);
      final descriptionMatch = ticket.description.toLowerCase().contains(searchLower);
      return subjectMatch || descriptionMatch;
    }).toList();
  }

  List<Ticket> get recentTickets => _recentTickets;
  Ticket? get selectedTicket => _selectedTicket;
  Map<String, int> get ticketStats => _ticketStats;

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
  bool get isRecentTicketsLoading => _recentTicketsState == TicketState.loading;
  bool get isStatsLoading => _statsState == TicketState.loading;

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

  /// Load ticket detail by ID
  Future<void> loadTicketDetail(int ticketId) async {
    _ticketDetailState = TicketState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedTicket = await _ticketRepository.getTicketById(ticketId);
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
      final response = await _ticketRepository.getTickets(
        page: 1,
        limit: 3,
      );

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

  /// Load ticket statistics for home screen
  Future<void> loadTicketStats() async {
    if (_statsState == TicketState.loading) return;

    _statsState = TicketState.loading;
    notifyListeners();

    try {
      // Load all tickets without filter to get counts
      final response = await _ticketRepository.getTickets(
        page: 1,
        limit: 100, // Get more to calculate accurate stats
      );

      final stats = <String, int>{
        'all': response.total,
        'open': 0,
        'in_progress': 0,
        'resolved': 0,
      };

      // Count tickets by status
      for (final ticket in response.tickets) {
        final statusName = ticket.status?.name.toLowerCase().replaceAll('_', ' ') ?? '';
        switch (statusName) {
          case 'open':
            stats['open'] = (stats['open'] ?? 0) + 1;
            break;
          case 'in progress':
            stats['in_progress'] = (stats['in_progress'] ?? 0) + 1;
            break;
          case 'resolved':
            stats['resolved'] = (stats['resolved'] ?? 0) + 1;
            break;
        }
      }

      _ticketStats = stats;
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
    await Future.wait([
      loadTicketStats(),
      loadRecentTickets(),
    ]);
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
    } catch (e) {
      _errorMessage = 'Failed to create ticket';
      _createTicketState = TicketState.error;
    }
    notifyListeners();
    return null;
  }

  /// Set filter status
  void setFilterStatus(int? statusId) {
    if (_filterStatusId != statusId) {
      _filterStatusId = statusId;
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
    final normalizedQuery = query?.trim().isEmpty == true ? null : query?.trim();
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
    _ticketDetailState = TicketState.initial;
    notifyListeners();
  }

  /// Get file download URL
  String getFileUrl(String filename) {
    return _ticketRepository.getFileUrl(filename);
  }

  /// Get ticket counts by status (for home screen stats)
  Map<String, int> getTicketCountsByStatus() {
    final counts = <String, int>{
      'all': _totalTickets,
      'open': 0,
      'in_progress': 0,
      'pending': 0,
      'resolved': 0,
      'closed': 0,
    };

    for (final ticket in _rawTickets) {
      final statusName = ticket.status?.name.toLowerCase() ?? '';
      if (counts.containsKey(statusName)) {
        counts[statusName] = (counts[statusName] ?? 0) + 1;
      }
    }

    return counts;
  }
}
