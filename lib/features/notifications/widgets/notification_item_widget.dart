import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../models/notification_model.dart';

/// Widget for displaying a single notification item
/// Shows left accent border only on unread notifications
class NotificationItemWidget extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAsRead;

  const NotificationItemWidget({
    super.key,
    required this.notification,
    this.onTap,
    this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: notification.isRead ? AppColors.white : AppColors.primary50,
          borderRadius: BorderRadius.circular(12),
          border: !notification.isRead
              ? const Border(
                  left: BorderSide(color: AppColors.primaryDark, width: 4),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withAlpha(15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            _buildIcon(),
            const SizedBox(width: 12),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Timestamp row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: notification.isRead
                                ? FontWeight.w600
                                : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(notification.createdAt),
                        style: AppTextStyles.caption.copyWith(
                          color: notification.isRead
                              ? AppColors.textSecondary
                              : AppColors.primaryDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Message
                  Text(
                    notification.message,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    Color backgroundColor;
    Color iconColor;
    IconData iconData;

    switch (notification.type) {
      case NotificationType.statusChange:
        backgroundColor = AppColors.primary100;
        iconColor = AppColors.primary600;
        iconData = Icons.sync;
        break;
      case NotificationType.assignment:
        backgroundColor = AppColors.accent300.withAlpha(50);
        iconColor = AppColors.accent600;
        iconData = Icons.person_add_outlined;
        break;
      case NotificationType.overdue:
        backgroundColor = AppColors.error100;
        iconColor = AppColors.error700;
        iconData = Icons.warning_amber_rounded;
        break;
      case NotificationType.warning:
        backgroundColor = const Color(0xFFFEF3C7);
        iconColor = AppColors.warning700;
        iconData = Icons.access_time;
        break;
      case NotificationType.autoClose:
        backgroundColor = AppColors.secondary100;
        iconColor = AppColors.secondary600;
        iconData = Icons.check_circle_outline;
        break;
      case NotificationType.newComment:
        backgroundColor = AppColors.success100;
        iconColor = AppColors.success700;
        iconData = Icons.chat_bubble_outline;
        break;
      case NotificationType.unknown:
        backgroundColor = AppColors.grey100;
        iconColor = AppColors.grey600;
        iconData = Icons.notifications_outlined;
        break;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Icon(iconData, color: iconColor, size: 22),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final months = [
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
      return '${months[dateTime.month - 1]} ${dateTime.day}';
    }
  }
}
