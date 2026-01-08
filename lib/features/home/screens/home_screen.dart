import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../datasources/home_mock_data.dart';
import '../widgets/statistics_card.dart';
import '../widgets/recent_ticket_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final greeting = _getGreeting();
    final fullName = user?.fullName ?? 'User';

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Blue Header Section
            _buildBlueHeaderSection(fullName, greeting),

            // Content below the header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // Ticket Status Section
                  _buildTicketStatusSection(),
                  const SizedBox(height: 24),

                  // Quick Action Section
                  _buildQuickActionSection(context),
                  const SizedBox(height: 28),

                  // Recent Tickets Section
                  _buildRecentTicketsSection(context),
                  // Extra padding for bottom navigation bar
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlueHeaderSection(String fullName, String greeting) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              _buildHeader(fullName, greeting),
              const SizedBox(height: 20),

              // Search Bar
              _buildSearchBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String fullName, String greeting) {
    return Row(
      children: [
        // Profile Avatar with white border
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.white.withAlpha(180),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: CircleAvatar(
              backgroundColor: AppColors.white.withAlpha(30),
              child: Text(
                fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Greeting Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting,',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white.withAlpha(200),
                ),
              ),
              Text(
                fullName,
                style: AppTextStyles.h5.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Notification Icon
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.white.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () {
              // TODO: Navigate to notifications
            },
            icon: const Icon(
              Icons.notifications_outlined,
              color: AppColors.white,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search tickets',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textSecondary,
            size: 22,
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
        ),
        onSubmitted: (value) {
          // TODO: Implement search
        },
      ),
    );
  }

  Widget _buildTicketStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ticket Status',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Statistics Grid (2x2)
        Row(
          children: [
            Expanded(
              child: StatisticsCard(
                label: 'ALL TICKET',
                count: HomeMockData.allTicketsCount,
                color: AppColors.textPrimary,
                isHighlighted: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatisticsCard(
                label: 'OPEN',
                count: HomeMockData.openCount,
                color: AppColors.statusOpen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatisticsCard(
                label: 'IN PROGRESS',
                count: HomeMockData.inProgressCount,
                color: AppColors.statusInProgress,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatisticsCard(
                label: 'RESOLVED',
                count: HomeMockData.resolvedCount,
                color: AppColors.statusResolved,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Action',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Create New Ticket Button with gradient
        Container(
          width: double.infinity,
          height: 55,
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // TODO: Navigate to create ticket
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Create New Ticket',
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.white.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 18,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTicketsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Tickets',
              style: AppTextStyles.h5.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                // TODO: Navigate to all tickets
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
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
        const SizedBox(height: 16),

        // Recent Tickets List
        ...HomeMockData.recentTickets.map((ticket) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RecentTicketCard(
              title: ticket['title'] as String,
              status: ticket['status'] as String,
              category: ticket['category'] as String,
              priority: ticket['priority'] as String,
              description: ticket['description'] as String,
              timeAgo: ticket['timeAgo'] as String,
              onTap: () {
                // TODO: Navigate to ticket detail
              },
            ),
          );
        }),
      ],
    );
  }
}
