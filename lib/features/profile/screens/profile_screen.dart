import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/api_config.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../routes/app_routes.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_menu_item.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _pushNotificationEnabled = true;

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
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Consumer2<ProfileProvider, AuthProvider>(
        builder: (context, profileProvider, authProvider, child) {
          final user = profileProvider.user ?? authProvider.currentUser;

          if (profileProvider.isLoading && user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _loadProfile,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // Profile Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // Avatar
                        ProfileAvatar(
                          imageUrl: user?.profilePicture != null
                              ? '${ApiConfig.baseUrl}${user!.profilePicture}'
                              : null,
                          name: user?.fullName ?? 'User',
                          size: 56,
                        ),
                        const SizedBox(width: 12),

                        // User Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Full Name
                              Text(
                                user?.fullName ?? 'User',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Email
                              Text(
                                user?.email ?? '',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              // Role
                              if (user?.role != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  user!.role.substring(0, 1).toUpperCase() +
                                      user.role.substring(1).toLowerCase(),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Logout Icon
                        IconButton(
                          onPressed: () => _showLogoutDialog(context),
                          icon: const Icon(
                            Icons.logout,
                            color: AppColors.textSecondary,
                            size: 24,
                          ),
                          tooltip: 'Sign Out',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Menu Items
                  Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Divider(height: 1),
                      ),
                      ProfileMenuItem(
                        icon: Icons.person_outline,
                        title: 'User Profile',
                        onTap: () => context.push(AppRoutes.editProfile),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Divider(height: 1),
                      ),
                      ProfileMenuItem(
                        icon: Icons.lock_outline,
                        title: 'Change Password',
                        onTap: () => context.push(AppRoutes.changePassword),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Divider(height: 1),
                      ),
                      ProfileMenuItem(
                        icon: Icons.help_outline,
                        title: 'FAQs',
                        onTap: () => _showAboutDialog(context),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Divider(height: 1),
                      ),
                      ProfileMenuItem(
                        icon: Icons.notifications_outlined,
                        title: 'Push Notification',
                        showArrow: false,
                        trailing: Switch(
                          value: _pushNotificationEnabled,
                          onChanged: (value) {
                            setState(() {
                              _pushNotificationEnabled = value;
                            });
                            // TODO: Implement push notification toggle
                          },
                          activeColor: AppColors.success500,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Divider(height: 1),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Support Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.grey100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'If you have any other query you can reach out to us.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              // TODO: Open WhatsApp or support
                            },
                            child: Text(
                              'Contact Support',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.primary500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // App Version
                  Text(
                    'Version ${ApiConfig.appVersion}',
                    style: AppTextStyles.caption,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('About'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enterprise Ticketing System',
              style: AppTextStyles.h6,
            ),
            const SizedBox(height: 8),
            Text(
              'Version ${ApiConfig.appVersion}',
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error500,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
