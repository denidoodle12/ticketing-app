import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/knowledge_category_model.dart';
import '../models/knowledge_article_model.dart';
import '../models/ai_chat_model.dart';
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

  // ─── Selected Tag Filter ─────────────────────────────────────────
  String? _selectedTag;
  String? get selectedTag => _selectedTag;

  // All unique tags from an unfiltered category load (used by filter sheet)
  List<String> _allCategoryTags = [];
  List<String> get allCategoryTags => _allCategoryTags;

  // All unique tags from an unfiltered global load (used by All Articles filter sheet)
  List<String> _allArticlesTags = [];
  List<String> get allArticlesTags => _allArticlesTags;

  // ─── Initial Load Tracking ────────────────────────────────────
  bool _hasLoadedInitialData = false;
  bool get hasLoadedInitialData => _hasLoadedInitialData;

  // ─── AI Chat ──────────────────────────────────────────────────────
  List<AiChatMessage> _chatMessages = [];
  List<AiChatMessage> get chatMessages => _chatMessages;
  bool _isAiResponding = false;
  bool get isAiResponding => _isAiResponding;
  String? _aiError;
  String? get aiError => _aiError;

  /// Whether the chat has any messages (used to show welcome vs chat view)
  bool get hasChatHistory => _chatMessages.isNotEmpty;

  // ─── Mention Picker (AI Chat input) ──────────────────────────────
  // State is isolated from the main `_articles` list so opening the
  // picker never disturbs the knowledge screens.
  //
  // Strategy: fetch up to 100 articles ONCE when the picker opens, then
  // filter by title client-side as the user types. This gives instant
  // feedback and avoids hammering the API on every keystroke. For tenants
  // with > 100 articles we'd need to revisit, but the typical KB size is
  // well under that.
  List<KnowledgeArticle> _mentionAllArticles = [];
  List<KnowledgeArticle> _mentionResults = [];
  List<KnowledgeArticle> get mentionResults => _mentionResults;
  bool _isMentionLoading = false;
  bool get isMentionLoading => _isMentionLoading;

  /// Dynamic suggested questions generated from loaded categories & articles
  List<String> get suggestedQuestions {
    final questions = <String>[];

    // Generate from categories
    if (_categories.isNotEmpty) {
      for (final cat in _categories.take(2)) {
        questions.add('What articles are available about ${cat.name}?');
      }
    }

    // Generate from recent articles
    if (_recentArticles.isNotEmpty) {
      for (final article in _recentArticles.take(2)) {
        questions.add('Explain about "${article.title}"');
      }
    }

    // Fallbacks if not enough dynamic questions
    final fallbacks = [
      'How to create a new ticket?',
      'How to reset my password?',
      'What ticket categories are available?',
      'How to use the knowledge base?',
    ];

    // Fill up to 4 questions
    for (final fb in fallbacks) {
      if (questions.length >= 4) break;
      if (!questions.contains(fb)) questions.add(fb);
    }

    return questions.take(4).toList();
  }

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
  Future<void> loadArticles({int? categoryId, String? search, String? tag}) async {
    if (_isArticlesLoading) return;
    _isArticlesLoading = true;
    _articlesError = null;
    _currentPage = 1;
    _selectedCategoryId = categoryId;
    _selectedTag = tag;
    _searchQuery = search ?? '';
    _articles = [];
    _totalArticles = 0;
    notifyListeners();

    try {
      final response = await _repository.getArticles(
        categoryId: _selectedCategoryId,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        tag: _selectedTag,
        sortBy: 'updated_at',
        order: 'DESC',
        page: 1,
        limit: 10,
      );
      _articles = response.articles;
      _totalArticles = response.total;

      // Only refresh the full tag list when loading without a tag filter
      // so the bottom sheet always shows all available tags for this category
      if (tag == null) {
        final freshTags = _articles
            .expand((a) => a.tags)
            .toSet()
            .toList()
          ..sort();

        if (categoryId != null) {
          // Category-scoped load → update category tags list only
          _allCategoryTags = freshTags;
        } else {
          // Global load (no category) → update global tags list
          _allArticlesTags = freshTags;
        }
      }
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
        tag: _selectedTag,
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

  // ═══════════════════════════════════════════════════════════════════
  // AI Chat Actions
  // ═══════════════════════════════════════════════════════════════════

  /// Send a message to the AI Assistant
  /// Pattern: append user msg → append loading placeholder → call API → replace
  ///
  /// [mentions] — articles the user picked via @-mention. Stored on the
  /// user message for UI chips. The current backend contract
  /// (`POST /knowledge/ask`) only accepts `{question}`, so mentions are
  /// not sent over the wire — the AI's pgvector semantic search picks up
  /// the article titles from the question text itself.
  Future<void> sendMessage(
    String question, {
    List<MentionedArticle> mentions = const [],
  }) async {
    if (_isAiResponding || question.trim().isEmpty) return;

    _isAiResponding = true;
    _aiError = null;

    // 1. Append user message (with mentions if any)
    _chatMessages = [
      ..._chatMessages,
      AiChatMessage.user(question.trim(), mentionedArticles: mentions),
    ];
    // 2. Append loading placeholder
    _chatMessages = [..._chatMessages, AiChatMessage.loading()];
    notifyListeners();

    try {
      final response = await _repository.askAi(question.trim());
      // 3. Replace loading placeholder with actual response
      _chatMessages = [
        ..._chatMessages.sublist(0, _chatMessages.length - 1),
        AiChatMessage.fromResponse(response),
      ];
    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      // 3. Replace loading placeholder with error
      _chatMessages = [
        ..._chatMessages.sublist(0, _chatMessages.length - 1),
        AiChatMessage.error(errorMsg),
      ];
      _aiError = errorMsg;
    } finally {
      _isAiResponding = false;
      notifyListeners();
    }
  }

  /// Retry the last failed message
  void retryLastMessage() {
    if (_chatMessages.length < 2) return;
    // Find the last user message (should be second-to-last)
    final lastUserMsg = _chatMessages[_chatMessages.length - 2];
    if (lastUserMsg.role != ChatRole.user) return;

    // Remove the error message
    _chatMessages = _chatMessages.sublist(0, _chatMessages.length - 1);
    notifyListeners();

    // Resend, preserving the original mentions
    sendMessage(
      lastUserMsg.content,
      mentions: lastUserMsg.mentionedArticles,
    );
  }

  /// Clear chat history (reset to welcome state)
  void clearChat() {
    _chatMessages = [];
    _aiError = null;
    _isAiResponding = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════
  // Mention Picker Actions (AI Chat @-mention)
  // ═══════════════════════════════════════════════════════════════════

  /// Load articles for the picker. Fetches once per picker open; subsequent
  /// filter calls are handled client-side in [filterArticlesForMention].
  Future<void> loadArticlesForMention() async {
    // Already populated for this picker session — no-op.
    if (_mentionAllArticles.isNotEmpty) return;

    _isMentionLoading = true;
    notifyListeners();
    try {
      final response = await _repository.getArticles(
        sortBy: 'updated_at',
        order: 'DESC',
        page: 1,
        limit: 100,
      );
      _mentionAllArticles = response.articles;
      _mentionResults = response.articles;
    } catch (_) {
      _mentionAllArticles = [];
      _mentionResults = [];
    } finally {
      _isMentionLoading = false;
      notifyListeners();
    }
  }

  /// Filter the already-loaded mention articles by title (case-insensitive).
  /// Runs entirely on-device for instant feedback.
  void filterArticlesForMention(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      _mentionResults = _mentionAllArticles;
    } else {
      _mentionResults = _mentionAllArticles
          .where((a) => a.title.toLowerCase().contains(q))
          .toList();
    }
    notifyListeners();
  }

  /// Reset mention picker state when sheet is dismissed.
  void clearMentionResults() {
    _mentionAllArticles = [];
    _mentionResults = [];
    _isMentionLoading = false;
    // No notify — sheet is already closing.
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}

