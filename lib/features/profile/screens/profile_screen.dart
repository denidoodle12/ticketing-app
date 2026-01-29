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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  void _loadProfile() {
    final authUser = context.read<AuthProvider>().currentUser;
    if (authUser != null) {
      context.read<ProfileProvider>().setUser(authUser);
    }
    context.read<ProfileProvider>().loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, profileProvider, child) {
          final user = profileProvider.user;

          if (profileProvider.isLoading && user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              await profileProvider.loadProfile();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Profile Header Card
                  Container(
                    width: double.infinity,
                    color: AppColors.white,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Avatar
                        ProfileAvatar(
                          imageUrl: user?.profilePicture != null
                              ? '${ApiConfig.baseUrl}${user!.profilePicture}'
                              : null,
                          name: user?.fullName ?? 'User',
                          size: 90,
                        ),
                        const SizedBox(height: 16),

                        // Name
                        Text(
                          user?.fullName ?? 'User',
                          style: AppTextStyles.h4,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),

                        // Email
                        Text(
                          user?.email ?? '',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            user?.role.toUpperCase() ?? '',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Menu Items
                  Container(
                    color: AppColors.white,
                    child: Column(
                      children: [
                        ProfileMenuItem(
                          icon: Icons.person_outline,
                          title: 'Edit Profile',
                          onTap: () {
                            context.push(AppRoutes.editProfile);
                          },
                        ),
                        const Divider(height: 1, indent: 56),
                        ProfileMenuItem(
                          icon: Icons.lock_outline,
                          title: 'Change Password',
                          onTap: () {
                            context.push(AppRoutes.changePassword);
                          },
                        ),
                        const Divider(height: 1, indent: 56),
                        ProfileMenuItem(
                          icon: Icons.info_outline,
                          title: 'About App',
                          onTap: () {
                            _showAboutDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Logout Button
                  Container(
                    color: AppColors.white,
                    child: ProfileMenuItem(
                      icon: Icons.logout,
                      title: 'Logout',
                      iconColor: AppColors.error500,
                      textColor: AppColors.error500,
                      showArrow: false,
                      onTap: () => _showLogoutDialog(context),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // App Version
                  Text(
                    'Version ${ApiConfig.appVersion}',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 24),
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
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
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
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
