import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/mixins/offline_aware_mixin.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/asset_paths.dart';
import '../../../shared/widgets/section_label.dart';
import '../../../routes/app_routes.dart';
import '../providers/knowledge_provider.dart';
import '../models/knowledge_article_model.dart';
import '../widgets/knowledge_category_card.dart';
import '../widgets/knowledge_article_card.dart';
import 'knowledge_search_screen.dart';
import 'knowledge_category_screen.dart';
import 'knowledge_all_articles_screen.dart';
import '../../../shared/widgets/empty_state_widget.dart';

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen>
    with OfflineAwareStateMixin<KnowledgeScreen> {
  @override
  void initState() {
    super.initState();
    if (!isOffline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<KnowledgeProvider>().loadInitialData();
        }
      });
    }
  }

  @override
  void onConnectionRestored() {
    if (mounted) {
      context.read<KnowledgeProvider>().loadInitialData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: isOffline
            ? const SizedBox.expand(
                child: Center(
                  child: OfflineStateWidget(
                    title: 'Knowledge Base Unavailable Offline',
                    description:
                        'Please connect to the internet to browse articles and categories.',
                  ),
                ),
              )
            : Consumer<KnowledgeProvider>(
                builder: (context, provider, _) {
                  return RefreshIndicator(
                    onRefresh: provider.refresh,
                    color: AppColors.primary600,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        const SizedBox(height: 32),
                        _buildGreeting(),
                        const SizedBox(height: 16),
                        _buildSearchBar(),
                        const SizedBox(height: 20),
                        _buildAiBanner(),
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
            color: AppColors.textPrimary,
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

  // ─── AI Assistant Banner ──────────────────────────────────────

  Widget _buildAiBanner() {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.aiChat),
      child: Container(
        height: 170, // Increased from 150 to fix overflow
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3B5BDB), // Deeper vibrant blue
              AppColors.primary600,
              AppColors.primary400,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary500.withAlpha(50),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative elements for depth
            Positioned(
              top: -30,
              right: 60,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white.withAlpha(15),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white.withAlpha(10),
                ),
              ),
            ),
            Positioned(
              top: 15,
              left: 45,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white.withAlpha(50),
                ),
              ),
            ),
            Positioned(
              top: 35,
              right: 140,
              child: Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppColors.white.withAlpha(60),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 0, 16),
              child: Row(
                children: [
                  // Left: text + button
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Tagline badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '✨ AI-Powered',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8), // Reduced gap
                        Text(
                          'TixAI Assistant',
                          style: AppTextStyles.h4.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Get instant answers from\nour knowledge base',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.white.withAlpha(200),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10), // Reduced gap
                        // CTA Button
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(10),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Ask Now',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.primary600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: AppColors.primary600,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right: chatbot image (enlarged & cropped)
                  SizedBox(
                    width: 140,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Transform.translate(
                        offset: const Offset(10, 25), // Adjusted offset for larger height
                        child: Image.asset(
                          AssetPaths.chatbot,
                          width: 175, 
                          height: 175,
                          fit: BoxFit.contain,
                          alignment: Alignment.topCenter, 
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.white.withAlpha(30),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.smart_toy_outlined,
                              color: AppColors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Categories Section ────────────────────────────────────────

  Widget _buildCategoriesSection(KnowledgeProvider provider) {
    if (!provider.hasLoadedInitialData || provider.isCategoriesLoading) {
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionLabel(label: 'Recent Articles'),
            GestureDetector(
              onTap: () => _navigateToAllArticles(),
              child: Text(
                'See all →',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!provider.hasLoadedInitialData ||
            (provider.isRecentArticlesLoading && provider.recentArticles.isEmpty))
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
            (article) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: KnowledgeArticleCard(
                article: article,
                onTap: () => _navigateToArticleDetail(article),
              ),
            ),
          ),
      ],
    );
  }

  // _buildArticleCard replaced by KnowledgeArticleCard.

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
    return const Padding(
      padding: EdgeInsets.only(bottom: 40),
      child: Center(
        child: EmptyStateWidget(
          imagePath: 'assets/images/empty-states/empty-five.png',
          title: 'No Articles Available',
          description:
              'Articles will appear here once they are published.',
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

  void _navigateToAllArticles() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<KnowledgeProvider>(),
          child: const KnowledgeAllArticlesScreen(),
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

  // Date formatting handled by [DateFormatter.date].
}
