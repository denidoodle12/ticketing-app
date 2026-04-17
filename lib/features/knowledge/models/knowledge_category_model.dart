/// Knowledge Base category model
class KnowledgeCategory {
  final int id;
  final int tenantId;
  final String name;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const KnowledgeCategory({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory KnowledgeCategory.fromJson(Map<String, dynamic> json) {
    return KnowledgeCategory(
      id: json['id'] as int,
      tenantId: json['tenant_id'] as int? ?? 0,
      name: json['name'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}
