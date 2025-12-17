import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';

class PageIndicator extends StatelessWidget {
  final int currentPage;
  final int pageCount;

  // Dot sizes
  static const double _dotSize = 8.0;
  static const double _activeDotWidth = 24.0;
  static const double _activeDotHeight = 8.0;
  static const double _dotSpacing = 6.0;
  static const double _borderRadius = 4.0;

  const PageIndicator({
    super.key,
    required this.currentPage,
    required this.pageCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) {
          final isActive = currentPage == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: _dotSpacing / 2),
            width: isActive ? _activeDotWidth : _dotSize,
            height: isActive ? _activeDotHeight : _dotSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                isActive ? _borderRadius : _dotSize / 2,
              ),
              color: isActive
                  ? AppColors.primaryDark
                  : AppColors.primaryDark.withAlpha(77), // 30% opacity
            ),
          );
        },
      ),
    );
  }
}
