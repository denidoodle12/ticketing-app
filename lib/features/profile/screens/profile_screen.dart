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
import '../../../shared/widgets/profile_picture_viewer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Avatar size
  static const double _avatarSize = 60.0;

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
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
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
                SliverToBoxAdapter(child: _buildProfileHeader(user)),
                SliverToBoxAdapter(child: _buildMenuContent(user)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Profile header: Avatar left + user info right in a Row
  Widget _buildProfileHeader(user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          // Avatar
          ProfileAvatar(
            imageUrl: user?.profilePicture != null
                ? '${ApiConfig.baseUrl}${user!.profilePicture}'
                : null,
            name: user?.fullName ?? 'User',
            size: _avatarSize,
            heroTag: 'profile_screen_avatar',
            onTap: () {
              ProfilePictureViewer.show(
                context: context,
                imageUrl: user?.profilePicture != null
                    ? '${ApiConfig.baseUrl}${user!.profilePicture}'
                    : null,
                userName: user?.fullName ?? 'User',
                heroTag: 'profile_screen_avatar',
              );
            },
          ),
          const SizedBox(width: 16),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full Name
                Text(
                  user?.fullName ?? 'User',
                  style: AppTextStyles.h5.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // Email
                Text(
                  user?.email ?? '',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
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

          // ── Account Section ──
          _buildSectionHeader('Account'),
          const SizedBox(height: 8),
          _buildSectionCard(
            children: [
              _buildMenuItem(
                icon: Icons.person_outline,
                title: 'User Profile',
                subtitle: 'Manage your personal information',
                onTap: () => context.push(AppRoutes.editProfile),
              ),
              const Divider(height: 1, indent: 40),
              _buildMenuItem(
                icon: Icons.lock_outline,
                title: 'Change Password',
                subtitle: 'Update your security credentials',
                onTap: () => context.push(AppRoutes.changePassword),
              ),
            ],
          ),



          const SizedBox(height: 32),

          // ── Logout Button ──
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(context),
              icon: const Icon(
                Icons.logout_rounded,
                size: 18,
                color: AppColors.error500,
              ),
              label: Text(
                'Sign Out',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.error500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error500, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryDark, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textDisabled,
              size: 20,
            ),
          ],
        ),
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
