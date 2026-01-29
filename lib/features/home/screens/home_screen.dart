import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/ticket_provider.dart';
import '../../main/screens/main_screen.dart';
import '../../tickets/widgets/ticket_card.dart';
import '../widgets/ticket_statistics_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TicketProvider>().loadHomeData();
    });
  }

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
    final ticketProvider = context.watch<TicketProvider>();
    final user = authProvider.currentUser;
    final greeting = _getGreeting();
    final fullName = user?.fullName ?? 'User';

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: RefreshIndicator(
        onRefresh: () => ticketProvider.loadHomeData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Blue Header Section
              _buildBlueHeaderSection(fullName, greeting),

              // Content below the header with white background and top border radius
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      // Ticket Statistics Section
                      _buildTicketStatisticsSection(ticketProvider),
                      const SizedBox(height: 24),

                      // Quick Action Section
                      _buildQuickActionSection(context),
                      const SizedBox(height: 28),

                      // Recent Tickets Section
                      _buildRecentTicketsSection(context, ticketProvider),
                      // Extra padding for bottom navigation bar
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlueHeaderSection(String fullName, String greeting) {
    return Container(
      color: AppColors.primaryDark,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with avatar and greeting
              _buildHeader(fullName, greeting),
              const SizedBox(height: 20),

              // Title
              Text(
                'Find your IT\nticketing here',
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 20),

              // Search Bar with Filter
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
          width: 48,
          height: 48,
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
                style: AppTextStyles.h5.copyWith(
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
                'Hi, $fullName',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                greeting,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.white.withAlpha(180),
                ),
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
    // Search Input - pill shaped white background (tap to open search screen)
    return GestureDetector(
      onTap: () {
        context.push('/search');
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Icon(
                Icons.search,
                color: AppColors.grey400,
                size: 22,
              ),
            ),
            Expanded(
              child: Text(
                'Search tickets...',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.grey400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketStatisticsSection(TicketProvider ticketProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ticket Statistics',
          style: AppTextStyles.h6.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TicketStatisticsCard(
          statusCounts: ticketProvider.statusCounts,
          priorityCounts: ticketProvider.priorityCounts,
          categoryCounts: ticketProvider.categoryCounts,
          isLoading: ticketProvider.isStatsLoading,
          showHeader: false,
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
          style: AppTextStyles.h6.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Create New Ticket Button
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
                context.push('/tickets/create');
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

  Widget _buildRecentTicketsSection(
    BuildContext context,
    TicketProvider ticketProvider,
  ) {
    final recentTickets = ticketProvider.recentTickets;
    final isLoading = ticketProvider.isRecentTicketsLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Tickets',
              style: AppTextStyles.h6.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                // Switch to Tickets tab (index 1)
                context
                    .findAncestorStateOfType<MainScreenState>()
                    ?.switchToTab(1);
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
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (recentTickets.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No tickets yet',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...recentTickets.map((ticket) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TicketCard(
                ticket: ticket,
                onTap: () {
                  context.push('/tickets/detail', extra: ticket);
                },
              ),
            );
          }),
      ],
    );
  }
}
