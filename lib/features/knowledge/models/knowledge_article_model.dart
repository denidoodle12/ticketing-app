import 'knowledge_category_model.dart';

/// Knowledge Base article model
class KnowledgeArticle {
  final int id;
  final int tenantId;
  final int categoryId;
  final KnowledgeCategory? category;
  final String title;
  final String content;
  final List<String> tags;
  final String visibility;
  final String status;
  final int createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const KnowledgeArticle({
    required this.id,
    required this.tenantId,
    required this.categoryId,
    this.category,
    required this.title,
    required this.content,
    this.tags = const [],
    this.visibility = 'all',
    this.status = 'published',
    this.createdBy = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory KnowledgeArticle.fromJson(Map<String, dynamic> json) {
    return KnowledgeArticle(
      id: json['id'] as int,
      tenantId: json['tenant_id'] as int? ?? 0,
      categoryId: json['category_id'] as int,
      category: json['category'] != null
          ? KnowledgeCategory.fromJson(
              json['category'] as Map<String, dynamic>,
            )
          : null,
      title: json['title'] as String,
      content: json['content'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      visibility: json['visibility'] as String? ?? 'all',
      status: json['status'] as String? ?? 'published',
      createdBy: json['created_by'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}

/// Response wrapper for paginated article list
class KnowledgeArticleListResponse {
  final List<KnowledgeArticle> articles;
  final int total;
  final int page;
  final int limit;

  const KnowledgeArticleListResponse({
    required this.articles,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory KnowledgeArticleListResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? [];
    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};

    return KnowledgeArticleListResponse(
      articles: data
          .map((e) => KnowledgeArticle.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: pagination['total'] as int? ?? 0,
      page: pagination['page'] as int? ?? 1,
      limit: pagination['limit'] as int? ?? 10,
    );
  }

  bool get hasMore => page * limit < total;
}
