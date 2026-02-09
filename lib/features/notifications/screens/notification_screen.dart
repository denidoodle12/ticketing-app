import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/ticket_provider.dart';
import '../../../routes/app_routes.dart';
import '../models/notification_model.dart';
import '../widgets/notification_item_widget.dart';
import '../widgets/notification_filter_tabs.dart';
import 'package:shimmer/shimmer.dart';

/// Screen displaying list of notifications with filters
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  NotificationFilterType _selectedFilter = NotificationFilterType.all;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNotifications();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadNotifications() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().refresh();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<NotificationProvider>().loadMore();
    }
  }

  List<NotificationItem> _getFilteredNotifications(
    NotificationProvider provider,
  ) {
    switch (_selectedFilter) {
      case NotificationFilterType.all:
        return provider.notifications;
      case NotificationFilterType.unread:
        return provider.unreadNotifications;
      case NotificationFilterType.tickets:
        return provider.ticketNotifications;
      case NotificationFilterType.system:
        return provider.systemNotifications;
    }
  }

  Map<String, List<NotificationItem>> _groupByDate(
    List<NotificationItem> notifications,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<NotificationItem>> grouped = {};

    for (final notification in notifications) {
      final notifDate = DateTime(
        notification.createdAt.year,
        notification.createdAt.month,
        notification.createdAt.day,
      );

      String groupKey;
      if (notifDate == today) {
        groupKey = 'TODAY';
      } else if (notifDate == yesterday) {
        groupKey = 'YESTERDAY';
      } else {
        groupKey = '${notifDate.day}/${notifDate.month}/${notifDate.year}';
      }

      grouped.putIfAbsent(groupKey, () => []);
      grouped[groupKey]!.add(notification);
    }

    return grouped;
  }

  Future<void> _handleNotificationTap(NotificationItem notification) async {
    final provider = context.read<NotificationProvider>();

    // Mark as read if unread
    if (!notification.isRead) {
      await provider.markAsRead(notification.id);
    }

    // Navigate to ticket detail if ticket_id exists
    if (notification.ticketId != null && mounted) {
      final ticketProvider = context.read<TicketProvider>();

      // Load ticket detail and navigate
      try {
        await ticketProvider.loadTicketDetail(notification.ticketId!);
        final ticket = ticketProvider.selectedTicket;

        if (ticket != null && mounted) {
          context.push(AppRoutes.ticketDetail, extra: ticket);
        }
      } catch (e) {
        if (mounted) {
          ToastHelper.showError(context, 'Could not load ticket details');
        }
      }
    }
  }

  Future<void> _handleMarkAllAsRead() async {
    final provider = context.read<NotificationProvider>();
    try {
      await provider.markAllAsRead();
      if (mounted) {
        ToastHelper.showSuccess(context, 'All notifications marked as read');
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Failed to mark all as read');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // Filter tabs
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: NotificationFilterTabs(
                  selectedFilter: _selectedFilter,
                  totalCount: provider.notifications.length,
                  unreadCount: provider.unreadCount,
                  onFilterChanged: (filter) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                ),
              ),

              // Notification list
              Expanded(child: _buildNotificationList(provider)),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      automaticallyImplyLeading: false,
      title: Text(
        'Notifications',
        style: AppTextStyles.h4.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            if (provider.unreadCount > 0) {
              return TextButton.icon(
                onPressed: _handleMarkAllAsRead,
                icon: const Icon(
                  Icons.done_all,
                  size: 18,
                  color: AppColors.primary600,
                ),
                label: Text(
                  'Mark All',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildNotificationList(NotificationProvider provider) {
    if (provider.isLoading) {
      return _buildLoadingShimmer();
    }

    if (provider.error != null) {
      return _buildErrorState(provider.error!);
    }

    final filteredNotifications = _getFilteredNotifications(provider);

    if (filteredNotifications.isEmpty) {
      return _buildEmptyState();
    }

    final groupedNotifications = _groupByDate(filteredNotifications);

    return RefreshIndicator(
      onRefresh: provider.refresh,
      color: AppColors.primary600,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount:
            groupedNotifications.length + (provider.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == groupedNotifications.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          final groupKey = groupedNotifications.keys.elementAt(index);
          final notifications = groupedNotifications[groupKey]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 12),
                child: Text(
                  groupKey,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // Notification items
              ...notifications.map(
                (notification) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NotificationItemWidget(
                    notification: notification,
                    onTap: () => _handleNotificationTap(notification),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.grey200,
      highlightColor: AppColors.grey100,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    // Add bottom padding to account for bottom navigation bar height
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 80,
              color: AppColors.grey300,
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: AppTextStyles.h5.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'When you get notifications, they\'ll appear here',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error500),
          const SizedBox(height: 16),
          Text(
            'Failed to load notifications',
            style: AppTextStyles.h5.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary600,
              foregroundColor: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}
