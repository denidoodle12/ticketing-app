import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/knowledge_article_model.dart';
import '../utils/content_utils.dart';

/// Reusable card for displaying a [KnowledgeArticle] in a list.
///
/// This consolidates the five near-identical `_buildArticleCard`
/// implementations that previously lived in `knowledge_screen`,
/// `knowledge_category_screen`, `knowledge_all_articles_screen`, and
/// `knowledge_search_screen` (the search screen has a slightly different
/// preview source — see [previewOverride]).
///
/// The card shows:
/// - Title (max 2 lines) and an optional category pill
/// - A plain-text preview of the article content (max 2 lines)
/// - Meta row with updated-date and up to two tags
class KnowledgeArticleCard extends StatelessWidget {
  /// Article to render.
  final KnowledgeArticle article;

  /// Optional override for the navigation route. Defaults to
  /// `/knowledge/article` with the article id as `extra`.
  final VoidCallback? onTap;

  /// Optional override for the preview text. Useful for the search
  /// screen which strips the original HTML before highlighting matches.
  /// When `null`, the preview is generated from `article.content` via
  /// [ContentUtils.stripToPlainText].
  final String? previewOverride;

  const KnowledgeArticleCard({
    super.key,
    required this.article,
    this.onTap,
    this.previewOverride,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ??
            () => context.push('/knowledge/article', extra: article.id),
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
                previewOverride ??
                    ContentUtils.stripToPlainText(article.content),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Row 3: Meta info — updated date + first 2 tags
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
}
