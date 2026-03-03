/// Model for ticket rating data from API
class TicketRating {
  final int id;
  final int ticketId;
  final int agentId;
  final int ratedBy;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  TicketRating({
    required this.id,
    required this.ticketId,
    required this.agentId,
    required this.ratedBy,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory TicketRating.fromJson(Map<String, dynamic> json) {
    return TicketRating(
      id: json['id'] as int? ?? 0,
      ticketId: json['ticket_id'] as int? ?? 0,
      agentId: json['agent_id'] as int? ?? 0,
      ratedBy: json['rated_by'] as int? ?? 0,
      rating: json['rating'] as int? ?? 0,
      comment: json['comment'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticket_id': ticketId,
      'agent_id': agentId,
      'rated_by': ratedBy,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'TicketRating(id: $id, ticketId: $ticketId, rating: $rating)';
}
