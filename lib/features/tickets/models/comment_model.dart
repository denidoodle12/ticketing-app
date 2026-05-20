import '../../../core/utils/date_formatter.dart';

/// Comment/Chat message model for ticket conversations
class Comment {
  final int id;
  final int ticketId;
  final int userId;
  final String userName;
  final String? firstname;
  final String? profilePicture;
  final String userRole;
  final String content;
  final String? attachment;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.ticketId,
    required this.userId,
    required this.userName,
    this.firstname,
    this.profilePicture,
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
      firstname: json['firstname'] as String?,
      profilePicture: json['profile_picture'] as String?,
      userRole: json['user_role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
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
      'firstname': firstname,
      'profile_picture': profilePicture,
      'user_role': userRole,
      'content': content,
      'attachment': attachment,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Check if this comment is from an agent
  bool get isFromAgent => userRole.toLowerCase() != 'user';

  /// Check if this comment is from the current user
  bool get isFromUser => userRole.toLowerCase() == 'user';

  /// Get display name
  /// For agent/admin/superadmin: "firstname.role" format
  /// For user: firstname or extracted from email
  String get displayName {
    // For non-user (agent/admin/superadmin), show "firstname.role" format
    if (!isFromUser && firstname != null && firstname!.isNotEmpty) {
      return '$firstname - $userRole';
    }

    // For user or if firstname is not available, use firstname or extract from email
    if (firstname != null && firstname!.isNotEmpty) {
      return firstname!;
    }

    if (userName.contains('@')) {
      return userName.split('@').first;
    }
    return userName;
  }

  /// Get formatted time (e.g., "10:30 AM") in local timezone
  String get formattedTime => DateFormatter.time(createdAt);

  /// Get formatted date (e.g., "May 20, 2026") in local timezone
  String get formattedDate => DateFormatter.date(createdAt);

  /// Get formatted date for grouping (e.g., "JANUARY 6, 2026") in local timezone
  String get formattedDateGroup {
    final localTime = createdAt.toLocal();
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    return '${months[localTime.month - 1]} ${localTime.day}, ${localTime.year}';
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

  /// Get formatted date (e.g., "May 20, 2026") in local timezone
  String get formattedDate => DateFormatter.date(uploadedAt);

  /// Get formatted time (e.g., "10:30 AM") in local timezone
  String get formattedTime => DateFormatter.time(uploadedAt);
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
      comments:
          (json['data'] as List<dynamic>?)
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
