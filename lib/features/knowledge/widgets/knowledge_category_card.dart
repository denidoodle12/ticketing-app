import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../models/knowledge_category_model.dart';

/// Category card for the 2x2 grid on Knowledge Hub screen.
/// Has animated press feedback and shows real article count.
class KnowledgeCategoryCard extends StatefulWidget {
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
  State<KnowledgeCategoryCard> createState() => _KnowledgeCategoryCardState();
}

class _KnowledgeCategoryCardState extends State<KnowledgeCategoryCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.93 : 1.0,
        duration: Duration(milliseconds: _isPressed ? 80 : 300),
        curve: _isPressed ? Curves.easeOut : Curves.elasticOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isPressed
                ? widget.iconColor.withAlpha(12)
                : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withAlpha(_isPressed ? 8 : 15),
                blurRadius: _isPressed ? 4 : 8,
                offset: Offset(0, _isPressed ? 1 : 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon circle
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.iconColor.withAlpha(_isPressed ? 40 : 25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 18),
              ),
              const Spacer(),
              // Category name
              Text(
                widget.category.name,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              // Article count
              Text(
                '${widget.articleCount} articles',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
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
    if (nameLower.contains('test')) {
      return CategoryStyle(Icons.science_outlined, AppColors.accent700);
    }
    if (nameLower.contains('update') || nameLower.contains('release')) {
      return const CategoryStyle(
        Icons.system_update_outlined,
        Color(0xFF059669),
      );
    }
    if (nameLower.contains('non') || nameLower.contains('inactive')) {
      return const CategoryStyle(
        Icons.folder_off_outlined,
        Color(0xFF6B7280),
      );
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
