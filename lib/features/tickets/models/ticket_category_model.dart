class TicketCategory {
  final int id;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TicketCategory({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory TicketCategory.fromJson(Map<String, dynamic> json) {
    return TicketCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
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
      'is_active': isActive,
    };
  }

  @override
  String toString() => 'TicketCategory(id: $id, name: $name)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TicketCategory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
