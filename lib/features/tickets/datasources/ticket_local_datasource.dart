import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../data/datasources/local/database_helper.dart';
import '../models/ticket_model.dart';
import '../models/ticket_category_model.dart';
import '../models/ticket_status_model.dart';

/// Local datasource for offline caching of ticket data.
/// Uses sqflite to store and retrieve tickets, categories, statuses,
/// and dashboard statistics for offline access.
class TicketLocalDatasource {
  final DatabaseHelper _dbHelper;

  TicketLocalDatasource(this._dbHelper);

  // ==================== TICKETS ====================

  /// Cache a list of tickets (insert or replace)
  Future<void> cacheTickets(List<Ticket> tickets) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    for (final ticket in tickets) {
      batch.insert(
        'tickets',
        _ticketToMap(ticket),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    await updateSyncTime('tickets');
  }

  /// Get cached tickets with optional filters and pagination
  /// Supports filtering by statusId (integer), statusName (string fallback),
  /// priority, and search text
  Future<TicketListResponse> getCachedTickets({
    int page = 1,
    int limit = 10,
    int? statusId,
    String? statusName,
    String? priority,
    String? search,
  }) async {
    final db = await _dbHelper.database;

    // Build WHERE clause
    final conditions = <String>[];
    final args = <dynamic>[];

    if (statusId != null) {
      conditions.add('status_id = ?');
      args.add(statusId);
    }
    if (priority != null && priority.isNotEmpty) {
      conditions.add('priority = ?');
      args.add(priority);
    }
    if (search != null && search.isNotEmpty) {
      conditions.add('(subject LIKE ? OR description LIKE ?)');
      args.add('%$search%');
      args.add('%$search%');
    }

    final whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : null;

    // Get total count for pagination info
    final countResult = await db.query(
      'tickets',
      columns: ['COUNT(*) as count'],
      where: whereClause,
      whereArgs: args.isNotEmpty ? args : null,
    );
    var total = Sqflite.firstIntValue(countResult) ?? 0;

    // If statusId filter returned 0 results but statusName is available,
    // retry with name-based matching on the status_json column.
    // This handles cases where hardcoded status IDs don't match backend IDs.
    if (total == 0 &&
        statusId != null &&
        statusName != null &&
        statusName.isNotEmpty) {
      final nameConditions = <String>[];
      final nameArgs = <dynamic>[];

      // Match by status name inside the JSON blob
      // Try both exact name and snake_case variant (backend may store either)
      final snakeName = statusName.toLowerCase().replaceAll(' ', '_');
      nameConditions.add('(status_json LIKE ? OR status_json LIKE ?)');
      nameArgs.add('%"name":"$statusName"%');
      nameArgs.add('%"name":"$snakeName"%');

      if (priority != null && priority.isNotEmpty) {
        nameConditions.add('priority = ?');
        nameArgs.add(priority);
      }
      if (search != null && search.isNotEmpty) {
        nameConditions.add('(subject LIKE ? OR description LIKE ?)');
        nameArgs.add('%$search%');
        nameArgs.add('%$search%');
      }

      final nameWhere = nameConditions.join(' AND ');
      final nameCount = await db.query(
        'tickets',
        columns: ['COUNT(*) as count'],
        where: nameWhere,
        whereArgs: nameArgs,
      );
      total = Sqflite.firstIntValue(nameCount) ?? 0;

      // Use name-based query for results
      final offset = (page - 1) * limit;
      final results = await db.query(
        'tickets',
        where: nameWhere,
        whereArgs: nameArgs,
        orderBy: 'created_at DESC',
        limit: limit,
        offset: offset,
      );

      final tickets = results.map(_ticketFromMap).toList();
      final hasNext = (page * limit) < total;

      return TicketListResponse(
        tickets: tickets,
        total: total,
        page: page,
        limit: limit,
        hasNext: hasNext,
        hasPrev: page > 1,
      );
    }

    // Get paginated results (normal path)
    final offset = (page - 1) * limit;
    final results = await db.query(
      'tickets',
      where: whereClause,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    final tickets = results.map(_ticketFromMap).toList();
    final hasNext = (page * limit) < total;

    return TicketListResponse(
      tickets: tickets,
      total: total,
      page: page,
      limit: limit,
      hasNext: hasNext,
      hasPrev: page > 1,
    );
  }

  /// Get a single cached ticket by ID
  Future<Ticket?> getCachedTicketById(int id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'tickets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _ticketFromMap(results.first);
  }

  // ==================== CATEGORIES ====================

  /// Cache ticket categories
  Future<void> cacheCategories(List<TicketCategory> categories) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    // Clear existing and re-insert
    batch.delete('ticket_categories');
    for (final category in categories) {
      batch.insert('ticket_categories', {
        'id': category.id,
        'name': category.name,
        'description': category.description,
        'is_active': category.isActive ? 1 : 0,
        'created_at': category.createdAt?.toIso8601String(),
        'updated_at': category.updatedAt?.toIso8601String(),
      });
    }

    await batch.commit(noResult: true);
    await updateSyncTime('ticket_categories');
  }

  /// Get cached categories
  Future<List<TicketCategory>> getCachedCategories() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'ticket_categories',
      where: 'is_active = ?',
      whereArgs: [1],
    );

    return results.map((row) {
      return TicketCategory(
        id: row['id'] as int,
        name: row['name'] as String,
        description: row['description'] as String?,
        isActive: (row['is_active'] as int) == 1,
        createdAt: row['created_at'] != null
            ? DateTime.parse(row['created_at'] as String)
            : null,
        updatedAt: row['updated_at'] != null
            ? DateTime.parse(row['updated_at'] as String)
            : null,
      );
    }).toList();
  }

  // ==================== STATUSES ====================

  /// Cache ticket statuses
  Future<void> cacheStatuses(List<TicketStatus> statuses) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    batch.delete('ticket_statuses');
    for (final status in statuses) {
      batch.insert('ticket_statuses', {
        'id': status.id,
        'name': status.name,
        'description': status.description,
        'is_final': status.isFinal ? 1 : 0,
        'display_order': status.displayOrder,
        'is_active': status.isActive ? 1 : 0,
        'created_at': status.createdAt?.toIso8601String(),
        'updated_at': status.updatedAt?.toIso8601String(),
      });
    }

    await batch.commit(noResult: true);
    await updateSyncTime('ticket_statuses');
  }

  /// Get cached statuses
  Future<List<TicketStatus>> getCachedStatuses() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'ticket_statuses',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'display_order ASC',
    );

    return results.map((row) {
      return TicketStatus(
        id: row['id'] as int,
        name: row['name'] as String,
        description: row['description'] as String?,
        isFinal: (row['is_final'] as int) == 1,
        displayOrder: row['display_order'] as int,
        isActive: (row['is_active'] as int) == 1,
        createdAt: row['created_at'] != null
            ? DateTime.parse(row['created_at'] as String)
            : null,
        updatedAt: row['updated_at'] != null
            ? DateTime.parse(row['updated_at'] as String)
            : null,
      );
    }).toList();
  }

  // ==================== DASHBOARD CACHE ====================

  /// Cache dashboard stats as JSON string
  Future<void> cacheDashboardStats(String key, String jsonData) async {
    final db = await _dbHelper.database;
    await db.insert('dashboard_cache', {
      'cache_key': key,
      'data': jsonData,
      'cached_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get cached dashboard stats by key
  Future<String?> getCachedDashboardStats(String key) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'dashboard_cache',
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return results.first['data'] as String;
  }

  // ==================== CACHE METADATA ====================

  /// Check if any cached data exists (for smart connectivity decisions)
  Future<bool> hasCache() async {
    final db = await _dbHelper.database;
    final result = await db.query('cache_metadata', limit: 1);
    return result.isNotEmpty;
  }

  /// Check if specific table has cached data
  Future<bool> hasTableCache(String tableName) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'cache_metadata',
      where: 'table_name = ?',
      whereArgs: [tableName],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Get last sync time for a table
  Future<DateTime?> getLastSyncTime(String tableName) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'cache_metadata',
      where: 'table_name = ?',
      whereArgs: [tableName],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return DateTime.parse(results.first['last_synced_at'] as String);
  }

  /// Update sync time for a table
  Future<void> updateSyncTime(String tableName) async {
    final db = await _dbHelper.database;
    await db.insert('cache_metadata', {
      'table_name': tableName,
      'last_synced_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Clear all cached data (used on logout)
  Future<void> clearAllCache() async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    batch.delete('tickets');
    batch.delete('ticket_categories');
    batch.delete('ticket_statuses');
    batch.delete('dashboard_cache');
    batch.delete('cache_metadata');
    await batch.commit(noResult: true);
  }

  // ==================== HELPERS ====================

  /// Convert Ticket to a Map for sqflite storage
  /// Nested objects (creator_info, assignee_info, category, status)
  /// are stored as JSON strings
  Map<String, dynamic> _ticketToMap(Ticket ticket) {
    return {
      'id': ticket.id,
      'subject': ticket.subject,
      'description': ticket.description,
      'category_id': ticket.categoryId,
      'status_id': ticket.statusId,
      'priority': ticket.priority.value,
      'attachment': ticket.attachment,
      'created_by': ticket.createdBy,
      'assigned_to': ticket.assignedTo,
      'creator_info': ticket.creatorInfo != null
          ? jsonEncode(ticket.creatorInfo!.toJson())
          : null,
      'assignee_info': ticket.assigneeInfo != null
          ? jsonEncode(ticket.assigneeInfo!.toJson())
          : null,
      'category_json': ticket.category != null
          ? jsonEncode(ticket.category!.toJson())
          : null,
      'status_json': ticket.status != null
          ? jsonEncode(ticket.status!.toJson())
          : null,
      'created_at': ticket.createdAt?.toIso8601String(),
      'updated_at': ticket.updatedAt?.toIso8601String(),
    };
  }

  /// Convert a sqflite row Map back to a Ticket object
  Ticket _ticketFromMap(Map<String, dynamic> map) {
    return Ticket(
      id: map['id'] as int,
      subject: map['subject'] as String,
      description: map['description'] as String? ?? '',
      categoryId: map['category_id'] as int? ?? 0,
      statusId: map['status_id'] as int? ?? 0,
      priority: TicketPriorityExtension.fromString(
        map['priority'] as String? ?? 'medium',
      ),
      attachment: map['attachment'] as String?,
      createdBy: map['created_by'] as int? ?? 0,
      assignedTo: map['assigned_to'] as int?,
      creatorInfo: map['creator_info'] != null
          ? UserInfo.fromJson(
              jsonDecode(map['creator_info'] as String) as Map<String, dynamic>,
            )
          : null,
      assigneeInfo: map['assignee_info'] != null
          ? UserInfo.fromJson(
              jsonDecode(map['assignee_info'] as String)
                  as Map<String, dynamic>,
            )
          : null,
      category: map['category_json'] != null
          ? TicketCategory.fromJson(
              jsonDecode(map['category_json'] as String)
                  as Map<String, dynamic>,
            )
          : null,
      status: map['status_json'] != null
          ? TicketStatus.fromJson(
              jsonDecode(map['status_json'] as String) as Map<String, dynamic>,
            )
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }
}
