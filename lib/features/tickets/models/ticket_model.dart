import 'ticket_category_model.dart';
import 'ticket_status_model.dart';

enum TicketPriority { low, medium, high, critical }

extension TicketPriorityExtension on TicketPriority {
  String get value {
    switch (this) {
      case TicketPriority.low:
        return 'low';
      case TicketPriority.medium:
        return 'medium';
      case TicketPriority.high:
        return 'high';
      case TicketPriority.critical:
        return 'critical';
    }
  }

  String get displayName {
    switch (this) {
      case TicketPriority.low:
        return 'Low';
      case TicketPriority.medium:
        return 'Medium';
      case TicketPriority.high:
        return 'High';
      case TicketPriority.critical:
        return 'Critical';
    }
  }

  static TicketPriority fromString(String value) {
    switch (value.toLowerCase()) {
      case 'low':
        return TicketPriority.low;
      case 'medium':
        return TicketPriority.medium;
      case 'high':
        return TicketPriority.high;
      case 'critical':
        return TicketPriority.critical;
      default:
        return TicketPriority.medium;
    }
  }
}

class Ticket {
  final int id;
  final String subject;
  final String description;
  final int categoryId;
  final int statusId;
  final TicketPriority priority;
  final String? attachment;
  final int createdBy;
  final int? assignedTo;
  final TicketCategory? category;
  final TicketStatus? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Ticket({
    required this.id,
    required this.subject,
    required this.description,
    required this.categoryId,
    required this.statusId,
    required this.priority,
    this.attachment,
    required this.createdBy,
    this.assignedTo,
    this.category,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as int,
      subject: json['subject'] as String,
      description: json['description'] as String,
      categoryId: json['category_id'] as int,
      statusId: json['status_id'] as int,
      priority: TicketPriorityExtension.fromString(
        json['priority'] as String? ?? 'medium',
      ),
      attachment: json['attachment'] as String?,
      createdBy: json['created_by'] as int,
      assignedTo: json['assigned_to'] as int?,
      category: json['category'] != null
          ? TicketCategory.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      status: json['status'] != null
          ? TicketStatus.fromJson(json['status'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'description': description,
      'category_id': categoryId,
      'status_id': statusId,
      'priority': priority.value,
      'attachment': attachment,
      'created_by': createdBy,
      'assigned_to': assignedTo,
    };
  }

  Ticket copyWith({
    int? id,
    String? subject,
    String? description,
    int? categoryId,
    int? statusId,
    TicketPriority? priority,
    String? attachment,
    int? createdBy,
    int? assignedTo,
    TicketCategory? category,
    TicketStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Ticket(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      statusId: statusId ?? this.statusId,
      priority: priority ?? this.priority,
      attachment: attachment ?? this.attachment,
      createdBy: createdBy ?? this.createdBy,
      assignedTo: assignedTo ?? this.assignedTo,
      category: category ?? this.category,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get time ago string from createdAt
  String get timeAgo {
    if (createdAt == null) return '';

    final now = DateTime.now();
    final difference = now.difference(createdAt!);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  String toString() => 'Ticket(id: $id, subject: $subject, status: ${status?.name})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ticket && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Response model for paginated ticket list
class TicketListResponse {
  final List<Ticket> tickets;
  final int total;
  final int page;
  final int limit;
  final bool hasNext;
  final bool hasPrev;

  TicketListResponse({
    required this.tickets,
    required this.total,
    required this.page,
    required this.limit,
    this.hasNext = false,
    this.hasPrev = false,
  });

  factory TicketListResponse.fromJson(Map<String, dynamic> json) {
    return TicketListResponse(
      tickets: (json['data'] as List<dynamic>?)
              ?.map((e) => Ticket.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['meta']?['total_items'] as int? ?? 0,
      page: json['meta']?['current_page'] as int? ?? 1,
      limit: json['meta']?['limit'] as int? ?? 10,
      hasNext: json['meta']?['has_next'] as bool? ?? false,
      hasPrev: json['meta']?['has_prev'] as bool? ?? false,
    );
  }

  bool get hasMore => hasNext;
}

/// Response model for ticket detail with comments
class TicketDetailResponse {
  final Ticket ticket;
  final List<dynamic> comments;
  final int totalComments;

  TicketDetailResponse({
    required this.ticket,
    required this.comments,
    required this.totalComments,
  });

  factory TicketDetailResponse.fromJson(Map<String, dynamic> json) {
    final commentsData = json['comments'] as Map<String, dynamic>?;

    return TicketDetailResponse(
      ticket: Ticket.fromJson(json['data'] as Map<String, dynamic>),
      comments: commentsData?['data'] as List<dynamic>? ?? [],
      totalComments: commentsData?['total'] as int? ?? 0,
    );
  }
}
