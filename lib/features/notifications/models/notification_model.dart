/// Types of notifications that can be received
enum NotificationType {
  statusChange,
  assignment,
  overdue,
  warning,
  autoClose,
  newComment,
  unknown;

  static NotificationType fromString(String value) {
    switch (value) {
      case 'status_change':
        return NotificationType.statusChange;
      case 'assignment':
        return NotificationType.assignment;
      case 'overdue':
        return NotificationType.overdue;
      case 'warning':
        return NotificationType.warning;
      case 'auto_close':
        return NotificationType.autoClose;
      case 'new_comment':
        return NotificationType.newComment;
      default:
        return NotificationType.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case NotificationType.statusChange:
        return 'Status Update';
      case NotificationType.assignment:
        return 'Assignment';
      case NotificationType.overdue:
        return 'Overdue';
      case NotificationType.warning:
        return 'Warning';
      case NotificationType.autoClose:
        return 'Auto Close';
      case NotificationType.newComment:
        return 'New Comment';
      case NotificationType.unknown:
        return 'Notification';
    }
  }
}

/// Model representing a notification from the backend
class NotificationItem {
  final int id;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic> metadata;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.metadata,
    required this.isRead,
    required this.createdAt,
  });

  /// Parse from JSON response
  ///
  /// Accepts `Map<dynamic, dynamic>` because IPC round-trips via
  /// flutter_background_service lose generic type info (nested maps become
  /// `Map<Object?, Object?>`).
  factory NotificationItem.fromJson(Map<dynamic, dynamic> json) {
    // Safe-cast nested metadata map
    final rawMeta = json['metadata'];
    final Map<String, dynamic> meta = rawMeta is Map
        ? rawMeta.map<String, dynamic>(
            (key, value) => MapEntry(key.toString(), value),
          )
        : <String, dynamic>{};

    return NotificationItem(
      id: json['id'] as int? ?? 0,
      type: NotificationType.fromString(json['type'] as String? ?? ''),
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      metadata: meta,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Create a copy with updated read status
  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      message: message,
      metadata: metadata,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  /// Get ticket ID from metadata if available
  int? get ticketId {
    final id = metadata['ticket_id'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    return null;
  }

  /// Get old status from metadata (for status_change type)
  String? get oldStatus => metadata['old_status'] as String?;

  /// Get new status from metadata (for status_change type)
  String? get newStatus => metadata['new_status'] as String?;

  @override
  String toString() {
    return 'NotificationItem(id: $id, type: $type, title: $title, isRead: $isRead)';
  }
}

/// Response wrapper for notification list with pagination
class NotificationListResponse {
  final List<NotificationItem> items;
  final int page;
  final int limit;
  final int total;

  NotificationListResponse({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? [];
    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};

    return NotificationListResponse(
      items: data
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: pagination['page'] as int? ?? 1,
      limit: pagination['limit'] as int? ?? 20,
      total: pagination['total'] as int? ?? 0,
    );
  }

  bool get hasMore => page * limit < total;
}

/// Response wrapper for unread count
class UnreadCountResponse {
  final int count;

  UnreadCountResponse({required this.count});

  factory UnreadCountResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return UnreadCountResponse(count: data['count'] as int? ?? 0);
  }
}
