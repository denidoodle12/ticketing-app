import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/services/local_notification_service.dart';
import 'package:ticketing_app/core/constants/asset_paths.dart';
import '../../../providers/auth_provider.dart';
import '../../../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  // Controls visibility: wait until image is pre-cached before animating
  bool _ready = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _initializeApp();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    // Pre-cache the logo so image & text appear simultaneously
    await precacheImage(
      const AssetImage(AssetPaths.tixcoraColorCircle),
      context,
    );

    if (!mounted) return;

    // Mark ready & start animation together — logo + text animate as one unit
    setState(() => _ready = true);
    _animController.forward();

    // Run auth checks in parallel (they were already started)
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedOnboarding =
        prefs.getBool(StorageKeys.hasCompletedOnboarding) ?? false;

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    await authProvider.checkAuthStatus();

    await Future.delayed(
      const Duration(milliseconds: AppConstants.splashDurationMs),
    );

    if (!mounted) return;

    if (!hasCompletedOnboarding) {
      context.go(AppRoutes.onboarding);
    } else if (authProvider.isAuthenticated) {
      if (authProvider.isFirstLogin) {
        context.go(AppRoutes.changePassword, extra: true);
      } else {
        // Cold-launch: check if app was opened from a notification tap.
        // Pass the payload to MainScreen so it can deep-link to the ticket.
        final pendingPayload = LocalNotificationService.instance
            .consumePendingNotificationPayload();

        context.go(
          AppRoutes.home,
          extra: {
            if (pendingPayload != null)
              'pendingNotificationPayload': pendingPayload,
          },
        );
      }
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary600,
      body: Stack(
        children: [
          // Subtle radial glow
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary500.withAlpha(120),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Center content: logo + app name — both in same animation
          if (_ready)
            Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Circle logo — already pre-cached, renders instantly
                      Image.asset(
                        AssetPaths.tixcoraColorCircle,
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 20),

                      // App name — same fade/scale as logo
                      Text(
                        AppConstants.appName,
                        style: AppTextStyles.h1.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 36,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom loading indicator
          if (_ready)
            Positioned(
              left: 0,
              right: 0,
              bottom: 52,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        strokeCap: StrokeCap.round,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.white.withAlpha(180),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      AppConstants.appTagline,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.white.withAlpha(160),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
