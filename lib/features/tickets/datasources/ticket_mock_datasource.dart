import '../models/ticket_model.dart';
import '../models/ticket_category_model.dart';
import '../models/ticket_status_model.dart';

class TicketMockDatasource {
  // Mock categories
  final List<TicketCategory> _categories = [
    TicketCategory(
      id: 1,
      name: 'Technical Issue',
      description: 'Technical issues and system errors',
      isActive: true,
    ),
    TicketCategory(
      id: 2,
      name: 'Account Access',
      description: 'Account access and login problems',
      isActive: true,
    ),
    TicketCategory(
      id: 3,
      name: 'Billing',
      description: 'Billing and payment related issues',
      isActive: true,
    ),
    TicketCategory(
      id: 4,
      name: 'Feature Request',
      description: 'Feature requests and suggestions',
      isActive: true,
    ),
    TicketCategory(
      id: 5,
      name: 'General Support',
      description: 'General support and inquiries',
      isActive: true,
    ),
    TicketCategory(
      id: 6,
      name: 'Bug Report',
      description: 'Bug reports and error tracking',
      isActive: true,
    ),
    TicketCategory(
      id: 7,
      name: 'Other',
      description: 'Other miscellaneous issues',
      isActive: true,
    ),
  ];

  // Mock statuses
  final List<TicketStatus> _statuses = [
    TicketStatus(
      id: 1,
      name: 'open',
      description: 'New ticket created',
      isFinal: false,
      displayOrder: 1,
      isActive: true,
    ),
    TicketStatus(
      id: 2,
      name: 'in_progress',
      description: 'Ticket being handled',
      isFinal: false,
      displayOrder: 2,
      isActive: true,
    ),
    TicketStatus(
      id: 3,
      name: 'pending',
      description: 'Waiting for information/action',
      isFinal: false,
      displayOrder: 3,
      isActive: true,
    ),
    TicketStatus(
      id: 4,
      name: 'resolved',
      description: 'Issue has been resolved',
      isFinal: false,
      displayOrder: 4,
      isActive: true,
    ),
    TicketStatus(
      id: 5,
      name: 'closed',
      description: 'Ticket closed',
      isFinal: true,
      displayOrder: 5,
      isActive: true,
    ),
  ];

  // Mock tickets
  final List<Ticket> _tickets = [];
  int _nextTicketId = 1;

  TicketMockDatasource() {
    _initializeMockTickets();
  }

  void _initializeMockTickets() {
    _tickets.addAll([
      Ticket(
        id: _nextTicketId++,
        subject: 'Laptop Won\'t Boot',
        description: 'My laptop is not turning on after the latest update. I have tried restarting multiple times but the screen remains black.',
        categoryId: 1,
        statusId: 1,
        priority: TicketPriority.high,
        createdBy: 1,
        category: _categories[0],
        status: _statuses[0],
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Ticket(
        id: _nextTicketId++,
        subject: 'Cannot Access Email',
        description: 'I am unable to log into my company email account. It keeps showing invalid credentials error.',
        categoryId: 2,
        statusId: 2,
        priority: TicketPriority.medium,
        createdBy: 1,
        category: _categories[1],
        status: _statuses[1],
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Ticket(
        id: _nextTicketId++,
        subject: 'Request for New Software License',
        description: 'I need a license for Adobe Creative Suite for my design work.',
        categoryId: 4,
        statusId: 3,
        priority: TicketPriority.low,
        createdBy: 1,
        category: _categories[3],
        status: _statuses[2],
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),
      Ticket(
        id: _nextTicketId++,
        subject: 'Network Connectivity Issue',
        description: 'The WiFi connection in the meeting room keeps dropping every few minutes.',
        categoryId: 1,
        statusId: 4,
        priority: TicketPriority.high,
        createdBy: 1,
        category: _categories[0],
        status: _statuses[3],
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Ticket(
        id: _nextTicketId++,
        subject: 'Billing Inquiry',
        description: 'I received a charge on my account that I do not recognize.',
        categoryId: 3,
        statusId: 5,
        priority: TicketPriority.medium,
        createdBy: 1,
        category: _categories[2],
        status: _statuses[4],
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ]);
  }

  Future<List<TicketCategory>> getActiveCategories() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _categories.where((c) => c.isActive).toList();
  }

  Future<List<TicketStatus>> getActiveStatuses() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _statuses.where((s) => s.isActive).toList();
  }

  Future<TicketListResponse> getTickets({
    int page = 1,
    int limit = 10,
    int? statusId,
    String? priority,
    String? search,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    var filteredTickets = List<Ticket>.from(_tickets);

    if (statusId != null) {
      filteredTickets = filteredTickets.where((t) => t.statusId == statusId).toList();
    }

    if (priority != null) {
      final priorityEnum = TicketPriority.values.firstWhere(
        (p) => p.name.toLowerCase() == priority.toLowerCase(),
        orElse: () => TicketPriority.medium,
      );
      filteredTickets = filteredTickets.where((t) => t.priority == priorityEnum).toList();
    }

    if (search != null && search.isNotEmpty) {
      final searchLower = search.toLowerCase();
      filteredTickets = filteredTickets.where((t) {
        return t.subject.toLowerCase().contains(searchLower) ||
            t.description.toLowerCase().contains(searchLower);
      }).toList();
    }

    filteredTickets.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.now();
      final bDate = b.createdAt ?? DateTime.now();
      return bDate.compareTo(aDate);
    });

    final total = filteredTickets.length;
    final startIndex = (page - 1) * limit;
    final endIndex = startIndex + limit;

    final paginatedTickets = filteredTickets.sublist(
      startIndex.clamp(0, total),
      endIndex.clamp(0, total),
    );

    return TicketListResponse(
      tickets: paginatedTickets,
      total: total,
      page: page,
      limit: limit,
    );
  }

  Future<Ticket> getTicketById(int id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _tickets.firstWhere(
      (t) => t.id == id,
      orElse: () => throw Exception('Ticket not found'),
    );
  }

  Future<Ticket> createTicket({
    required String subject,
    required String description,
    required int categoryId,
    required String priority,
    String? attachmentPath,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1000));

    final category = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => _categories.first,
    );

    final priorityEnum = TicketPriority.values.firstWhere(
      (p) => p.name.toLowerCase() == priority.toLowerCase(),
      orElse: () => TicketPriority.medium,
    );

    final newTicket = Ticket(
      id: _nextTicketId++,
      subject: subject,
      description: description,
      categoryId: categoryId,
      statusId: 1,
      priority: priorityEnum,
      attachment: attachmentPath,
      createdBy: 1,
      category: category,
      status: _statuses[0],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _tickets.insert(0, newTicket);
    return newTicket;
  }

  Future<String> uploadFile(String filePath) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final filename = filePath.split('/').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '/uploads/${timestamp}_$filename';
  }

  String getFileUrl(String filename) {
    return 'https://example.com$filename';
  }
}
