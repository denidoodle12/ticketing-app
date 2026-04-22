import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/knowledge_category_model.dart';
import '../models/knowledge_article_model.dart';
import '../repositories/knowledge_repository.dart';

/// Provider for Knowledge Base state management
class KnowledgeProvider extends ChangeNotifier {
  final KnowledgeRepository _repository;

  KnowledgeProvider({KnowledgeRepository? repository})
    : _repository = repository ?? KnowledgeRepositoryImpl();

  // ─── Categories ──────────────────────────────────────────────────
  List<KnowledgeCategory> _categories = [];
  List<KnowledgeCategory> get categories => _categories;
  bool _isCategoriesLoading = false;
  bool get isCategoriesLoading => _isCategoriesLoading;
  String? _categoriesError;
  String? get categoriesError => _categoriesError;

  // ─── Article Count Per Category ──────────────────────────────────
  Map<int, int> _articleCountPerCategory = {};
  Map<int, int> get articleCountPerCategory => _articleCountPerCategory;

  // ─── Recent Articles (Home screen section) ───────────────────────
  List<KnowledgeArticle> _recentArticles = [];
  List<KnowledgeArticle> get recentArticles => _recentArticles;
  bool _isRecentArticlesLoading = false;
  bool get isRecentArticlesLoading => _isRecentArticlesLoading;
  String? _recentArticlesError;
  String? get recentArticlesError => _recentArticlesError;

  // ─── Articles (category detail / search) ────────────────────────
  List<KnowledgeArticle> _articles = [];
  List<KnowledgeArticle> get articles => _articles;
  bool _isArticlesLoading = false;
  bool get isArticlesLoading => _isArticlesLoading;
  String? _articlesError;
  String? get articlesError => _articlesError;
  int _currentPage = 1;
  int _totalArticles = 0;
  int get totalArticles => _totalArticles;
  bool get hasMoreArticles => _articles.length < _totalArticles;

  // ─── Article Detail ──────────────────────────────────────────────
  KnowledgeArticle? _selectedArticle;
  KnowledgeArticle? get selectedArticle => _selectedArticle;
  bool _isArticleLoading = false;
  bool get isArticleLoading => _isArticleLoading;
  String? _articleError;
  String? get articleError => _articleError;

  // ─── Search ──────────────────────────────────────────────────────
  String _searchQuery = '';
  String get searchQuery => _searchQuery;
  Timer? _searchDebounce;

  // ─── Selected Category Filter ────────────────────────────────────
  int? _selectedCategoryId;
  int? get selectedCategoryId => _selectedCategoryId;

  // ─── Initial Load Tracking ────────────────────────────────────
  bool _hasLoadedInitialData = false;
  bool get hasLoadedInitialData => _hasLoadedInitialData;

  // ═══════════════════════════════════════════════════════════════════
  // Actions
  // ═══════════════════════════════════════════════════════════════════

  /// Load categories
  Future<void> loadCategories() async {
    if (_isCategoriesLoading) return;
    _isCategoriesLoading = true;
    _categoriesError = null;
    notifyListeners();

    try {
      _categories = await _repository.getCategories();
      // After loading categories, fetch article counts
      await _loadArticleCountsForCategories();
    } catch (e) {
      _categoriesError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isCategoriesLoading = false;
      notifyListeners();
    }
  }

  /// Fetch article count for each category using pagination total
  Future<void> _loadArticleCountsForCategories() async {
    final counts = <int, int>{};
    // Run all requests in parallel
    await Future.wait(
      _categories.map((category) async {
        try {
          final response = await _repository.getArticles(
            categoryId: category.id,
            page: 1,
            limit: 1, // We only need the total count from pagination
          );
          counts[category.id] = response.total;
        } catch (_) {
          counts[category.id] = 0;
        }
      }),
    );
    _articleCountPerCategory = counts;
  }

  /// Load 5 most recently updated articles (for home section)
  Future<void> loadRecentArticles() async {
    if (_isRecentArticlesLoading) return;
    _isRecentArticlesLoading = true;
    _recentArticlesError = null;
    notifyListeners();

    try {
      final response = await _repository.getArticles(
        sortBy: 'updated_at',
        order: 'DESC',
        page: 1,
        limit: 5,
      );
      _recentArticles = response.articles;
    } catch (e) {
      _recentArticlesError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isRecentArticlesLoading = false;
      notifyListeners();
    }
  }

  /// Load articles for a specific category (first page)
  Future<void> loadArticles({int? categoryId, String? search}) async {
    if (_isArticlesLoading) return;
    _isArticlesLoading = true;
    _articlesError = null;
    _currentPage = 1;
    _selectedCategoryId = categoryId;
    _searchQuery = search ?? '';
    _articles = [];
    _totalArticles = 0;
    notifyListeners();

    try {
      final response = await _repository.getArticles(
        categoryId: _selectedCategoryId,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        sortBy: 'updated_at',
        order: 'DESC',
        page: 1,
        limit: 10,
      );
      _articles = response.articles;
      _totalArticles = response.total;
    } catch (e) {
      _articlesError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isArticlesLoading = false;
      notifyListeners();
    }
  }

  /// Load more articles (pagination)
  Future<void> loadMoreArticles() async {
    if (_isArticlesLoading || !hasMoreArticles) return;
    _isArticlesLoading = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final response = await _repository.getArticles(
        categoryId: _selectedCategoryId,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        sortBy: 'updated_at',
        order: 'DESC',
        page: nextPage,
        limit: 10,
      );
      _articles.addAll(response.articles);
      _totalArticles = response.total;
      _currentPage = nextPage;
    } catch (e) {
      _articlesError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isArticlesLoading = false;
      notifyListeners();
    }
  }

  /// Load article detail
  Future<void> loadArticleDetail(int id) async {
    _isArticleLoading = true;
    _articleError = null;
    _selectedArticle = null;
    notifyListeners();

    try {
      _selectedArticle = await _repository.getArticleById(id);
    } catch (e) {
      _articleError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isArticleLoading = false;
      notifyListeners();
    }
  }

  /// Search articles with debounce
  void searchArticles(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _searchQuery = query;
      loadArticles(categoryId: _selectedCategoryId, search: query);
    });
  }

  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    _searchDebounce?.cancel();
    loadArticles(categoryId: _selectedCategoryId);
  }

  /// Filter by category (used internally — navigates to category screen instead)
  void filterByCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    loadArticles(categoryId: categoryId);
  }

  /// Load initial data (categories + recent articles in parallel)
  Future<void> loadInitialData() async {
    _hasLoadedInitialData = true;
    await Future.wait([
      loadCategories(),
      loadRecentArticles(),
    ]);
  }

  /// Refresh all data
  Future<void> refresh() async {
    _searchQuery = '';
    _selectedCategoryId = null;
    await loadInitialData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
