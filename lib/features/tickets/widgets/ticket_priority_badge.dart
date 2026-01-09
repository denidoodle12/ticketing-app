import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../models/ticket_model.dart';

class TicketPriorityBadge extends StatelessWidget {
  final String priority;
  final bool showLabel;
  final bool compact;

  const TicketPriorityBadge({
    super.key,
    required this.priority,
    this.showLabel = true,
    this.compact = false,
  });

  factory TicketPriorityBadge.fromEnum(
    TicketPriority priority, {
    bool showLabel = true,
    bool compact = false,
  }) {
    return TicketPriorityBadge(
      priority: priority.name,
      showLabel: showLabel,
      compact: compact,
    );
  }

  Color _getPriorityColor() {
    switch (priority.toLowerCase()) {
      case 'critical':
        return AppColors.error500;
      case 'high':
        return AppColors.priorityHigh;
      case 'medium':
        return AppColors.warning500;
      case 'low':
        return AppColors.success500;
      default:
        return AppColors.secondary500;
    }
  }

  Color _getPriorityBgColor() {
    switch (priority.toLowerCase()) {
      case 'critical':
        return AppColors.error100;
      case 'high':
        return const Color(0xFFFED7AA);
      case 'medium':
        return const Color(0xFFFEF3C7);
      case 'low':
        return AppColors.success100;
      default:
        return AppColors.grey100;
    }
  }

  String _getPriorityLabel() {
    switch (priority.toLowerCase()) {
      case 'critical':
        return 'Critical';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return priority;
    }
  }

  IconData _getPriorityIcon() {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Icons.priority_high;
      case 'high':
        return Icons.arrow_upward;
      case 'medium':
        return Icons.remove;
      case 'low':
        return Icons.arrow_downward;
      default:
        return Icons.remove;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!showLabel) {
      // Dot only
      return Container(
        width: compact ? 6 : 8,
        height: compact ? 6 : 8,
        decoration: BoxDecoration(
          color: _getPriorityColor(),
          shape: BoxShape.circle,
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: _getPriorityBgColor(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getPriorityIcon(),
            size: compact ? 10 : 12,
            color: _getPriorityColor(),
          ),
          const SizedBox(width: 4),
          Text(
            _getPriorityLabel(),
            style: AppTextStyles.caption.copyWith(
              color: _getPriorityColor(),
              fontWeight: FontWeight.w600,
              fontSize: compact ? 10 : 11,
            ),
          ),
        ],
      ),
    );
  }
}
