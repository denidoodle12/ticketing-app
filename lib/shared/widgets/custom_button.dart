import 'package:flutter/material.dart';
import '../../core/themes/app_colors.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final bool isEnabled;
  final Color? backgroundColor;
  final Color? textColor;
  final double? height;
  final Widget? icon;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.isEnabled = true,
    this.backgroundColor,
    this.textColor,
    this.height,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = !isEnabled || isLoading;

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: height ?? 52,
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled
              ? AppColors.grey300
              : (backgroundColor ?? AppColors.primary600),
          foregroundColor: isDisabled
              ? AppColors.grey500
              : (textColor ?? AppColors.white),
          disabledBackgroundColor: AppColors.grey300,
          disabledForegroundColor: AppColors.grey500,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.white,
                  ),
                ),
              )
            : icon != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon!,
                      const SizedBox(width: 8),
                      Text(text),
                    ],
                  )
                : Text(text),
      ),
    );
  }
}
