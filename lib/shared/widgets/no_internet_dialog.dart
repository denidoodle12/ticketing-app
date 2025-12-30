import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart';
import '../../core/themes/app_colors.dart';

class NoInternetDialog extends StatelessWidget {
  final VoidCallback? onRefresh;

  const NoInternetDialog({
    super.key,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration
            SizedBox(
              width: 200,
              height: 180,
              child: Image.asset(
                'assets/images/illustrations/no_internet.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholderIllustration();
                },
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'No Internet Connection',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              'Please make sure you\'re connected to the internet, then you can refresh this page',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Check Phone Connection Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  AppSettings.openAppSettings(type: AppSettingsType.wifi);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary600,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Check Phone Connection',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Refresh Button
            TextButton(
              onPressed: onRefresh,
              child: Text(
                'Refresh',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIllustration() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 64,
            color: AppColors.primary600,
          ),
          const SizedBox(height: 8),
          Text(
            'No WiFi',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
