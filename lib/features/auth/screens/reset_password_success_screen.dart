import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/asset_paths.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../routes/app_routes.dart';

class ResetPasswordSuccessScreen extends StatelessWidget {
  const ResetPasswordSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Vector Illustration
              Image.asset(
                AssetPaths.vecSuccessResetPassword,
                height: 220,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(60),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 70,
                      color: AppColors.white,
                    ),
                  );
                },
              ),
              const SizedBox(height: 48),

              // Title (left-aligned)
              Align(
                alignment: Alignment.center,
                child: Text(
                  'Password Reset Successful!',
                  style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),

              // Description (centered)
              Align(
                alignment: Alignment.center,
                child: Text(
                  'Your password has been reset successfully. You can now login with your new password.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // Continue Button
              CustomButton(
                text: 'Continue to Login',
                onPressed: () {
                  context.go(AppRoutes.login);
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
