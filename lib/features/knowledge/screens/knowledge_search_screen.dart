import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../providers/knowledge_provider.dart';
import '../models/knowledge_article_model.dart';
import '../models/knowledge_category_model.dart';
import '../utils/content_utils.dart';
import '../widgets/article_card_shimmer.dart';
import '../widgets/knowledge_category_card.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../search/services/recent_search_service.dart';
import '../../search/widgets/recent_searches_section.dart';

enum _ArticleSearchState { initial, searching, results, empty }

/// Knowledge search screen — visually & behaviorally consistent with the
/// existing ticket [SearchScreen]. Supports recent searches, category filter,
/// search tips, results header with filter button, and unified empty/loading
/// states.
class KnowledgeSearchScreen extends StatefulWidget {
  const KnowledgeSearchScreen({super.key});

  @override
  State<KnowledgeSearchScreen> createState() => _KnowledgeSearchScreenState();
}

class _KnowledgeSearchScreenState extends State<KnowledgeSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final RecentSearchService _recentSearchService = RecentSearchService(
    storageKey: StorageKeys.recentArticleSearches,
  );
  Timer? _debounceTimer;

  // State
  _ArticleSearchState _screenState = _ArticleSearchState.initial;
  List<String> _recentSearches = [];
  List<KnowledgeArticle> _results = [];
  int _totalResults = 0;
  String _lastSearchedQuery = '';

  // Single-select category filter
  int? _selectedCategoryId;
  String? _selectedCategoryName;

  // ─── Offline detection ─────────────────────────────────────────
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _isOffline = !ConnectivityService().isConnected;
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChange,
    );

    if (!_isOffline) {
      _loadInitialData();
    }

    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final isNowOffline = results.contains(ConnectivityResult.none);
    if (isNowOffline && !_isOffline) {
      if (mounted) setState(() => _isOffline = true);
    } else if (!isNowOffline && _isOffline) {
      if (mounted) {
        setState(() => _isOffline = false);
        _loadInitialData();
      }
    }
  }

  Future<void> _loadInitialData() async {
    await _loadRecentSearches();
    if (!mounted) return;
    final provider = context.read<KnowledgeProvider>();
    if (provider.categories.isEmpty) {
      provider.loadCategories();
    }
  }

  Future<void> _loadRecentSearches() async {
    final searches = await _recentSearchService.getRecentSearches();
    if (mounted) {
      setState(() => _recentSearches = searches);
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    // Reset filter when typing a new search
    if (_selectedCategoryId != null) {
      setState(() {
        _selectedCategoryId = null;
        _selectedCategoryName = null;
      });
    }

    if (query.trim().isEmpty) {
      setState(() {
        _screenState = _ArticleSearchState.initial;
        _results = [];
        _totalResults = 0;
        _lastSearchedQuery = '';
      });
      return;
    }

    if (_lastSearchedQuery != query.trim()) {
      setState(() => _screenState = _ArticleSearchState.searching);
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    if (trimmed == _lastSearchedQuery &&
        _screenState == _ArticleSearchState.results) {
      return;
    }

    setState(() => _screenState = _ArticleSearchState.searching);

    await _recentSearchService.addRecentSearch(trimmed);
    await _loadRecentSearches();

    if (!mounted) return;

    try {
      final provider = context.read<KnowledgeProvider>();
      await provider.loadArticles(
        categoryId: _selectedCategoryId,
        search: trimmed,
      );

      if (mounted) {
        _lastSearchedQuery = trimmed;
        setState(() {
          _results = provider.articles;
          _totalResults = provider.totalArticles;
          _screenState = provider.articles.isEmpty
              ? _ArticleSearchState.empty
              : _ArticleSearchState.results;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _screenState = _ArticleSearchState.empty;
          _results = [];
          _totalResults = 0;
        });
      }
    }
  }

  Future<void> _performFilterSearch() async {
    setState(() => _screenState = _ArticleSearchState.searching);
    if (!mounted) return;

    try {
      final provider = context.read<KnowledgeProvider>();
      final searchQuery = _searchController.text.trim();
      await provider.loadArticles(
        categoryId: _selectedCategoryId,
        search: searchQuery.isNotEmpty ? searchQuery : null,
      );

      if (mounted) {
        setState(() {
          _results = provider.articles;
          _totalResults = provider.totalArticles;
          _screenState = provider.articles.isEmpty
              ? _ArticleSearchState.empty
              : _ArticleSearchState.results;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _screenState = _ArticleSearchState.empty;
          _results = [];
          _totalResults = 0;
        });
      }
    }
  }

  void _onRecentSearchTap(String search) {
    _searchController.text = search;
    _performSearch(search);
  }

  Future<void> _onDeleteRecentSearch(String search) async {
    await _recentSearchService.removeRecentSearch(search);
    await _loadRecentSearches();
  }

  Future<void> _onClearAllRecentSearches() async {
    await _recentSearchService.clearAllRecentSearches();
    await _loadRecentSearches();
  }

  void _onCategoryTap(KnowledgeCategory category) {
    setState(() {
      // Single-select toggle
      if (_selectedCategoryId == category.id) {
        _selectedCategoryId = null;
        _selectedCategoryName = null;
      } else {
        _selectedCategoryId = category.id;
        _selectedCategoryName = category.name;
      }
    });
    _performFilterSearch();
  }

  void _showFilterBottomSheet() {
    final provider = context.read<KnowledgeProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategoryFilterBottomSheet(
        categories: provider.categories,
        selectedCategoryId: _selectedCategoryId,
        onApply: (categoryId, categoryName) {
          setState(() {
            _selectedCategoryId = categoryId;
            _selectedCategoryName = categoryName;
          });
          _performFilterSearch();
        },
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _screenState = _ArticleSearchState.initial;
      _results = [];
      _totalResults = 0;
    });
    _focusNode.requestFocus();
  }

  void _tryAnotherSearch() {
    _searchController.clear();
    setState(() {
      _screenState = _ArticleSearchState.initial;
      _selectedCategoryId = null;
      _selectedCategoryName = null;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchHeader(),
            Expanded(
              child: _isOffline
                  ? const Center(
                      child: OfflineStateWidget(
                        title: 'Search Unavailable Offline',
                        description:
                            'Please connect to the internet to search articles.',
                      ),
                    )
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Search Header ────────────────────────────────────────────

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildBackButton(),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search articles...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.grey400,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 16, right: 8),
                    child: Icon(
                      Icons.search,
                      color: AppColors.grey400,
                      size: 22,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 46,
                    minHeight: 46,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: _clearSearch,
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.grey400,
                            size: 20,
                          ),
                        )
                      : null,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 14,
                  ),
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _focusNode.unfocus(),
                textInputAction: TextInputAction.done,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.pop(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back,
            color: AppColors.primaryDark,
            size: 22,
          ),
        ),
      ),
    );
  }

  // ─── Content router ───────────────────────────────────────────

  Widget _buildContent() {
    switch (_screenState) {
      case _ArticleSearchState.initial:
        return _buildInitialContent();
      case _ArticleSearchState.searching:
        return _buildSearchingContent();
      case _ArticleSearchState.results:
        return _buildResultsContent();
      case _ArticleSearchState.empty:
        return _buildEmptyContent();
    }
  }

  // ─── Initial state ────────────────────────────────────────────

  Widget _buildInitialContent() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent searches
          RecentSearchesSection(
            recentSearches: _recentSearches,
            onSearchTap: _onRecentSearchTap,
            onDeleteTap: _onDeleteRecentSearch,
            onClearAll: _onClearAllRecentSearches,
          ),

          if (_recentSearches.isNotEmpty) const SizedBox(height: 24),

          // Filter by category — same chip style as search ticket
          _buildCategoryFilterSection(),

          const SizedBox(height: 24),

          // Search tips card
          _buildSearchTipsCard(),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterSection() {
    return Consumer<KnowledgeProvider>(
      builder: (context, provider, _) {
        final categories = provider.categories;
        if (categories.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'FILTER BY CATEGORY',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.take(8).map((cat) {
                  final isSelected = _selectedCategoryId == cat.id;
                  final style = CategoryStyle.forCategory(cat.name, 0);
                  return GestureDetector(
                    onTap: () => _onCategoryTap(cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? style.color.withAlpha(25)
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? style.color : AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            style.icon,
                            size: 14,
                            color: isSelected
                                ? style.color
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat.name,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isSelected
                                  ? style.color
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchTipsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: AppColors.warning500,
              ),
              const SizedBox(width: 8),
              Text(
                'Search Tips',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTipItem('Search articles by title or content'),
          const SizedBox(height: 6),
          _buildTipItem('Use specific keywords for better results'),
          const SizedBox(height: 6),
          _buildTipItem('Filter by category to narrow your search'),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 7),
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: AppColors.textSecondary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Searching state ──────────────────────────────────────────

  Widget _buildSearchingContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Searching...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary500,
              ),
            ),
          ),
          const ArticleCardShimmerList(itemCount: 3),
        ],
      ),
    );
  }

  // ─── Results state ────────────────────────────────────────────

  Widget _buildResultsContent() {
    final hasActiveFilters = _selectedCategoryId != null;

    return Column(
      children: [
        // Results header — matches ticket search style
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Found $_totalResults '
                'article${_totalResults != 1 ? 's' : ''}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              GestureDetector(
                onTap: _showFilterBottomSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: hasActiveFilters
                        ? AppColors.primaryDark
                        : AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasActiveFilters
                          ? AppColors.primaryDark
                          : AppColors.border,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune,
                        size: 18,
                        color: hasActiveFilters
                            ? AppColors.white
                            : AppColors.textPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Filter',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: hasActiveFilters
                              ? AppColors.white
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Active filter chip
        if (_selectedCategoryName != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary100, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedCategoryName!,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = null;
                          _selectedCategoryName = null;
                        });
                        _performFilterSearch();
                      },
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Results list
        Expanded(
          child: ListView.separated(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: _results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _buildArticleCard(_results[index]),
          ),
        ),
      ],
    );
  }

  // ─── Empty state ──────────────────────────────────────────────

  Widget _buildEmptyContent() {
    final hasActiveFilters = _selectedCategoryId != null;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          EmptyStateWidget(
            imagePath: 'assets/images/empty-states/empty-six.png',
            title: hasActiveFilters
                ? 'No Matching Articles'
                : 'No Results Found',
            description: hasActiveFilters
                ? 'No articles match your current filter. Try adjusting it.'
                : 'Try a different keyword or check the spelling.',
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _tryAnotherSearch,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              side: const BorderSide(color: AppColors.primaryDark, width: 1.5),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Try Another Search',
              style: AppTextStyles.buttonSmall.copyWith(
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Article Card ─────────────────────────────────────────────

  Widget _buildArticleCard(KnowledgeArticle article) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/knowledge/article', extra: article.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withAlpha(15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Title + Category badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      article.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (article.category != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        article.category!.name,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Row 2: Content preview
              Text(
                article.content.isNotEmpty
                    ? ContentUtils.stripToPlainText(article.content)
                    : 'No content available',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Row 3: Meta info
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Updated ${_formatDate(article.updatedAt ?? article.createdAt ?? DateTime.now())}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (article.tags.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.label_outline,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        article.tags.take(2).join(', '),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ─── Category Filter Bottom Sheet ───────────────────────────────────────────

class _CategoryFilterBottomSheet extends StatefulWidget {
  final List<KnowledgeCategory> categories;
  final int? selectedCategoryId;
  final void Function(int? categoryId, String? categoryName) onApply;

  const _CategoryFilterBottomSheet({
    required this.categories,
    required this.selectedCategoryId,
    required this.onApply,
  });

  @override
  State<_CategoryFilterBottomSheet> createState() =>
      _CategoryFilterBottomSheetState();
}

class _CategoryFilterBottomSheetState
    extends State<_CategoryFilterBottomSheet> {
  int? _tempCategoryId;
  String? _tempCategoryName;

  @override
  void initState() {
    super.initState();
    _tempCategoryId = widget.selectedCategoryId;
    if (_tempCategoryId != null) {
      final match = widget.categories
          .where((c) => c.id == _tempCategoryId)
          .toList();
      _tempCategoryName = match.isNotEmpty ? match.first.name : null;
    }
  }

  void _toggle(KnowledgeCategory category) {
    setState(() {
      if (_tempCategoryId == category.id) {
        _tempCategoryId = null;
        _tempCategoryName = null;
      } else {
        _tempCategoryId = category.id;
        _tempCategoryName = category.name;
      }
    });
  }

  void _reset() {
    setState(() {
      _tempCategoryId = null;
      _tempCategoryName = null;
    });
  }

  void _apply() {
    widget.onApply(_tempCategoryId, _tempCategoryName);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Results',
                  style: AppTextStyles.h5.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: _reset,
                  child: Text(
                    'Reset',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Category section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Category',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (widget.categories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'No categories available.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.categories.map((cat) {
                  final isSelected = _tempCategoryId == cat.id;
                  return GestureDetector(
                    onTap: () => _toggle(cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryDark
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryDark
                              : AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        cat.name,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isSelected
                              ? AppColors.white
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 24),

          // Apply button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Apply Filters',
                    style: AppTextStyles.button.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
