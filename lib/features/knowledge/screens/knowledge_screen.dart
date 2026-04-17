import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../shared/widgets/section_label.dart';
import '../providers/knowledge_provider.dart';
import '../widgets/knowledge_category_card.dart';

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KnowledgeProvider>().loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          // ─── Header ──────────────────────────────────────────
          _buildHeader(topPadding),
          // ─── Content ─────────────────────────────────────────
          Expanded(
            child: Consumer<KnowledgeProvider>(
              builder: (context, provider, _) {
                return RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      const SizedBox(height: 24),
                      // Greeting
                      _buildGreeting(),
                      const SizedBox(height: 20),
                      // Search bar
                      _buildSearchBar(provider),
                      const SizedBox(height: 28),
                      // Categories
                      _buildCategoriesSection(provider),
                      const SizedBox(height: 28),
                      // Recent articles
                      _buildRecentArticlesSection(provider),
                      const SizedBox(height: 100),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────

  Widget _buildHeader(double topPadding) {
    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 16,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary600, AppColors.primary500],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Text(
        'Knowledge Hub',
        style: AppTextStyles.h4.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ─── Greeting ──────────────────────────────────────────────────

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How can we help?',
          style: AppTextStyles.h3.copyWith(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Browse categories or search for answers',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ─── Search Bar (same style as Home) ───────────────────────────

  Widget _buildSearchBar(KnowledgeProvider provider) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: provider.searchArticles,
        decoration: InputDecoration(
          hintText: 'Search articles...',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.grey400,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 18, right: 10),
            child: Icon(Icons.search, color: AppColors.grey400, size: 22),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 50,
            minHeight: 22,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.grey400,
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    provider.clearSearch();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
        ),
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  // ─── Categories Section ────────────────────────────────────────

  Widget _buildCategoriesSection(KnowledgeProvider provider) {
    if (provider.isCategoriesLoading) {
      return _buildCategoriesShimmer();
    }

    if (provider.categoriesError != null) {
      return _buildErrorCard(
        'Failed to load categories',
        onRetry: provider.loadCategories,
      );
    }

    final categories = provider.categories;
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    // Show max 4 categories in grid, rest behind "See all"
    final displayCategories = categories.take(4).toList();
    final hasMore = categories.length > 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionLabel(label: 'Categories'),
            if (hasMore)
              GestureDetector(
                onTap: () => _showAllCategories(provider),
                child: Text(
                  'See all ${categories.length} →',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // 2x2 Grid
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: displayCategories.length,
          itemBuilder: (context, index) {
            final category = displayCategories[index];
            final style = CategoryStyle.forCategory(category.name, index);
            return KnowledgeCategoryCard(
              category: category,
              articleCount: 0, // API doesn't return count per category
              iconColor: style.color,
              icon: style.icon,
              onTap: () {
                provider.filterByCategory(category.id);
                _navigateToArticleList(category);
              },
            );
          },
        ),
      ],
    );
  }

  // ─── Recent Articles Section ───────────────────────────────────

  Widget _buildRecentArticlesSection(KnowledgeProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel(label: 'Recent Articles'),
        const SizedBox(height: 12),
        if (provider.isArticlesLoading && provider.articles.isEmpty)
          _buildArticlesShimmer()
        else if (provider.articlesError != null && provider.articles.isEmpty)
          _buildErrorCard(
            'Failed to load articles',
            onRetry: provider.loadArticles,
          )
        else if (provider.articles.isEmpty)
          _buildEmptyState()
        else
          ...provider.articles.take(5).map(
            (article) => _buildArticleCard(article),
          ),
      ],
    );
  }

  // ─── Article Card ──────────────────────────────────────────────

  Widget _buildArticleCard(article) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _navigateToArticleDetail(article),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withAlpha(15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category tag
                      if (article.category != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            article.category!.name,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      // Title
                      Text(
                        article.title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Meta row
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 13,
                            color: AppColors.grey400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${article.readTimeMinutes} min read',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.grey400,
                              fontSize: 11,
                            ),
                          ),
                          if (article.tags.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppColors.grey400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                article.tags.take(2).join(', '),
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.grey400,
                                  fontSize: 11,
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
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.grey400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Shimmer Helpers ───────────────────────────────────────────

  Widget _buildCategoriesShimmer() {
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.secondary100,
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  Widget _buildArticlesShimmer() {
    return Column(
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.secondary100,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }),
    );
  }

  // ─── Error & Empty States ──────────────────────────────────────

  Widget _buildErrorCard(String message, {VoidCallback? onRetry}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.error700,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: AppTextStyles.buttonSmall.copyWith(
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.article_outlined, size: 48, color: AppColors.grey400),
          const SizedBox(height: 12),
          Text(
            'No articles found',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your search or filter',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.grey400,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Navigation ────────────────────────────────────────────────

  void _navigateToArticleDetail(article) {
    context.push('/knowledge/article', extra: article.id);
  }

  void _navigateToArticleList(category) {
    // For now, scroll-to or filter articles on same screen
    // Future: dedicated category article list screen
  }

  void _showAllCategories(KnowledgeProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final categories = provider.categories;
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      'All Categories',
                      style: AppTextStyles.h5.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${categories.length} categories',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Category list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final style = CategoryStyle.forCategory(
                      category.name,
                      index,
                    );
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: style.color.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(style.icon, color: style.color, size: 20),
                      ),
                      title: Text(
                        category.name,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppColors.grey400,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        provider.filterByCategory(category.id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
