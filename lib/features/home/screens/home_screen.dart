import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/datasources/mock/ticket_mock_data.dart';
import '../widgets/statistics_card.dart';
import '../widgets/recent_ticket_item.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final greeting = MockTicketData.getGreeting();
    final date = MockTicketData.getFormattedDate();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary500,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Row(
          children: [
            // App Logo (circle)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.white,
                  width: 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // App Name
            Text(
              AppConstants.appName,
              style: AppTextStyles.h5.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          // Notification Icon
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Navigate to notifications
            },
          ),
          // Profile Avatar
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.white,
              child: Text(
                user?.fullName.substring(0, 1).toUpperCase() ?? 'U',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primary500,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Section
              Text(
                '$greeting, ${user?.fullName ?? 'User'}!',
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Statistics Section
              Text(
                'Ticket Statistics',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Statistics Grid (2x2)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  StatisticsCard(
                    label: 'All Tickets',
                    count: MockTicketData.allTicketsCount,
                    color: AppColors.primary500,
                  ),
                  StatisticsCard(
                    label: 'Open',
                    count: MockTicketData.openCount,
                    color: AppColors.statusOpen,
                  ),
                  StatisticsCard(
                    label: 'In Progress',
                    count: MockTicketData.inProgressCount,
                    color: AppColors.statusInProgress,
                  ),
                  StatisticsCard(
                    label: 'Resolved',
                    count: MockTicketData.resolvedCount,
                    color: AppColors.statusResolved,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quick Actions
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Navigate to create ticket
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Create New Ticket'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Recent Tickets Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Tickets',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: Navigate to all tickets
                    },
                    child: Text(
                      'View All',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primary500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Recent Tickets List
              ...MockTicketData.recentTickets.map((ticket) {
                return RecentTicketItem(
                  ticketId: ticket['id'] as String,
                  title: ticket['title'] as String,
                  status: ticket['status'] as String,
                  timeAgo: ticket['timeAgo'] as String,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
