import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../tickets/models/ticket_category_model.dart';
import '../../tickets/models/ticket_status_model.dart';

class FilterBottomSheet extends StatefulWidget {
  final List<TicketCategory> categories;
  final List<TicketStatus> statuses;
  final Set<int> selectedCategoryIds;
  final Set<int> selectedStatusIds;
  final Set<String> selectedPriorities;
  final Function(Set<int> categoryIds, Set<int> statusIds, Set<String> priorities) onApply;

  const FilterBottomSheet({
    super.key,
    required this.categories,
    required this.statuses,
    required this.selectedCategoryIds,
    required this.selectedStatusIds,
    required this.selectedPriorities,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late Set<int> _selectedCategoryIds;
  late Set<int> _selectedStatusIds;
  late Set<String> _selectedPriorities;

  // Priority options
  final List<Map<String, String>> _priorityOptions = [
    {'value': 'low', 'label': 'Low'},
    {'value': 'medium', 'label': 'Medium'},
    {'value': 'high', 'label': 'High'},
    {'value': 'critical', 'label': 'Critical'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategoryIds = Set.from(widget.selectedCategoryIds);
    _selectedStatusIds = Set.from(widget.selectedStatusIds);
    _selectedPriorities = Set.from(widget.selectedPriorities);
  }

  void _toggleCategory(int categoryId) {
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });
  }

  void _toggleStatus(int statusId) {
    setState(() {
      if (_selectedStatusIds.contains(statusId)) {
        _selectedStatusIds.remove(statusId);
      } else {
        _selectedStatusIds.add(statusId);
      }
    });
  }

  void _togglePriority(String priority) {
    setState(() {
      if (_selectedPriorities.contains(priority)) {
        _selectedPriorities.remove(priority);
      } else {
        _selectedPriorities.add(priority);
      }
    });
  }

  void _reset() {
    setState(() {
      _selectedCategoryIds.clear();
      _selectedStatusIds.clear();
      _selectedPriorities.clear();
    });
  }

  void _apply() {
    widget.onApply(_selectedCategoryIds, _selectedStatusIds, _selectedPriorities);
    Navigator.pop(context);
  }

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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Results',
                  style: AppTextStyles.h5.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: _reset,
                  child: Text(
                    'Reset',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Category section
          if (widget.categories.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Category',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.categories.map((category) {
                  final isSelected = _selectedCategoryIds.contains(category.id);
                  return _buildChip(
                    label: category.name,
                    isSelected: isSelected,
                    onTap: () => _toggleCategory(category.id),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Status section
          if (widget.statuses.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Status',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.statuses.map((status) {
                  final isSelected = _selectedStatusIds.contains(status.id);
                  return _buildChip(
                    label: status.displayName,
                    isSelected: isSelected,
                    onTap: () => _toggleStatus(status.id),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Priority section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Priority',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _priorityOptions.map((option) {
                final isSelected = _selectedPriorities.contains(option['value']);
                return _buildPriorityChip(
                  label: option['label']!,
                  value: option['value']!,
                  isSelected: isSelected,
                  onTap: () => _togglePriority(option['value']!),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Apply button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Apply Filters',
                    style: AppTextStyles.button.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isSelected ? AppColors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChip({
    required String label,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final priorityColor = _getPriorityColor(value);

    return GestureDetector(
      onTap: onTap,
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
