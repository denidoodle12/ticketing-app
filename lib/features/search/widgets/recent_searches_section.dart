import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';

class RecentSearchesSection extends StatelessWidget {
  final List<String> recentSearches;
  final Function(String) onSearchTap;
  final Function(String) onDeleteTap;
  final VoidCallback onClearAll;

  const RecentSearchesSection({
    super.key,
    required this.recentSearches,
    required this.onSearchTap,
    required this.onDeleteTap,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    if (recentSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT SEARCHES',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              GestureDetector(
                onTap: onClearAll,
                child: Text(
                  'Clear All',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Search items
        ...recentSearches.map((search) => _buildSearchItem(search)),
      ],
    );
  }

  Widget _buildSearchItem(String search) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSearchTap(search),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.history,
                size: 20,
                color: AppColors.grey400,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  search,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => onDeleteTap(search),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.grey400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
