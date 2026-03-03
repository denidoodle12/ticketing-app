import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';

class SearchResultsHeader extends StatelessWidget {
  final int count;
  final bool hasActiveFilters;
  final VoidCallback onFilterTap;

  const SearchResultsHeader({
    super.key,
    required this.count,
    required this.hasActiveFilters,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Found $count ticket${count != 1 ? 's' : ''}',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          GestureDetector(
            onTap: onFilterTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: hasActiveFilters
                    ? AppColors.primaryDark
                    : AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasActiveFilters
                      ? AppColors.primaryDark
                      : AppColors.border,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune,
                    size: 18,
                    color: hasActiveFilters
                        ? AppColors.white
                        : AppColors.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filter',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: hasActiveFilters
                          ? AppColors.white
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
