class TicketStatus {
  final int id;
  final String name;
  final String? description;
  final bool isFinal;
  final int displayOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TicketStatus({
    required this.id,
    required this.name,
    this.description,
    required this.isFinal,
    required this.displayOrder,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory TicketStatus.fromJson(Map<String, dynamic> json) {
    return TicketStatus(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      isFinal: json['is_final'] as bool? ?? false,
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
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
      'name': name,
      'description': description,
      'is_final': isFinal,
      'display_order': displayOrder,
      'is_active': isActive,
    };
  }

  /// Get display name (capitalize first letter of each word)
  String get displayName {
    return name
        .split('_')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');
  }

  @override
  String toString() => 'TicketStatus(id: $id, name: $name)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TicketStatus && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
