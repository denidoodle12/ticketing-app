import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/knowledge_category_model.dart';
import '../models/knowledge_article_model.dart';
import '../providers/knowledge_provider.dart';
import '../utils/content_utils.dart';
import '../../../shared/widgets/empty_state_widget.dart';

/// Screen showing all articles for a specific category
class KnowledgeCategoryScreen extends StatefulWidget {
  final KnowledgeCategory category;

  const KnowledgeCategoryScreen({super.key, required this.category});

  @override
  State<KnowledgeCategoryScreen> createState() =>
      _KnowledgeCategoryScreenState();
}

class _KnowledgeCategoryScreenState extends State<KnowledgeCategoryScreen> {
  final ScrollController _scrollController = ScrollController();

  // ─── Tag filter state (server-side via ?tag= param) ────────────
  String? _selectedTag; // null = no filter

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<KnowledgeProvider>().loadArticles(
          categoryId: widget.category.id,
        );
      });
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final isNowOffline = results.contains(ConnectivityResult.none);
    if (isNowOffline && !_isOffline) {
      if (mounted) setState(() => _isOffline = true);
    } else if (!isNowOffline && _isOffline) {
      if (mounted) {
        setState(() => _isOffline = false);
        // Reload data once back online
        context.read<KnowledgeProvider>().loadArticles(
          categoryId: widget.category.id,
          tag: _selectedTag,
        );
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<KnowledgeProvider>().loadMoreArticles();
    }
  }

  /// Apply tag filter — calls API server-side
  Future<void> _applyTagFilter(String? tag) async {
    setState(() => _selectedTag = tag);
    await context.read<KnowledgeProvider>().loadArticles(
      categoryId: widget.category.id,
      tag: tag,
    );
  }

  /// Reset filter and reload
  Future<void> _resetFilter() async {
    setState(() => _selectedTag = null);
    await context.read<KnowledgeProvider>().loadArticles(
      categoryId: widget.category.id,
    );
  }

  /// Show tag filter bottom sheet (same style as search screen filter)
  void _showTagFilterBottomSheet() {
    final provider = context.read<KnowledgeProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TagFilterBottomSheet(
        // Always use the full tag list collected during the unfiltered load
        availableTags: provider.allCategoryTags,
        selectedTag: _selectedTag,
        onApply: (tag) => _applyTagFilter(tag),
        onReset: _resetFilter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: _buildAppBar(),
      body: _isOffline
          ? const Center(
              child: OfflineStateWidget(
                title: 'Articles Unavailable Offline',
                description:
                    'Please connect to the internet to browse articles in this category.',
              ),
            )
          : Consumer<KnowledgeProvider>(
              builder: (context, provider, _) {
                return _buildContent(provider);
              },
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final hasFilter = _selectedTag != null;

    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 68,
      automaticallyImplyLeading: false,
      leadingWidth: 76,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: _buildActionButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.pop(context),
          ),
        ),
      ),
      centerTitle: true,
      title: Text(
        widget.category.name,
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
              onTap: _showTagFilterBottomSheet,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: hasFilter ? AppColors.primaryDark : AppColors.white,
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
                      color: hasFilter ? AppColors.white : AppColors.primaryDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Filter',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: hasFilter ? AppColors.white : AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hasFilter) ...[
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

  /// Reusable action button — matches ticket detail screen style
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
          child: Icon(icon, color: AppColors.primaryDark, size: 22),
        ),
      ),
    );
  }

  Widget _buildContent(KnowledgeProvider provider) {
    if (provider.isArticlesLoading && provider.articles.isEmpty) {
      return _buildShimmer();
    }

    if (provider.articlesError != null && provider.articles.isEmpty) {
      return _buildErrorState(provider);
    }

    if (provider.articles.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _selectedTag = null);
        await provider.loadArticles(categoryId: widget.category.id);
      },
      color: AppColors.primary600,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: provider.articles.length + (provider.hasMoreArticles ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == provider.articles.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildArticleCard(provider.articles[index]),
          );
        },
      ),
    );
  }

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
              // Row 1: Title and Category badge
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
                ContentUtils.stripToPlainText(article.content),
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
                    'Updated ${DateFormatter.date(article.updatedAt ?? article.createdAt)}',
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
    final isFiltered = _selectedTag != null;

    if (isFiltered) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EmptyStateWidget(
                imagePath: 'assets/images/empty-states/empty-six.png',
                title: 'No Articles Found',
                description:
                    'No articles found with tag "$_selectedTag". Try clearing the filter.',
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
                child: const Text('Clear Filter'),
              ),
            ],
          ),
        ),
      );
    }

    return const Center(
      child: EmptyStateWidget(
        imagePath: 'assets/images/empty-states/empty-five.png',
        title: 'No Articles Yet',
        description:
            'This category doesn\'t have any articles yet. Check back later.',
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
              onPressed: () =>
                  provider.loadArticles(categoryId: widget.category.id),
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

// ─── Tag Filter Bottom Sheet ───────────────────────────────────────────────

class _TagFilterBottomSheet extends StatefulWidget {
  final List<String> availableTags;
  final String? selectedTag;
  final Future<void> Function(String? tag) onApply;
  final Future<void> Function() onReset;

  const _TagFilterBottomSheet({
    required this.availableTags,
    required this.selectedTag,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_TagFilterBottomSheet> createState() => _TagFilterBottomSheetState();
}

class _TagFilterBottomSheetState extends State<_TagFilterBottomSheet> {
  String? _tempSelectedTag;

  @override
  void initState() {
    super.initState();
    _tempSelectedTag = widget.selectedTag;
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

          // Header row: "Filter Articles" + Reset
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter Articles',
                style: AppTextStyles.h5.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Always show Reset (matching search/ticket filter UX)
              GestureDetector(
                onTap: () {
                  setState(() => _tempSelectedTag = null);
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

          // Tags section
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
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No tags available for this category yet.',
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
                final isSelected = _tempSelectedTag == tag;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _tempSelectedTag = isSelected ? null : tag;
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
                await widget.onApply(_tempSelectedTag);
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
    );
  }
}
