import 'package:dio/dio.dart';
import '../../../core/constants/api_config.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_interceptor.dart';
import '../models/knowledge_category_model.dart';
import '../models/knowledge_article_model.dart';

/// Remote datasource for Knowledge Base API calls
class KnowledgeRemoteDatasource {
  late final Dio _dio;

  KnowledgeRemoteDatasource() {
    _dio = _createDio();
  }

  Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(
          milliseconds: AppConstants.connectionTimeoutMs,
        ),
        receiveTimeout: const Duration(
          milliseconds: AppConstants.receiveTimeoutMs,
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(ApiInterceptor());
    return dio;
  }

  /// Get all knowledge categories (active only for non-admin)
  Future<List<KnowledgeCategory>> getCategories() async {
    try {
      final response = await _dio.get(ApiEndpoints.knowledgeCategories);
      final data = response.data['data'] as List<dynamic>? ?? [];
      return data
          .map((e) => KnowledgeCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get paginated knowledge articles
  Future<KnowledgeArticleListResponse> getArticles({
    int? categoryId,
    String? search,
    String? sortBy,
    String? order,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (sortBy != null) queryParams['sort_by'] = sortBy;
      if (order != null) queryParams['order'] = order;

      final response = await _dio.get(
        ApiEndpoints.knowledgeArticles,
        queryParameters: queryParams,
      );

      return KnowledgeArticleListResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get a single article by ID
  Future<KnowledgeArticle> getArticleById(int id) async {
    try {
      final response = await _dio.get(ApiEndpoints.knowledgeArticleById(id));
      return KnowledgeArticle.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    final message =
        e.response?.data?['message'] ?? e.message ?? 'Unknown error';
    return Exception(message);
  }
}
