import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../models/knowledge_category_model.dart';

/// Category card for the 2x2 grid on Knowledge Hub screen.
/// Each card has a color-coded icon circle, category name, and article count.
class KnowledgeCategoryCard extends StatelessWidget {
  final KnowledgeCategory category;
  final int articleCount;
  final Color iconColor;
  final IconData icon;
  final VoidCallback? onTap;

  const KnowledgeCategoryCard({
    super.key,
    required this.category,
    this.articleCount = 0,
    this.iconColor = AppColors.primaryDark,
    this.icon = Icons.folder_outlined,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(height: 12),
              // Category name
              Text(
                category.name,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // Article count
              Text(
                '$articleCount articles',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Default icon and color mapping for categories
class CategoryStyle {
  final IconData icon;
  final Color color;

  const CategoryStyle(this.icon, this.color);

  /// Get style based on category name or index
  static CategoryStyle forCategory(String name, int index) {
    final nameLower = name.toLowerCase();

    if (nameLower.contains('faq')) {
      return const CategoryStyle(Icons.help_outline, AppColors.primaryDark);
    }
    if (nameLower.contains('troubleshoot') || nameLower.contains('problem')) {
      return CategoryStyle(Icons.build_outlined, AppColors.accent700);
    }
    if (nameLower.contains('guide') || nameLower.contains('start')) {
      return const CategoryStyle(Icons.menu_book_outlined, Color(0xFFD97706));
    }
    if (nameLower.contains('account') || nameLower.contains('billing')) {
      return const CategoryStyle(Icons.person_outline, Color(0xFF7C3AED));
    }
    if (nameLower.contains('security') || nameLower.contains('password')) {
      return const CategoryStyle(Icons.shield_outlined, Color(0xFFDC2626));
    }
    if (nameLower.contains('network') || nameLower.contains('vpn')) {
      return CategoryStyle(Icons.wifi_outlined, AppColors.accent500);
    }

    // Fallback colors by index
    const fallbackColors = [
      AppColors.primaryDark,
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFF7C3AED),
      Color(0xFFDC2626),
      Color(0xFF0891B2),
    ];
    const fallbackIcons = [
      Icons.article_outlined,
      Icons.folder_outlined,
      Icons.lightbulb_outline,
      Icons.bookmark_outline,
      Icons.description_outlined,
      Icons.category_outlined,
    ];

    return CategoryStyle(
      fallbackIcons[index % fallbackIcons.length],
      fallbackColors[index % fallbackColors.length],
    );
  }
}
