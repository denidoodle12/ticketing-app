import '../datasources/knowledge_remote_datasource.dart';
import '../models/knowledge_category_model.dart';
import '../models/knowledge_article_model.dart';

/// Repository for knowledge base operations
abstract class KnowledgeRepository {
  /// Get all categories
  Future<List<KnowledgeCategory>> getCategories();

  /// Get paginated articles
  Future<KnowledgeArticleListResponse> getArticles({
    int? categoryId,
    String? search,
    String? tag,
    String? sortBy,
    String? order,
    int page,
    int limit,
  });

  /// Get article by ID
  Future<KnowledgeArticle> getArticleById(int id);
}

/// Implementation of KnowledgeRepository
class KnowledgeRepositoryImpl implements KnowledgeRepository {
  final KnowledgeRemoteDatasource _remoteDatasource;

  KnowledgeRepositoryImpl({KnowledgeRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? KnowledgeRemoteDatasource();

  @override
  Future<List<KnowledgeCategory>> getCategories() async {
    return await _remoteDatasource.getCategories();
  }

  @override
  Future<KnowledgeArticleListResponse> getArticles({
    int? categoryId,
    String? search,
    String? tag,
    String? sortBy,
    String? order,
    int page = 1,
    int limit = 10,
  }) async {
    return await _remoteDatasource.getArticles(
      categoryId: categoryId,
      search: search,
      tag: tag,
      sortBy: sortBy,
      order: order,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<KnowledgeArticle> getArticleById(int id) async {
    return await _remoteDatasource.getArticleById(id);
  }
}
