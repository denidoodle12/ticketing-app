import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/api_config.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/ticket_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../shared/widgets/section_label.dart';
import '../../../shared/widgets/form_card.dart';
import '../../main/screens/main_screen.dart';
import '../../tickets/widgets/ticket_card.dart';
import '../widgets/ticket_statistics_card.dart';
import '../widgets/ticket_activity_chart.dart';

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
      _loadData();
    });
  }

  Future<void> _loadData() async {
    context.read<TicketProvider>().loadHomeData();
    final profileProvider = context.read<ProfileProvider>();
    await profileProvider.loadProfile();
    if (mounted && profileProvider.user != null) {
      context.read<AuthProvider>().updateCurrentUser(profileProvider.user!);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final ticketProvider = context.watch<TicketProvider>();
    final user = authProvider.currentUser;
    final greeting = _getGreeting();
    final firstName = user?.name ?? 'User';

    return Scaffold(
      backgroundColor: AppColors.white,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildGradientHeader(firstName, greeting),
            ),
            SliverToBoxAdapter(child: _buildContent(ticketProvider)),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientHeader(String firstName, String greeting) {
    final user = context.watch<AuthProvider>().currentUser;
    final profilePictureUrl = user?.profilePicture != null
        ? '${ApiConfig.baseUrl}${user!.profilePicture}'
        : null;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary600, AppColors.primary500],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.white.withAlpha(76),
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: profilePictureUrl != null
                          ? CachedNetworkImage(
                              imageUrl: profilePictureUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  _buildAvatarPlaceholder(firstName),
                              errorWidget: (_, __, ___) =>
                                  _buildAvatarPlaceholder(firstName),
                            )
                          : _buildAvatarPlaceholder(firstName),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Greeting
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, $firstName',
                          style: AppTextStyles.h5.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          greeting,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.white.withAlpha(204),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notification
                  _buildActionButton(
                    icon: Icons.notifications_outlined,
                    onTap: () {
                      // TODO: Navigate to notifications
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Find your IT\nticketing here',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSearchBar(),
            ),

            const SizedBox(height: 24),

            // Curved bottom
            Container(
              height: 24,
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.white.withAlpha(51),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String firstName) {
    return Container(
      color: AppColors.white.withAlpha(51),
      child: Center(
        child: Text(
          firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => context.push('/search'),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 18, right: 10),
              child: Icon(Icons.search, color: AppColors.grey400, size: 22),
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

  Widget _buildContent(TicketProvider ticketProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ticket Statistics
          FormCard(
            padding: const EdgeInsets.all(16),
            child: TicketStatisticsCard(
              statusCounts: ticketProvider.statusCounts,
              isLoading: ticketProvider.isStatsLoading,
            ),
          ),

          const SizedBox(height: 24),

          // Ticket Activity Chart
          FormCard(
            padding: const EdgeInsets.all(16),
            child: const TicketActivityChart(),
          ),

          const SizedBox(height: 28),

          // Quick Action
          const SectionLabel(label: 'Quick Action'),
          const SizedBox(height: 12),
          _buildCreateTicketButton(),

          const SizedBox(height: 28),

          // Recent Tickets
          _buildRecentTicketsSection(ticketProvider),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildCreateTicketButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.primary600, AppColors.primary500],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary500.withAlpha(60),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/tickets/create'),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.white.withAlpha(51),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 18,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Create New Ticket',
                  style: AppTextStyles.button.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTicketsSection(TicketProvider ticketProvider) {
    final recentTickets = ticketProvider.recentTickets;
    final isLoading = ticketProvider.isRecentTicketsLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionLabel(label: 'Recent Tickets'),
            TextButton(
              onPressed: () {
                context.findAncestorStateOfType<MainScreenState>()?.switchToTab(
                  1,
                );
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'View All',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Content
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (recentTickets.isEmpty)
          FormCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: AppColors.textSecondary.withAlpha(128),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No tickets yet',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create a new ticket to get started',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...recentTickets.map(
            (ticket) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TicketCard(
                ticket: ticket,
                onTap: () => context.push('/tickets/detail', extra: ticket),
              ),
            ),
          ),
      ],
    );
  }
}
