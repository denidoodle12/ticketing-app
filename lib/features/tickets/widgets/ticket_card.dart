import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../models/ticket_model.dart';

class TicketCard extends StatelessWidget {
  final Ticket ticket;
  final VoidCallback? onTap;

  const TicketCard({super.key, required this.ticket, this.onTap});

  Color _getStatusColor() {
    final statusName =
        ticket.status?.name.toLowerCase().replaceAll('_', ' ') ?? 'open';
    switch (statusName) {
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
    final statusName =
        ticket.status?.name.toLowerCase().replaceAll('_', ' ') ?? 'open';
    switch (statusName) {
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

  String _getStatusDisplayName() {
    final statusName =
        ticket.status?.name.toLowerCase().replaceAll('_', ' ') ?? 'open';
    switch (statusName) {
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
        return ticket.status?.name ?? 'Open';
    }
  }

  Color _getPriorityColor() {
    switch (ticket.priority) {
      case TicketPriority.critical:
        return AppColors.error500;
      case TicketPriority.high:
        return AppColors.priorityHigh;
      case TicketPriority.medium:
        return AppColors.warning500;
      case TicketPriority.low:
        return AppColors.success500;
    }
  }

  String _getPriorityLabel() {
    switch (ticket.priority) {
      case TicketPriority.critical:
        return 'Critical';
      case TicketPriority.high:
        return 'High';
      case TicketPriority.medium:
        return 'Medium';
      case TicketPriority.low:
        return 'Low';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
              // Row 1: Subject and Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      ticket.subject,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusBgColor(),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _getStatusDisplayName(),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: _getStatusColor(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 2: Category and Priority
              Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ticket.category?.name ?? 'Unknown',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _getPriorityColor(),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getPriorityLabel(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: _getPriorityColor(),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 3: Description
              Text(
                ticket.description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Row 4: Time and Attachment
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ticket.timeAgo,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (ticket.attachment != null) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.attach_file_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Attachment',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
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
