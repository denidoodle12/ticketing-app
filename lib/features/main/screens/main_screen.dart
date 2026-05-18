import 'dart:convert';
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
import '../../../core/services/local_notification_service.dart';
import '../../../core/services/token_refresh_service.dart';
import '../../../core/constants/storage_keys.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../data/datasources/local/local_storage.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/ticket_provider.dart';
import '../../../routes/app_routes.dart';
import '../../home/screens/home_screen.dart';
import '../../tickets/screens/tickets_screen.dart';
import '../../knowledge/screens/knowledge_screen.dart';
import '../../profile/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  final bool showWelcomeToast;
  final String? pendingNotificationPayload;

  const MainScreen({
    super.key,
    this.showWelcomeToast = false,
    this.pendingNotificationPayload,
  });

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

    // Listen for session expired (auto-redirect to login)
    _setupAuthListener();

    // Setup handler for system tray notification taps
    _setupNotificationTapHandler();

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

  /// Setup handler for when user taps a notification in the system tray.
  /// Parses the payload JSON and navigates to the relevant ticket detail.
  void _setupNotificationTapHandler() {
    // Register callback for notification taps while app is alive
    LocalNotificationService.onNotificationTap = (String? payload) {
      if (payload == null || payload.isEmpty) return;
      _handleNotificationPayload(payload);
    };

    // Handle cold-launch: app was opened by tapping a notification.
    // Priority: widget param (from SplashScreen) > consumePendingNotificationPayload
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // 1. Payload passed explicitly via route extra (preferred path)
      final passedPayload = widget.pendingNotificationPayload;
      if (passedPayload != null && passedPayload.isNotEmpty) {
        _handleNotificationPayload(passedPayload);
        return;
      }

      // 2. Fallback: payload stored during LocalNotificationService.initialize()
      final pendingPayload = LocalNotificationService.instance
          .consumePendingNotificationPayload();
      if (pendingPayload != null) {
        _handleNotificationPayload(pendingPayload);
      }
    });
  }

  /// Parse notification payload and navigate to ticket detail
  void _handleNotificationPayload(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final ticketId = data['ticket_id'];
      if (ticketId != null && mounted) {
        // ticket_id can be int or String depending on source
        final id = ticketId is int ? ticketId : int.tryParse('$ticketId');
        if (id != null) {
          _navigateToTicketFromNotification(id);
        }
      }
    } catch (_) {
      // Invalid payload — ignore
    }
  }

  /// Navigate to ticket detail from a notification tap.
  /// Loads the ticket data first, then pushes the detail screen.
  Future<void> _navigateToTicketFromNotification(int ticketId) async {
    if (!mounted) return;

    // Small delay to ensure GoRouter is fully initialized after cold-launch
    // (during cold-launch the home route may not be fully set up yet)
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    try {
      final ticketProvider = context.read<TicketProvider>();
      await ticketProvider.loadTicketDetail(ticketId);
      final ticket = ticketProvider.selectedTicket;
      if (ticket != null && mounted) {
        context.push(AppRoutes.ticketDetail, extra: ticket);
      }
    } catch (_) {
      if (mounted) {
        ToastHelper.showError(context, 'Could not load ticket details');
      }
    }
  }

  /// Listen to AuthProvider state changes.
  /// When forceLogout() is triggered (refresh token expired),
  /// state becomes unauthenticated → redirect to login.
  void _setupAuthListener() {
    final authProvider = context.read<AuthProvider>();
    authProvider.addListener(_onAuthStateChanged);
  }

  void _onAuthStateChanged() {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    if (authProvider.state == AuthState.unauthenticated) {
      // Remove listener to prevent multiple redirects
      authProvider.removeListener(_onAuthStateChanged);
      // Redirect to login
      if (mounted) {
        context.go(AppRoutes.login);
      }
    }
  }

  Future<void> _initBackgroundService() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        final localStorage = context.read<LocalStorage>();
        final accessToken = await localStorage.getAccessToken();
        final refreshToken = await localStorage.getRefreshToken();

        if (accessToken != null && accessToken.isNotEmpty && mounted) {
          // Start background foreground service with SSE
          await BackgroundNotificationService.instance.startService(
            accessToken,
            refreshToken: refreshToken,
          );

          // Register callback: when proactive token refresh fires,
          // push new token to the SSE background service so it reconnects
          TokenRefreshService.instance.onTokenRefreshed = (newToken) {
            BackgroundNotificationService.instance.startService(
              newToken,
              refreshToken: refreshToken,
            );
          };

          // Listen for token synced from background SSE isolate (Gap 2 fix).
          // When SSE independently refreshes, it sends the new token back
          // so FlutterSecureStorage stays in sync with the background service.
          BackgroundNotificationService.instance.on('tokenSynced').listen((
            data,
          ) async {
            final syncedToken = data?['token'] as String?;
            if (syncedToken != null) {
              const secureStorage = FlutterSecureStorage();
              await secureStorage.write(
                key: StorageKeys.accessToken,
                value: syncedToken,
              );
              // Restart proactive timer with the synced token
              TokenRefreshService.instance.startProactiveRefresh();
            }
          });

          // Listen for notification taps forwarded from background isolate
          BackgroundNotificationService.instance.on('notificationTapped').listen((
            data,
          ) {
            final payload = data?['payload'] as String?;
            if (payload != null && payload.isNotEmpty && mounted) {
              _handleNotificationPayload(payload);
            }
          });

          // When background service sends a new notification event,
          // re-show it from the main isolate's LocalNotificationService.
          // This ensures the tap handler (onDidReceiveNotificationResponse)
          // is properly registered, enabling deep-link to ticket detail.
          // The same notification ID replaces the background's version.
          BackgroundNotificationService.instance.on('newNotification').listen((
            data,
          ) {
            if (data != null) {
              LocalNotificationService.instance.showFromRawJson(
                Map<String, dynamic>.from(data),
              );
            }
          });

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
    // Safely remove auth listener
    try {
      context.read<AuthProvider>().removeListener(_onAuthStateChanged);
    } catch (_) {}
    // Don't stop background service on dispose - it should keep running!
    // Only stop on logout via forceLogout() or logout()
    super.dispose();
  }

  void _onTabTapped(int index) {
    // Notify tickets screen when switching to it
    if (index == 1) {
      _ticketsKey.currentState?.onTabSelected();
    }
    setState(() {
      _currentIndex = index;
    });
    HapticFeedback.lightImpact();
  }

  List<Widget> get _screens => [
    const HomeScreen(),
    _TicketsScreenWrapper(key: _ticketsKey),
    const KnowledgeScreen(),
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
    // Read system bottom inset (gesture bar / navigation buttons height).
    // This varies per device: 0 on full-gesture devices, ~24-48dp on button devices.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navBarHeight = 100.0 + bottomInset;

    return Scaffold(
      body: _screens[_currentIndex],
      extendBody: true,
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: SizedBox(
        height: navBarHeight,
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

            // Nav items — height 80 fixed + bottom inset as padding
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              // Do NOT set bottom: 0 — instead drive height explicitly
              height: navBarHeight,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 8,
                  right: 8,
                  bottom: bottomInset, // push items above system bar
                ),
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
                    _buildNavItem(
                      index: 2,
                      label: 'Knowledge',
                      iconPath: '',
                      activeIconPath: '',
                      materialIcon: Icons.menu_book_outlined,
                      materialActiveIcon: Icons.menu_book,
                    ),
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

  Widget _buildNavItem({
    required int index,
    required String label,
    required String iconPath,
    required String activeIconPath,
    bool useOriginalActiveColor = false,
    IconData? materialIcon,
    IconData? materialActiveIcon,
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
            child: materialIcon != null
                ? Icon(
                    isSelected
                        ? (materialActiveIcon ?? materialIcon)
                        : materialIcon,
                    key: ValueKey(isSelected),
                    size: 24,
                    color: color,
                  )
                : SvgPicture.asset(
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
      // Switch to Tickets tab and force refresh
      setState(() => _currentIndex = 1);
      // Force TicketsScreen to rebuild with fresh data
      _ticketsKey.currentState?.onTabSelected();
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
