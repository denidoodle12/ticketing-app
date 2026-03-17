import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../models/ticket_model.dart';
import 'ticket_status_badge.dart';

class TicketDetailTab extends StatefulWidget {
  final Ticket ticket;

  const TicketDetailTab({super.key, required this.ticket});

  @override
  State<TicketDetailTab> createState() => _TicketDetailTabState();
}

class _TicketDetailTabState extends State<TicketDetailTab> {
  bool _isDescriptionExpanded = true;

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final localTime = dateTime.toLocal();
    final day = localTime.day.toString().padLeft(2, '0');
    final month = localTime.month.toString().padLeft(2, '0');
    final year = localTime.year;
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    final second = localTime.second.toString().padLeft(2, '0');
    return '$day/$month/$year, $hour:$minute:$second';
  }

  String _formatDateForTimeline(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = localTime.hour;
    final minute = localTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${months[localTime.month - 1]} ${localTime.day}, ${localTime.year} \u2022 $displayHour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const PageStorageKey<String>('details'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description Section
          _buildDescriptionSection(),
          const SizedBox(height: 16),

          // Ticket Information Section
          _buildTicketInfoSection(),
          const SizedBox(height: 16),

          // Status Timeline Section
          _buildStatusTimelineSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    final description = widget.ticket.description;
    final isLongDescription = description.length > 150;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Description',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (isLongDescription)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isDescriptionExpanded = !_isDescriptionExpanded;
                    });
                  },
                  child: Text(
                    _isDescriptionExpanded ? 'Show Less' : 'Show More',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isDescriptionExpanded || !isLongDescription
                ? description
                : '${description.substring(0, 150)}...',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketInfoSection() {
    final assigneeName = widget.ticket.assigneeInfo?.name;
    final agentName = widget.ticket.assignedTo != null
        ? (assigneeName != null && assigneeName.isNotEmpty
            ? assigneeName
            : '')
        : 'Not Assigned Yet';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ticket Information',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Ticket ID
          _buildInfoRow(
            'Ticket ID',
            'TKT-${widget.ticket.id.toString().padLeft(3, '0')}',
          ),
          _buildDivider(),

          // Category
          _buildInfoRow(
            'Category',
            widget.ticket.category?.name ?? 'Uncategorized',
          ),
          _buildDivider(),

          // Priority
          _buildInfoRowWithWidget(
            'Priority',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getPriorityColor(widget.ticket.priority.name),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.ticket.priority.displayName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          _buildDivider(),

          // Status
          _buildInfoRowWithWidget(
            'Status',
            TicketStatusBadge(status: widget.ticket.status?.name ?? 'open'),
          ),
          _buildDivider(),

          // Created By
          _buildInfoRow('Created By', 'You'),
          _buildDivider(),

          // Assigned To
          _buildInfoRow('Assigned To', agentName),
          _buildDivider(),

          // Created Date
          _buildInfoRow(
            'Created Date',
            _formatDateTime(widget.ticket.createdAt),
          ),
          _buildDivider(),

          // Last Updated
          _buildInfoRow(
            'Last Updated',
            _formatDateTime(widget.ticket.updatedAt),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 24, thickness: 1, color: AppColors.grey100);
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRowWithWidget(String label, Widget valueWidget) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        valueWidget,
      ],
    );
  }

  Color _getPriorityColor(String priority) {
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

  Widget _buildStatusTimelineSection() {
    // Build timeline from available ticket data
    final timelineEvents = <Map<String, dynamic>>[];

    final currentStatus = (widget.ticket.status?.name ?? 'open').toLowerCase();

    // Only show status change if current status is different from "open"
    final hasStatusChange =
        currentStatus != 'open' &&
        widget.ticket.updatedAt != null &&
        widget.ticket.createdAt != null;

    if (hasStatusChange) {
      timelineEvents.add({
        'status': widget.ticket.status?.name ?? 'Unknown',
        'date': widget.ticket.updatedAt!,
        'note': 'Status updated',
        'isCurrent': true,
      });
    }

    // Ticket created event (always show)
    timelineEvents.add({
      'status': 'Open',
      'date': widget.ticket.createdAt ?? DateTime.now(),
      'note': 'Ticket created',
      'isCurrent': !hasStatusChange,
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status Timeline',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Timeline items
          ...timelineEvents.asMap().entries.map((entry) {
            final index = entry.key;
            final event = entry.value;
            final isLast = index == timelineEvents.length - 1;

            return _buildTimelineItem(
              status: event['status'] as String,
              date: event['date'] as DateTime,
              note: event['note'] as String,
              isCurrent: event['isCurrent'] as bool,
              isLast: isLast,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String status,
    required DateTime date,
    required String note,
    required bool isCurrent,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCurrent ? AppColors.primaryDark : AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCurrent
                        ? AppColors.primaryDark
                        : AppColors.grey300,
                    width: 2,
                  ),
                ),
                child: isCurrent
                    ? const Icon(Icons.circle, size: 8, color: AppColors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: AppColors.grey200)),
            ],
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDateForTimeline(date),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.grey100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      note,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
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
