import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/mixins/offline_aware_mixin.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../widgets/knowledge_article_card.dart';
import '../models/knowledge_category_model.dart';
import '../providers/knowledge_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/circle_icon_button.dart';

/// Screen that shows ALL knowledge articles (no category filter).
/// Triggered from the "See all" link in the Recent Articles section.
class KnowledgeAllArticlesScreen extends StatefulWidget {
  const KnowledgeAllArticlesScreen({super.key});

  @override
  State<KnowledgeAllArticlesScreen> createState() =>
      _KnowledgeAllArticlesScreenState();
}

class _KnowledgeAllArticlesScreenState
    extends State<KnowledgeAllArticlesScreen>
    with OfflineAwareStateMixin<KnowledgeAllArticlesScreen> {
  final ScrollController _scrollController = ScrollController();

  // ─── Active filter state ────────────────────────────────────────
  int? _selectedCategoryId;
  String? _selectedCategoryName; // for display only
  String? _selectedTag;

  bool get _hasActiveFilter => _selectedCategoryId != null || _selectedTag != null;

  // (offline state handled by OfflineAwareStateMixin)

  @override
  void initState() {
    super.initState();
    if (!isOffline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<KnowledgeProvider>().loadArticles();
        }
      });
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void onConnectionRestored() {
    if (!mounted) return;
    context.read<KnowledgeProvider>().loadArticles(
      categoryId: _selectedCategoryId,
      tag: _selectedTag,
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<KnowledgeProvider>().loadMoreArticles();
    }
  }

  /// Apply filter — calls API server-side
  Future<void> _applyFilter({int? categoryId, String? categoryName, String? tag}) async {
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedCategoryName = categoryName;
      _selectedTag = tag;
    });
    await context.read<KnowledgeProvider>().loadArticles(
      categoryId: categoryId,
      tag: tag,
    );
  }

  Future<void> _resetFilter() async {
    setState(() {
      _selectedCategoryId = null;
      _selectedCategoryName = null;
      _selectedTag = null;
    });
    await context.read<KnowledgeProvider>().loadArticles();
  }

  void _showFilterBottomSheet() {
    final provider = context.read<KnowledgeProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ArticleFilterBottomSheet(
        categories: provider.categories,
        availableTags: provider.allArticlesTags,
        selectedCategoryId: _selectedCategoryId,
        selectedTag: _selectedTag,
        onApply: (categoryId, categoryName, tag) =>
            _applyFilter(categoryId: categoryId, categoryName: categoryName, tag: tag),
        onReset: _resetFilter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: _buildAppBar(),
      body: isOffline
          ? const Center(
              child: OfflineStateWidget(
                title: 'Articles Unavailable Offline',
                description:
                    'Please connect to the internet to browse all articles.',
              ),
            )
          : Consumer<KnowledgeProvider>(
              builder: (context, provider, _) => _buildContent(provider),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 68,
      automaticallyImplyLeading: false,
      leadingWidth: 76,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(child: CircleIconButton.back(context)),
      ),
      centerTitle: true,
      title: Text(
        'All Articles',
        style: AppTextStyles.h5.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: GestureDetector(
              onTap: _showFilterBottomSheet,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: _hasActiveFilter ? AppColors.primaryDark : AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow.withAlpha(20),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: _hasActiveFilter
                          ? AppColors.white
                          : AppColors.primaryDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Filter',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: _hasActiveFilter
                            ? AppColors.white
                            : AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_hasActiveFilter) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // _buildBackButton replaced by CircleIconButton.back(context).

  Widget _buildContent(KnowledgeProvider provider) {
    if (provider.isInitialArticlesLoad) {
      return _buildShimmer();
    }

    if (provider.articlesError != null && provider.articles.isEmpty) {
      return _buildErrorState(provider);
    }

    if (provider.articles.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Active filter chips row (shown only when filter is active)
        if (_hasActiveFilter) _buildActiveFilterRow(),

        // Article list
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _selectedCategoryId = null;
                _selectedCategoryName = null;
                _selectedTag = null;
              });
              await provider.loadArticles();
            },
            color: AppColors.primary600,
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount:
                  provider.articles.length + (provider.hasMoreArticles ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == provider.articles.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return KnowledgeArticleCard(article: provider.articles[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Row of small chips showing active filters, each tappable to remove
  Widget _buildActiveFilterRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          if (_selectedCategoryId != null)
            _buildActiveChip(
              label: _selectedCategoryName ?? 'Category',
              onRemove: () => _applyFilter(tag: _selectedTag),
            ),
          if (_selectedTag != null)
            _buildActiveChip(
              label: _selectedTag!,
              onRemove: () => _applyFilter(
                categoryId: _selectedCategoryId,
                categoryName: _selectedCategoryName,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveChip({required String label, required VoidCallback onRemove}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary100, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  // _buildArticleCard replaced by KnowledgeArticleCard.

  Widget _buildShimmer() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.secondary100,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _hasActiveFilter;

    if (isFiltered) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const EmptyStateWidget(
                imagePath: 'assets/images/empty-states/empty-six.png',
                title: 'No Articles Found',
                description:
                    'No articles match the selected filters. Try clearing them.',
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _resetFilter,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: BorderSide(color: AppColors.primaryDark, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Clear Filters'),
              ),
            ],
          ),
        ),
      );
    }

    return const Center(
      child: EmptyStateWidget(
        imagePath: 'assets/images/empty-states/empty-five.png',
        title: 'No Articles Available',
        description: 'There are no published articles available.',
      ),
    );
  }

  Widget _buildErrorState(KnowledgeProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error500.withAlpha(150),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load articles',
              style: AppTextStyles.h5.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => provider.loadArticles(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // Date formatting handled by [DateFormatter.date].
}

// ─── Article Filter Bottom Sheet ──────────────────────────────────────────────

class _ArticleFilterBottomSheet extends StatefulWidget {
  final List<KnowledgeCategory> categories;
  final List<String> availableTags;
  final int? selectedCategoryId;
  final String? selectedTag;
  final Future<void> Function(int? categoryId, String? categoryName, String? tag) onApply;
  final Future<void> Function() onReset;

  const _ArticleFilterBottomSheet({
    required this.categories,
    required this.availableTags,
    required this.selectedCategoryId,
    required this.selectedTag,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_ArticleFilterBottomSheet> createState() =>
      _ArticleFilterBottomSheetState();
}

class _ArticleFilterBottomSheetState extends State<_ArticleFilterBottomSheet> {
  int? _tempCategoryId;
  String? _tempCategoryName;
  String? _tempTag;


  @override
  void initState() {
    super.initState();
    _tempCategoryId = widget.selectedCategoryId;
    _tempTag = widget.selectedTag;
    // Restore category name from the categories list
    if (_tempCategoryId != null) {
      final match = widget.categories
          .where((c) => c.id == _tempCategoryId)
          .toList();
      _tempCategoryName = match.isNotEmpty ? match.first.name : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: 20 + bottomPadding,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header row: "Filter Results" + Reset
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Results',
                  style: AppTextStyles.h5.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Always visible Reset (same as search screen)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _tempCategoryId = null;
                      _tempCategoryName = null;
                      _tempTag = null;
                    });
                  },
                  child: Text(
                    'Reset',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Category Section ──────────────────────────────────────
            Text(
              'Category',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            if (widget.categories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'No categories available.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.categories.map((category) {
                  final isSelected = _tempCategoryId == category.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _tempCategoryId = null;
                          _tempCategoryName = null;
                        } else {
                          _tempCategoryId = category.id;
                          _tempCategoryName = category.name;
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
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
                              : AppColors.grey200,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        category.name,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isSelected
                              ? AppColors.white
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 20),

            // ── Tags Section ──────────────────────────────────────────
            Text(
              'Tags',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            if (widget.availableTags.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'No tags available yet.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.availableTags.map((tag) {
                  final isSelected = _tempTag == tag;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _tempTag = isSelected ? null : tag;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
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
                              : AppColors.grey200,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isSelected
                              ? AppColors.white
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 28),

            // Apply button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await widget.onApply(
                    _tempCategoryId,
                    _tempCategoryName,
                    _tempTag,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Apply Filters',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
