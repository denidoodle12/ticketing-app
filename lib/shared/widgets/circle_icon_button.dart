import 'package:flutter/material.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_shadows.dart';

/// Floating circular icon button used for screen-level back navigation and
/// header actions (share, bookmark, more, etc.).
///
/// Replaces the 14+ copies of `_buildBackButton` and `_buildActionButton`
/// scattered across the app that all rendered the same 44×44 white square
/// with a soft shadow and a centered icon.
///
/// Use the named constructors for the common shapes:
/// - `CircleIconButton.back(context)` — back navigation
/// - `CircleIconButton(icon, onTap)` — generic action
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? backgroundColor;
  final double size;
  final double borderRadius;
  final Widget? badge;

  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.backgroundColor,
    this.size = 44,
    this.borderRadius = 12,
    this.badge,
  });

  /// Standard back button — pops the current route.
  factory CircleIconButton.back(
    BuildContext context, {
    Key? key,
    Color? iconColor,
    Color? backgroundColor,
  }) {
    return CircleIconButton(
      key: key,
      icon: Icons.arrow_back,
      iconColor: iconColor,
      backgroundColor: backgroundColor,
      onTap: () => Navigator.of(context).maybePop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.white,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: AppShadows.card,
          ),
          child: Icon(
            icon,
            color: iconColor ?? AppColors.primaryDark,
            size: 22,
          ),
        ),
      ),
    );

    if (badge == null) return button;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(top: -2, right: -2, child: badge!),
      ],
    );
  }
}
