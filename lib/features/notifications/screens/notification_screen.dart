import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/mixins/offline_aware_mixin.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/ticket_provider.dart';
import '../../../routes/app_routes.dart';
import '../models/notification_model.dart';
import '../widgets/notification_item_widget.dart';
import 'package:shimmer/shimmer.dart';
import '../../../shared/widgets/empty_state_widget.dart';

/// Screen displaying list of notifications with filters
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin,
        OfflineAwareStateMixin<NotificationScreen> {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);

    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

  /// Load notifications — skips API call if offline.
  ///
  /// Deferred to post-frame because [refresh] synchronously calls
  /// `notifyListeners()` (via `_isLoading = true`), and triggering that
  /// during initState/build raises a "setState during build" assertion.
  void _loadNotifications() {
    if (isOffline) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationProvider>().refresh();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<NotificationProvider>().loadMore();
    }
  }

  @override
  void onConnectionRestored() {
    if (mounted) {
      context.read<NotificationProvider>().refresh();
    }
  }

  List<NotificationItem> _getFilteredNotifications(
    NotificationProvider provider,
  ) {
    if (_tabController.index == 1) {
      return provider.unreadNotifications;
    }
    return provider.notifications;
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

    // Navigate to ticket detail first if ticket_id exists
    if (notification.ticketId != null && mounted) {
      final ticketProvider = context.read<TicketProvider>();

      try {
        await ticketProvider.loadTicketDetail(notification.ticketId!);
        final ticket = ticketProvider.selectedTicket;

        if (ticket != null && mounted) {
          // Navigate immediately
          context.push(AppRoutes.ticketDetail, extra: ticket);

          // Mark as read in background while user is on detail screen
          // When user returns, the card will already be in read state
          if (!notification.isRead) {
            provider.markAsRead(notification.id);
          }
        }
      } catch (e) {
        if (mounted) {
          ToastHelper.showError(context, 'Could not load ticket details');
        }
      }
    } else {
      // No ticket_id — just mark as read
      if (!notification.isRead) {
        provider.markAsRead(notification.id);
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
      backgroundColor: AppColors.white,
      appBar: _buildAppBar(),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          // Always show offline placeholder when device is offline
          // (notifications are not cached locally)
          if (isOffline) {
            return _buildOfflinePlaceholder();
          }

          return Column(
            children: [
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
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: Text(
        'Notifications',
        style: AppTextStyles.h5.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            if (provider.unreadCount > 0) {
              return TextButton(
                onPressed: _handleMarkAllAsRead,
                child: Text(
                  'Read All',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryDark,
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
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primaryDark,
                  indicatorWeight: 3,
                  labelColor: AppColors.primaryDark,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: AppTextStyles.bodyMedium,
                  dividerColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  tabs: [
                    const Tab(text: 'All'),
                    Tab(text: 'Unread (${provider.unreadCount})'),
                  ],
                ),
                // Bottom shadow divider (same as ticket detail)
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withAlpha(15), Colors.transparent],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationList(NotificationProvider provider) {
    // Show offline placeholder immediately (before loading check)
    if (isOffline) {
      return _buildOfflinePlaceholder();
    }

    if (provider.isInitialLoad) {
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
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
                padding: const EdgeInsets.only(top: 20, bottom: 12),
                child: Text(
                  groupKey,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.grey600,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // Notification items
              ...notifications.map(
                (notification) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
    return const Center(
      child: EmptyStateWidget(
        imagePath: 'assets/images/empty-states/empty-seven.png',
        title: 'No Notifications Yet',
        description:
            'You\'ll be notified here when there are updates on your tickets.',
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.error500.withAlpha(150),
          ),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadNotifications,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflinePlaceholder() {
    return const SizedBox.expand(
      child: Center(
        child: OfflineStateWidget(
          title: 'Notifications Unavailable Offline',
          description:
              'Please connect to the internet to view your notifications.',
        ),
      ),
    );
  }
}
