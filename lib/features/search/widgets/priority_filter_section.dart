import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';

/// Quick-select priority section shown on search screen initial state.
/// Replaces PopularCategoriesSection — uses server-side priority filter.
class PriorityFilterSection extends StatelessWidget {
  final Set<String> selectedPriorities;
  final Function(String priority) onPriorityTap;

  const PriorityFilterSection({
    super.key,
    required this.selectedPriorities,
    required this.onPriorityTap,
  });

  static const List<Map<String, String>> _priorityOptions = [
    {'value': 'low', 'label': 'Low'},
    {'value': 'medium', 'label': 'Medium'},
    {'value': 'high', 'label': 'High'},
    {'value': 'critical', 'label': 'Critical'},
  ];

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'low':
        return AppColors.success500;
      case 'medium':
        return AppColors.warning500;
      case 'high':
        return AppColors.priorityHigh;
      case 'critical':
        return AppColors.error500;
      default:
        return AppColors.grey400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'FILTER BY PRIORITY',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Priority chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _priorityOptions.map((option) {
              final isSelected = selectedPriorities.contains(option['value']);
              return _buildPriorityChip(
                label: option['label']!,
                value: option['value']!,
                isSelected: isSelected,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityChip({
    required String label,
    required String value,
    required bool isSelected,
  }) {
    final priorityColor = _getPriorityColor(value);

    return GestureDetector(
      onTap: () => onPriorityTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? priorityColor.withAlpha(25) : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? priorityColor : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: priorityColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: isSelected ? priorityColor : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
