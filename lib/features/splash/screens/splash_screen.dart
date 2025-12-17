import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/storage_keys.dart';
import 'package:ticketing_app/core/constants/asset_paths.dart';
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

    // Check onboarding completion status
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedOnboarding =
        prefs.getBool(StorageKeys.hasCompletedOnboarding) ?? false;

    // Check auth status
    final authProvider = context.read<AuthProvider>();
    await authProvider.checkAuthStatus();

    // Wait for splash duration
    await Future.delayed(
      const Duration(milliseconds: AppConstants.splashDurationMs),
    );

    // Navigate based on onboarding and auth status
    if (!mounted) return;

    if (!hasCompletedOnboarding) {
      context.go(AppRoutes.onboarding);
    } else if (authProvider.isAuthenticated) {
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Main Content (Logo, Title, Subtitle)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Circle Logo
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.white,
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Image.asset(
                        AssetPaths.appLogo,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // App Name
                    Text(
                      AppConstants.appName,
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.primary600,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tagline
                    Text(
                      AppConstants.appTagline,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary600.withValues(alpha: 0.9),
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Section (Loading + Powered By)
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(
                children: [
                  // Loading Indicator
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Loading Text
                  Text(
                    'INITIALIZING SECURE SESSION...',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.black.withValues(alpha: 0.8),
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Powered By
                  Text(
                    AppConstants.poweredBy,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.black.withValues(alpha: 0.6),
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
