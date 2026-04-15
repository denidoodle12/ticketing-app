import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/api_config.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/ticket_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../shared/widgets/section_label.dart';
import '../../../shared/widgets/form_card.dart';
import '../../tickets/widgets/ticket_card.dart';
import '../widgets/ticket_statistics_card.dart';
import '../widgets/ticket_activity_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Counter to force rebuild TicketActivityChart when coming back online
  int _chartRebuildKey = 0;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();

    // Listen to connectivity changes for real-time sync
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChange,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    context.read<TicketProvider>().loadHomeData();
    final profileProvider = context.read<ProfileProvider>();
    await profileProvider.loadProfile();
    if (mounted && profileProvider.user != null) {
      context.read<AuthProvider>().updateCurrentUser(profileProvider.user!);
    }
  }

  /// Handle connectivity changes in real-time
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final isNowOffline = results.contains(ConnectivityResult.none);

    if (isNowOffline) {
      _wasOffline = true;
    } else if (!isNowOffline && _wasOffline) {
      // Just came back online — refresh all home data
      _wasOffline = false;
      if (mounted) {
        _loadData();
        // Force rebuild TicketActivityChart by changing its key
        setState(() => _chartRebuildKey++);
      }
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
    final profilePictureUrl = user?.profilePicture != null
        ? '${ApiConfig.baseUrl}${user!.profilePicture}'
        : null;
    final topPadding = MediaQuery.of(context).padding.top;

    // Heights for SliverAppBar
    // Collapsed: status bar + search bar + padding
    const collapsedSearchBarHeight = 52.0;
    const collapsedVerticalPadding = 12.0;
    const curvedBottomHeight = 24.0;
    final collapsedHeight =
        topPadding + collapsedSearchBarHeight + collapsedVerticalPadding * 2 + curvedBottomHeight;
    // Expanded: full header with avatar, greeting, title, search, curved bottom
    // topPad(16) + avatar row(68) + spacer(24) + title(64) + spacer(20) + search(52) + spacer(24) + curve(24)
    final expandedHeight = topPadding + 16 + 68 + 24 + 64 + 20 + 52 + 24 + 24;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: RefreshIndicator(
        onRefresh: _loadData,
        edgeOffset: collapsedHeight,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _HomeHeaderDelegate(
                firstName: firstName,
                greeting: greeting,
                profilePictureUrl: profilePictureUrl,
                topPadding: topPadding,
                expandedHeight: expandedHeight.toDouble(),
                collapsedHeight: collapsedHeight,
                onSearchTap: () => context.push('/search'),
              ),
            ),
            SliverToBoxAdapter(child: _buildContent(ticketProvider)),
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
            child: TicketActivityChart(key: ValueKey(_chartRebuildKey)),
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
        const SectionLabel(label: 'Recent Tickets'),
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

// ===========================================================================
// SliverPersistentHeaderDelegate — controls the collapsing header behavior
// ===========================================================================

class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String firstName;
  final String greeting;
  final String? profilePictureUrl;
  final double topPadding;
  final double expandedHeight;
  final double collapsedHeight;
  final VoidCallback onSearchTap;

  _HomeHeaderDelegate({
    required this.firstName,
    required this.greeting,
    required this.profilePictureUrl,
    required this.topPadding,
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.onSearchTap,
  });

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => collapsedHeight;

  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate oldDelegate) {
    return firstName != oldDelegate.firstName ||
        greeting != oldDelegate.greeting ||
        profilePictureUrl != oldDelegate.profilePictureUrl;
  }

  // Positions (relative to topPadding)
  // Expanded positions
  double get _avatarRowTop => 16.0;
  double get _titleTop => _avatarRowTop + 68 + 24; // after avatar row + spacer
  double get _searchExpandedTop =>
      _titleTop + 64 + 20; // after title + spacer
  // Collapsed position
  double get _searchCollapsedTop => 12.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // 0.0 = fully expanded, 1.0 = fully collapsed
    final double t =
        (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    // Eased curves for smoother feel
    final avatarFade = Curves.easeOut.transform((t * 2.5).clamp(0.0, 1.0));
    final titleFade = Curves.easeOut.transform(((t - 0.1) * 2.5).clamp(0.0, 1.0));
    final searchT = Curves.easeInOut.transform(t);

    // Parallax offsets — elements slide UP faster than scroll
    final avatarSlide = avatarFade * 30.0;
    final titleSlide = titleFade * 20.0;

    // Search bar: interpolate between expanded and collapsed Y position
    final searchTop = topPadding +
        _lerpDouble(_searchExpandedTop, _searchCollapsedTop, searchT);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary600, AppColors.primary500],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ═══════════════════════════════════════════════════
          // AVATAR ROW — slides up fast with parallax + fades
          // ═══════════════════════════════════════════════════
          if (avatarFade < 1.0)
            Positioned(
              top: topPadding + _avatarRowTop - avatarSlide,
              left: 20,
              right: 20,
              child: Opacity(
                opacity: (1.0 - avatarFade).clamp(0.0, 1.0),
                child: _buildAvatarRow(),
              ),
            ),

          // ═══════════════════════════════════════════════════
          // TITLE — staggered slide-up, fades slightly later
          // ═══════════════════════════════════════════════════
          if (titleFade < 1.0)
            Positioned(
              top: topPadding + _titleTop - titleSlide,
              left: 20,
              right: 20,
              child: Opacity(
                opacity: (1.0 - titleFade).clamp(0.0, 1.0),
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

          // ═══════════════════════════════════════════════════
          // SEARCH BAR — single instance, position interpolated
          // ═══════════════════════════════════════════════════
          Positioned(
            top: searchTop,
            left: 20,
            right: 20,
            child: _buildSearchBar(),
          ),

          // ═══════════════════════════════════════════════════
          // CURVED BOTTOM — always at bottom of header
          // ═══════════════════════════════════════════════════
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 24,
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Linear interpolation helper
  double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

  Widget _buildAvatarRow() {
    return Row(
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
                    imageUrl: profilePictureUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _buildAvatarPlaceholder(),
                    errorWidget: (_, __, ___) => _buildAvatarPlaceholder(),
                  )
                : _buildAvatarPlaceholder(),
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
      ],
    );
  }

  Widget _buildAvatarPlaceholder() {
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
      onTap: onSearchTap,
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
}

