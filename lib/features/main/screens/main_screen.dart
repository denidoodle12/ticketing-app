import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/background_notification_service.dart';
import '../../../data/datasources/local/local_storage.dart';
import '../../../providers/notification_provider.dart';
import '../../../routes/app_routes.dart';
import '../../home/screens/home_screen.dart';
import '../../tickets/screens/tickets_screen.dart';
import '../../notifications/screens/notification_screen.dart';
import '../../profile/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  final bool showWelcomeToast;

  const MainScreen({super.key, this.showWelcomeToast = false});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _pressedIndex = -1;
  bool _centerPressed = false;

  // Keys to force rebuild screens when tab changes
  final GlobalKey<_TicketsScreenWrapperState> _ticketsKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // Start background SSE service for real-time notifications
    _initBackgroundService();

    // Show welcome toast after first frame if flag is set
    if (widget.showWelcomeToast) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ToastHelper.showSuccess(
            context,
            'Welcome to ${AppConstants.appName}!',
            description: 'Your account is ready to use.',
          );
        }
      });
    }
  }

  Future<void> _initBackgroundService() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        final localStorage = context.read<LocalStorage>();
        final accessToken = await localStorage.getAccessToken();

        if (accessToken != null && accessToken.isNotEmpty && mounted) {
          // Start background foreground service with SSE
          await BackgroundNotificationService.instance.startService(
            accessToken,
          );

          if (!mounted) return;

          // Setup listener for notifications from background service
          final notificationProvider = context.read<NotificationProvider>();
          notificationProvider.listenToBackgroundService();

          // Fetch initial notifications and unread count
          await notificationProvider.refresh();
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    // Don't stop background service on dispose - it should keep running!
    // Only stop on logout via NotificationProvider.clear()
    super.dispose();
  }

  void _onTabTapped(int index) {
    // Notify tickets screen when switching to it
    if (index == 1) {
      _ticketsKey.currentState?.onTabSelected();
    }
    // Refresh notifications when switching to notifications tab
    if (index == 2) {
      context.read<NotificationProvider>().refresh();
    }
    setState(() {
      _currentIndex = index;
    });
    HapticFeedback.lightImpact();
  }

  List<Widget> get _screens => [
    const HomeScreen(),
    _TicketsScreenWrapper(key: _ticketsKey),
    const NotificationScreen(),
    const ProfileScreen(),
  ];

  /// Public method to switch tabs - can be called via context.findAncestorStateOfType
  void switchToTab(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      extendBody: true,
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: SizedBox(
        height: 100,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Nav bar background with wave notch
            Positioned.fill(
              child: CustomPaint(
                painter: _NavBarNotchPainter(
                  color: AppColors.white,
                  shadowColor: AppColors.black.withAlpha(25),
                ),
              ),
            ),

            // Sliding active tab indicator at the TOP EDGE of the nav bar
            Positioned(
              top: 18,
              left: 8,
              right: 8,
              height: 6,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columnWidth = constraints.maxWidth / 5;
                  // Map tab index to column center position
                  final positions = {
                    0: columnWidth * 0.5 - 24,
                    1: columnWidth * 1.5 - 24,
                    2: columnWidth * 3.5 - 24,
                    3: columnWidth * 4.5 - 24,
                  };
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
                        left: positions[_currentIndex] ?? 0,
                        top: 0,
                        child: Container(
                          height: 3,
                          width: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Nav items positioned at the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 80,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(
                        index: 0,
                        label: 'Home',
                        iconPath: 'assets/icons/ic_home_no_filled.svg',
                        activeIconPath: 'assets/icons/ic_home_filled.svg',
                      ),
                      _buildNavItem(
                        index: 1,
                        label: 'Tickets',
                        iconPath: 'assets/icons/ic_tickets_nofilled.svg',
                        activeIconPath: 'assets/icons/ic_tickets_filled.svg',
                        useOriginalActiveColor: true,
                      ),
                      const Expanded(child: SizedBox()),
                      _buildNotificationNavItem(),
                      _buildNavItem(
                        index: 3,
                        label: 'Profile',
                        iconPath: 'assets/icons/ic_profile_no_filled.svg',
                        activeIconPath: 'assets/icons/ic_profile_filled.svg',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Floating center diamond button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(child: _buildCenterButton()),
            ),
          ],
        ),
      ),
    );
  }

  /// Build notification nav item with badge
  Widget _buildNotificationNavItem() {
    final isSelected = _currentIndex == 2;
    final isPressed = _pressedIndex == 2;
    final color = isSelected ? AppColors.primaryDark : AppColors.textSecondary;

    Widget content = Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            child: Consumer<NotificationProvider>(
              key: ValueKey(isSelected),
              builder: (context, provider, _) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SvgPicture.asset(
                      isSelected
                          ? 'assets/icons/ic_notification_filled.svg'
                          : 'assets/icons/ic_notification_no_filled.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                    ),
                    if (provider.unreadCount > 0)
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error500,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            provider.unreadCount > 99
                                ? '99+'
                                : provider.unreadCount.toString(),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Notification',
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );

    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressedIndex = 2),
        onTapUp: (_) {
          setState(() => _pressedIndex = -1);
          _onTabTapped(2);
        },
        onTapCancel: () => setState(() => _pressedIndex = -1),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: isPressed ? 0.85 : 1.0,
          duration: Duration(milliseconds: isPressed ? 100 : 500),
          curve: isPressed ? Curves.easeOut : Curves.elasticOut,
          child: content,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required String iconPath,
    required String activeIconPath,
    bool useOriginalActiveColor = false,
  }) {
    final isSelected = _currentIndex == index;
    final isPressed = _pressedIndex == index;
    final color = isSelected ? AppColors.primaryDark : AppColors.textSecondary;
    final applyColorFilter = !(isSelected && useOriginalActiveColor);

    Widget content = Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            child: SvgPicture.asset(
              isSelected ? activeIconPath : iconPath,
              key: ValueKey(isSelected),
              width: 24,
              height: 24,
              colorFilter: applyColorFilter
                  ? ColorFilter.mode(color, BlendMode.srcIn)
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );

    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressedIndex = index),
        onTapUp: (_) {
          setState(() => _pressedIndex = -1);
          _onTabTapped(index);
        },
        onTapCancel: () => setState(() => _pressedIndex = -1),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: isPressed ? 0.85 : 1.0,
          duration: Duration(milliseconds: isPressed ? 100 : 500),
          curve: isPressed ? Curves.easeOut : Curves.elasticOut,
          child: content,
        ),
      ),
    );
  }

  /// Build the floating center diamond button for quick create ticket
  Widget _buildCenterButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _centerPressed = true),
      onTapUp: (_) {
        setState(() => _centerPressed = false);
        HapticFeedback.mediumImpact();
        _navigateToCreateTicket();
      },
      onTapCancel: () => setState(() => _centerPressed = false),
      child: AnimatedScale(
        scale: _centerPressed ? 0.85 : 1.0,
        duration: Duration(milliseconds: _centerPressed ? 100 : 500),
        curve: _centerPressed ? Curves.easeOut : Curves.elasticOut,
        child: Transform.rotate(
          angle: 0.7854, // 45 degrees in radians (pi/4)
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary500, AppColors.primary600],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(100),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Transform.rotate(
              angle: -0.7854, // Counter-rotate icon to keep it upright
              child: const Icon(Icons.add, color: AppColors.white, size: 30),
            ),
          ),
        ),
      ),
    );
  }

  /// Navigate to create ticket screen
  void _navigateToCreateTicket() async {
    final result = await context.push(AppRoutes.createTicket);
    if (result != null && mounted) {
      // Switch to Tickets tab and refresh
      setState(() => _currentIndex = 1);
    }
  }
}

/// Wrapper for TicketsScreen to handle tab selection callback
class _TicketsScreenWrapper extends StatefulWidget {
  const _TicketsScreenWrapper({super.key});

  @override
  State<_TicketsScreenWrapper> createState() => _TicketsScreenWrapperState();
}

class _TicketsScreenWrapperState extends State<_TicketsScreenWrapper> {
  Key _ticketsScreenKey = UniqueKey();

  /// Called when this tab is selected - forces rebuild of TicketsScreen
  void onTabSelected() {
    setState(() {
      _ticketsScreenKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return TicketsScreen(key: _ticketsScreenKey);
  }
}

/// Custom painter that draws the nav bar background with a wave notch in the center
class _NavBarNotchPainter extends CustomPainter {
  final Color color;
  final Color shadowColor;

  _NavBarNotchPainter({required this.color, required this.shadowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final path = _buildPath(size);

    // Draw shadow
    canvas.drawPath(path.shift(const Offset(0, -2)), shadowPaint);
    // Draw white fill
    canvas.drawPath(path, paint);
  }

  Path _buildPath(Size size) {
    final path = Path();
    const topY = 20.0; // Flat top edge Y position
    const cornerRadius = 24.0;
    final centerX = size.width / 2;
    const notchWidth = 88.0; // Width of the wave area
    const notchPeakY = 2.0; // Top of the wave (how high it goes)

    // Start from top-left corner
    path.moveTo(0, topY + cornerRadius);
    path.quadraticBezierTo(0, topY, cornerRadius, topY);

    // Flat top to left edge of notch
    path.lineTo(centerX - notchWidth / 2, topY);

    // Wave: left side curves up
    path.cubicTo(
      centerX - notchWidth / 3.5,
      topY,
      centerX - notchWidth / 4,
      notchPeakY,
      centerX,
      notchPeakY,
    );

    // Wave: right side curves back down
    path.cubicTo(
      centerX + notchWidth / 4,
      notchPeakY,
      centerX + notchWidth / 3.5,
      topY,
      centerX + notchWidth / 2,
      topY,
    );

    // Flat top to right corner
    path.lineTo(size.width - cornerRadius, topY);
    path.quadraticBezierTo(size.width, topY, size.width, topY + cornerRadius);

    // Right side down
    path.lineTo(size.width, size.height);

    // Bottom
    path.lineTo(0, size.height);

    // Left side up
    path.lineTo(0, topY + cornerRadius);

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
