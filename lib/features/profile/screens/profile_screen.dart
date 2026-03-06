import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/api_config.dart';
import '../../../core/utils/app_info.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../providers/profile_provider.dart';
import '../../../routes/app_routes.dart';
import '../widgets/profile_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _pushNotificationEnabled = true;

  // Avatar size and overlap constants
  static const double _avatarRadius = 45.0;
  static const double _avatarBorderWidth = 4.0;
  static const double _avatarTotalRadius = _avatarRadius + _avatarBorderWidth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    final profileProvider = context.read<ProfileProvider>();
    await profileProvider.loadProfile();

    if (mounted && profileProvider.user != null) {
      context.read<AuthProvider>().updateCurrentUser(profileProvider.user!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Consumer2<ProfileProvider, AuthProvider>(
        builder: (context, profileProvider, authProvider, child) {
          final user = profileProvider.user ?? authProvider.currentUser;

          if (profileProvider.isLoading && user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _loadProfile,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeaderWithAvatar(user)),
                SliverToBoxAdapter(child: _buildMenuContent(user)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds the gradient header + overlapping avatar as a single unit.
  /// Uses a Stack so the avatar sits at the boundary of gradient and white.
  Widget _buildHeaderWithAvatar(user) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Gradient header
        Column(
          children: [
            _buildGradientHeader(user),
            // White space below gradient to hold the bottom half of the avatar
            SizedBox(height: _avatarTotalRadius + 12),
          ],
        ),
        // Avatar overlapping the gradient/white boundary
        Positioned(bottom: 12, child: _buildOverlappingAvatar(user)),
      ],
    );
  }

  Widget _buildGradientHeader(user) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary600, AppColors.primary500],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // AppBar - only "Profile" text, no icons
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Profile',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Full Name
              Text(
                user?.fullName ?? 'User',
                style: AppTextStyles.h5.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 4),

              // Email
              Text(
                user?.email ?? '',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white.withAlpha(204),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              // Role Badge
              if (user?.role != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user!.role.substring(0, 1).toUpperCase() +
                        user.role.substring(1).toLowerCase(),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              // Space for the top half of the avatar to sit inside the gradient
              SizedBox(height: _avatarTotalRadius + 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Avatar with a white border, centered at the gradient/white boundary.
  Widget _buildOverlappingAvatar(user) {
    return Container(
      padding: const EdgeInsets.all(_avatarBorderWidth),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white,
      ),
      child: ProfileAvatar(
        imageUrl: user?.profilePicture != null
            ? '${ApiConfig.baseUrl}${user!.profilePicture}'
            : null,
        name: user?.fullName ?? 'User',
        size: _avatarRadius * 2,
      ),
    );
  }

  Widget _buildMenuContent(user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Single flat menu card
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withAlpha(15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.person_outline,
                  title: 'User Profile',
                  onTap: () => context.push(AppRoutes.editProfile),
                  isFirst: true,
                ),
                const Divider(height: 1, indent: 60, endIndent: 16),
                _buildMenuItem(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  onTap: () => context.push(AppRoutes.changePassword),
                ),
                const Divider(height: 1, indent: 60, endIndent: 16),
                _buildSwitchMenuItem(
                  icon: Icons.notifications_outlined,
                  title: 'Push Notification',
                  value: _pushNotificationEnabled,
                  onChanged: (value) {
                    setState(() => _pushNotificationEnabled = value);
                    // TODO: Implement push notification toggle
                  },
                ),
                const Divider(height: 1, indent: 60, endIndent: 16),
                _buildMenuItem(
                  icon: Icons.help_outline,
                  title: 'FAQs',
                  onTap: () => _showAboutDialog(context),
                ),
                const Divider(height: 1, indent: 60, endIndent: 16),
                _buildMenuItem(
                  icon: Icons.headset_mic_outlined,
                  title: 'Contact Support',
                  onTap: () {
                    // TODO: Open contact support
                  },
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Sign Out Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(context),
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error500,
                side: const BorderSide(color: AppColors.error500),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // App Version
          Center(
            child: Text(
              'Version ${AppInfo.version}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textDisabled,
              ),
            ),
          ),

          // Bottom padding for navigation
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.only(
          topLeft: isFirst ? const Radius.circular(16) : Radius.zero,
          topRight: isFirst ? const Radius.circular(16) : Radius.zero,
          bottomLeft: isLast ? const Radius.circular(16) : Radius.zero,
          bottomRight: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary500, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textDisabled,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchMenuItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary500, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.success500,
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.info_outline,
                color: AppColors.primary500,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('About'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enterprise Ticketing System', style: AppTextStyles.h6),
            const SizedBox(height: 8),
            Text(
              'Version ${AppInfo.version}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'A mobile application for managing support tickets and communicating with agents.',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.error500.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout,
                color: AppColors.error500,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Sign Out'),
          ],
        ),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Capture provider before navigation invalidates context
              final authProvider = context.read<AuthProvider>();
              // Show toast while Navigator is still available
              ToastHelper.showSuccess(
                context,
                'Logged Out',
                description: 'You have been signed out successfully.',
              );
              // Navigate to login FIRST (before logout triggers OfflinePage)
              context.go(AppRoutes.login);
              // Then perform logout (clears tokens, cache, auth state)
              await authProvider.logout();
            },
            child: Text(
              'Sign Out',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.error500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
