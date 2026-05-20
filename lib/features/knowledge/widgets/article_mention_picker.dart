import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../models/knowledge_article_model.dart';
import '../providers/knowledge_provider.dart';

/// Show the @-mention picker bottom sheet for the AI chat input.
///
/// [initialQuery] is the text typed after `@` when the user triggered the
/// picker (without the leading `@`). Empty string means user just typed `@`
/// — we then surface the most recently updated articles.
///
/// When the user taps an article, [onSelected] is invoked synchronously and
/// the sheet pops itself. If the user dismisses the sheet (X button, swipe,
/// or back press), [onSelected] is never called.
///
/// **Search strategy:** the picker fetches up to 100 articles ONCE on open
/// (sorted by recency) and filters by title client-side. This gives instant
/// feedback and avoids hammering the API on every keystroke.
Future<void> showArticleMentionPicker(
  BuildContext context, {
  required String initialQuery,
  required void Function(KnowledgeArticle article) onSelected,
}) async {
  final provider = context.read<KnowledgeProvider>();

  // Fire-and-forget; the sheet listens via Consumer.
  // ignore: unawaited_futures
  provider.loadArticlesForMention();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(100),
    // Sheet shape lives on the Material inside _ArticleMentionPicker so
    // clipBehavior actually clips children. Defining shape here too would
    // create a redundant outline.
    builder: (sheetContext) {
      return ChangeNotifierProvider<KnowledgeProvider>.value(
        value: provider,
        child: _ArticleMentionPicker(
          initialQuery: initialQuery,
          onSelected: (article) {
            onSelected(article);
            Navigator.of(sheetContext).pop();
          },
        ),
      );
    },
  );

  provider.clearMentionResults();
}

class _ArticleMentionPicker extends StatefulWidget {
  final String initialQuery;
  final void Function(KnowledgeArticle article) onSelected;

  const _ArticleMentionPicker({
    required this.initialQuery,
    required this.onSelected,
  });

  @override
  State<_ArticleMentionPicker> createState() => _ArticleMentionPickerState();
}

class _ArticleMentionPickerState extends State<_ArticleMentionPicker> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocus;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _searchFocus = FocusNode();
    // Focus the field after the sheet animates in so the keyboard slides up
    // smoothly instead of fighting the sheet animation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
      // Apply initial query (in case the user had typed something after `@`).
      if (widget.initialQuery.isNotEmpty) {
        context
            .read<KnowledgeProvider>()
            .filterArticlesForMention(widget.initialQuery);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Client-side filter on the already-loaded articles for instant feedback.
    context.read<KnowledgeProvider>().filterArticlesForMention(query);
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<KnowledgeProvider>().filterArticlesForMention('');
    _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    // Use 75% of available height as a comfortable cap. The sheet is
    // scroll-controlled so the keyboard pushes it up naturally.
    final maxHeight = MediaQuery.of(context).size.height * 0.75;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    // Material gives us reliable rounded-corner clipping for ALL child
    // widgets (dividers, InkWell ripples, ListView scroll edges). Using
    // a plain Container.clipBehavior is unreliable for ink effects.
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Material(
        color: AppColors.white,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              _buildHeader(context),
              _buildSearchBar(),
              const Divider(height: 1, color: AppColors.secondary200),
              Flexible(child: _buildResultsList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.grey300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'SELECT ARTICLE',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  /// Mirrors the search-bar styling used across tickets / knowledge screens
  /// (pill shape, radius 30, grey100 background, search icon prefix) so the
  /// experience feels native to the app.
  Widget _buildSearchBar() {
    final hasQuery = _searchController.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(30),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          onChanged: (value) {
            _onSearchChanged(value);
            setState(() {}); // refresh suffix icon visibility
          },
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Search article…',
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.grey400,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
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
            suffixIcon: hasQuery
                ? IconButton(
                    onPressed: _clearSearch,
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.grey400,
                      size: 20,
                    ),
                    tooltip: 'Clear',
                  )
                : null,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    return Consumer<KnowledgeProvider>(
      builder: (context, provider, _) {
        if (provider.isMentionLoading && provider.mentionResults.isEmpty) {
          return _buildShimmer();
        }

        if (provider.mentionResults.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: provider.mentionResults.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            color: AppColors.secondary100,
            indent: 56,
          ),
          itemBuilder: (context, index) {
            final article = provider.mentionResults[index];
            return _MentionListItem(
              article: article,
              onTap: () => widget.onSelected(article),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.neutral100,
      highlightColor: AppColors.white,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 36,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 36,
            color: AppColors.grey400,
          ),
          const SizedBox(height: 10),
          Text(
            'No articles found',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different keyword or close this picker',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.grey400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MentionListItem extends StatelessWidget {
  final KnowledgeArticle article;
  final VoidCallback onTap;

  const _MentionListItem({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final categoryName = article.category?.name ?? '';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.menu_book_outlined,
              color: AppColors.primary500,
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                article.title,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (categoryName.isNotEmpty) ...[
              const SizedBox(width: 12),
              Text(
                categoryName.toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary500,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
