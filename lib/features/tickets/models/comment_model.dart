/// Comment/Chat message model for ticket conversations
class Comment {
  final int id;
  final int ticketId;
  final int userId;
  final String userName;
  final String userRole;
  final String content;
  final String? attachment;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.ticketId,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.content,
    this.attachment,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as int,
      ticketId: json['ticket_id'] as int,
      userId: json['user_id'] as int,
      userName: json['user_name'] as String? ?? 'Unknown',
      userRole: json['user_role'] as String? ?? 'customer',
      content: json['content'] as String,
      attachment: json['attachment'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticket_id': ticketId,
      'user_id': userId,
      'user_name': userName,
      'user_role': userRole,
      'content': content,
      'attachment': attachment,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Check if this comment is from an agent
  bool get isFromAgent => userRole.toLowerCase() != 'customer';

  /// Check if this comment is from the current user (customer)
  bool get isFromCustomer => userRole.toLowerCase() == 'customer';

  /// Get display name (extract name from email or use full name)
  String get displayName {
    if (userName.contains('@')) {
      return userName.split('@').first;
    }
    return userName;
  }

  /// Get formatted time (e.g., "10:30 AM")
  String get formattedTime {
    final hour = createdAt.hour;
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  /// Get formatted date (e.g., "Jan 6, 2026")
  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }

  /// Get formatted date for grouping (e.g., "JANUARY 6, 2026")
  String get formattedDateGroup {
    const months = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];
    return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }

  @override
  String toString() => 'Comment(id: $id, content: $content)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Comment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Status change event model (for showing status transitions in chat)
class StatusChangeEvent {
  final String fromStatus;
  final String toStatus;
  final DateTime changedAt;

  StatusChangeEvent({
    required this.fromStatus,
    required this.toStatus,
    required this.changedAt,
  });

  /// Get formatted time (e.g., "11:00 AM")
  String get formattedTime {
    final hour = changedAt.hour;
    final minute = changedAt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}

/// Attachment model for files tab
class TicketAttachment {
  final String fileName;
  final String fileUrl;
  final int fileSize;
  final DateTime uploadedAt;
  final String uploadedBy;
  final bool isFromAgent;

  TicketAttachment({
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.uploadedAt,
    required this.uploadedBy,
    this.isFromAgent = false,
  });

  /// Get file extension
  String get extension => fileName.split('.').last.toLowerCase();

  /// Check if file is an image
  bool get isImage =>
      ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);

  /// Check if file is a PDF
  bool get isPdf => extension == 'pdf';

  /// Get formatted file size
  String get formattedSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(0)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Get formatted date (e.g., "Jan 6, 2026")
  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[uploadedAt.month - 1]} ${uploadedAt.day}, ${uploadedAt.year}';
  }

  /// Get formatted time (e.g., "10:30 AM")
  String get formattedTime {
    final hour = uploadedAt.hour;
    final minute = uploadedAt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}

/// Comments response model for pagination
class CommentsResponse {
  final List<Comment> comments;
  final int total;
  final int page;
  final int limit;

  CommentsResponse({
    required this.comments,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory CommentsResponse.fromJson(Map<String, dynamic> json) {
    return CommentsResponse(
      comments: (json['data'] as List<dynamic>?)
              ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['pagination']?['total'] as int? ?? 0,
      page: json['pagination']?['page'] as int? ?? 1,
      limit: json['pagination']?['limit'] as int? ?? 50,
    );
  }

  bool get hasMore => comments.length < total;
}
