import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../core/constants/app_constants.dart';
import '../../home/screens/home_screen.dart';
import '../../tickets/screens/tickets_screen.dart';
import '../../profile/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  final bool showWelcomeToast;

  const MainScreen({
    super.key,
    this.showWelcomeToast = false,
  });

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Keys to force rebuild screens when tab changes
  final GlobalKey<_TicketsScreenWrapperState> _ticketsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
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

  void _onTabTapped(int index) {
    // Notify tickets screen when switching to it
    if (index == 1) {
      _ticketsKey.currentState?.onTabSelected();
    }
    setState(() {
      _currentIndex = index;
    });
  }

  List<Widget> get _screens => [
    const HomeScreen(),
    _TicketsScreenWrapper(key: _ticketsKey),
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withAlpha(25),
              blurRadius: 20,
              spreadRadius: -5,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: Container(
            color: AppColors.white,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      index: 0,
                      label: 'Home',
                      iconPath: 'assets/icons/ic_home.svg',
                      activeIconPath: 'assets/icons/ic_home_filled.svg',
                    ),
                    _buildNavItem(
                      index: 1,
                      label: 'Tickets',
                      iconPath: 'assets/icons/ic_ticket.svg',
                      activeIconPath: 'assets/icons/ic_ticket_filled.svg',
                    ),
                    _buildNavItem(
                      index: 2,
                      label: 'Profile',
                      iconPath: 'assets/icons/ic_profile.svg',
                      activeIconPath: 'assets/icons/ic_profile_filled.svg',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required String iconPath,
    required String activeIconPath,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.primaryDark : AppColors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: () => _onTabTapped(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                isSelected ? activeIconPath : iconPath,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  color,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
