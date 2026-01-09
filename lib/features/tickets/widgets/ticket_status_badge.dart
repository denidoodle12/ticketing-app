import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';

class TicketStatusBadge extends StatelessWidget {
  final String status;
  final bool compact;

  const TicketStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  Color _getStatusColor() {
    switch (status.toLowerCase().replaceAll('_', ' ')) {
      case 'open':
        return AppColors.statusOpen;
      case 'in progress':
        return AppColors.statusInProgress;
      case 'pending':
        return AppColors.warning700;
      case 'resolved':
        return AppColors.statusResolved;
      case 'closed':
        return AppColors.statusClosed;
      default:
        return AppColors.secondary500;
    }
  }

  Color _getStatusBgColor() {
    switch (status.toLowerCase().replaceAll('_', ' ')) {
      case 'open':
        return AppColors.primary50;
      case 'in progress':
        return const Color(0xFFFEF3C7);
      case 'pending':
        return const Color(0xFFFEF3C7);
      case 'resolved':
        return AppColors.success100;
      case 'closed':
        return AppColors.secondary100;
      default:
        return AppColors.grey100;
    }
  }

  String _getDisplayName() {
    switch (status.toLowerCase().replaceAll('_', ' ')) {
      case 'open':
        return 'Open';
      case 'in progress':
        return 'In Progress';
      case 'pending':
        return 'Pending';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: _getStatusBgColor(),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _getDisplayName(),
        style: AppTextStyles.caption.copyWith(
          color: _getStatusColor(),
          fontWeight: FontWeight.w600,
          fontSize: compact ? 10 : 11,
        ),
      ),
    );
  }
}
