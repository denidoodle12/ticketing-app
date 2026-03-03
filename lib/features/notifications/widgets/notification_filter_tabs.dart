import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';

/// Filter type for notification list
enum NotificationFilterType { all, unread }

/// Filter tabs for notification screen
/// Styled to match the tickets screen filter chips
class NotificationFilterTabs extends StatelessWidget {
  final NotificationFilterType selectedFilter;
  final int totalCount;
  final int unreadCount;
  final ValueChanged<NotificationFilterType> onFilterChanged;

  const NotificationFilterTabs({
    super.key,
    required this.selectedFilter,
    required this.totalCount,
    required this.unreadCount,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: 2,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filters = [
            {
              'label': 'All',
              'count': totalCount,
              'type': NotificationFilterType.all,
            },
            {
              'label': 'Unread',
              'count': unreadCount,
              'type': NotificationFilterType.unread,
            },
          ];
          final filter = filters[index];
          return _buildFilterChip(
            label: filter['label'] as String,
            count: filter['count'] as int?,
            type: filter['type'] as NotificationFilterType,
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    int? count,
    required NotificationFilterType type,
  }) {
    final isSelected = selectedFilter == type;
    final displayText = count != null ? '$label ($count)' : label;

    return GestureDetector(
      onTap: () => onFilterChanged(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.grey300,
            width: 1,
          ),
        ),
        child: Text(
          displayText,
          style: AppTextStyles.bodySmall.copyWith(
            color: isSelected ? AppColors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
