import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait a frame to ensure context is ready
    await Future.delayed(Duration.zero);

    // Check if widget is still mounted
    if (!mounted) return;

    // Check auth status
    final authProvider = context.read<AuthProvider>();
    await authProvider.checkAuthStatus();

    // Wait for splash duration
    await Future.delayed(
      const Duration(milliseconds: AppConstants.splashDurationMs),
    );

    // Navigate based on auth status
    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Placeholder
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.support_agent,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),

            // App Name
            Text(
              AppConstants.appName,
              style: AppTextStyles.h3.copyWith(
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 8),

            // App Version
            Text(
              'v${AppConstants.appVersion}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 48),

            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
            ),
          ],
        ),
      ),
    );
  }
}
