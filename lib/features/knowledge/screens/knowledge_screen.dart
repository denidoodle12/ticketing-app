import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../shared/widgets/section_label.dart';
import '../providers/knowledge_provider.dart';
import '../models/knowledge_article_model.dart';
import '../widgets/knowledge_category_card.dart';
import 'knowledge_search_screen.dart';
import 'knowledge_category_screen.dart';

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KnowledgeProvider>().loadInitialData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Consumer<KnowledgeProvider>(
          builder: (context, provider, _) {
            return RefreshIndicator(
              onRefresh: provider.refresh,
              color: AppColors.primary600,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 20),
                  _buildGreeting(),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  const SizedBox(height: 24),
                  _buildCategoriesSection(provider),
                  const SizedBox(height: 24),
                  _buildRecentArticlesSection(provider),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
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
          style: AppTextStyles.h4.copyWith(
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

  // ─── Search Bar (GestureDetector — same as Home) ───────────────

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: context.read<KnowledgeProvider>(),
              child: const KnowledgeSearchScreen(),
            ),
          ),
        );
      },
      child: Container(
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
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 18, right: 10),
              child: Icon(Icons.search, color: AppColors.grey400, size: 22),
            ),
            Expanded(
              child: Text(
                'Search articles...',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.grey400,
                ),
              ),
            ),
          ],
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
    if (categories.isEmpty) return const SizedBox.shrink();

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
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: displayCategories.length,
          itemBuilder: (context, index) {
            final category = displayCategories[index];
            final style = CategoryStyle.forCategory(category.name, index);
            final count = provider.articleCountPerCategory[category.id] ?? 0;
            return KnowledgeCategoryCard(
              category: category,
              articleCount: count,
              iconColor: style.color,
              icon: style.icon,
              onTap: () => _navigateToCategoryScreen(category),
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
        if (provider.isRecentArticlesLoading && provider.recentArticles.isEmpty)
          _buildArticlesShimmer()
        else if (provider.recentArticlesError != null &&
            provider.recentArticles.isEmpty)
          _buildErrorCard(
            'Failed to load articles',
            onRetry: provider.loadRecentArticles,
          )
        else if (provider.recentArticles.isEmpty)
          _buildEmptyState()
        else
          ...provider.recentArticles.map(
            (article) => _buildArticleCard(article),
          ),
      ],
    );
  }

  // ─── Article Card (TicketCard-style) ───────────────────────────

  Widget _buildArticleCard(KnowledgeArticle article) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToArticleDetail(article),
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
                  article.content,
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
                      Icons.access_time_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${article.readTimeMinutes} min read',
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
        childAspectRatio: 1.5,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppColors.secondary100,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildArticlesShimmer() {
    return Column(
      children: List.generate(3, (_) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.secondary100,
              borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error700),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Icon(
              Icons.article_outlined,
              size: 64,
              color: AppColors.textSecondary.withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              'No articles yet',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Navigation ────────────────────────────────────────────────

  void _navigateToArticleDetail(KnowledgeArticle article) {
    context.push('/knowledge/article', extra: article.id);
  }

  void _navigateToCategoryScreen(category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<KnowledgeProvider>(),
          child: KnowledgeCategoryScreen(category: category),
        ),
      ),
    );
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
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
                    final count =
                        provider.articleCountPerCategory[category.id] ?? 0;
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
                      subtitle: Text(
                        '$count articles',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppColors.grey400,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _navigateToCategoryScreen(category);
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
