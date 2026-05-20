import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Shared elevation/shadow tokens used across the app.
///
/// Before this file existed, every card and floating button literally
/// re-wrote the same `BoxShadow` with `withAlpha(20)` — 23 copies of the
/// same magic number. Use these tokens instead so a future design tweak is
/// a one-line change.
class AppShadows {
  AppShadows._();

  /// Subtle shadow for resting cards (tickets, articles, list items).
  /// Equivalent to the old `withAlpha(20)` recipe.
  static List<BoxShadow> get card => [
    BoxShadow(
      color: AppColors.shadow.withAlpha(20),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Slightly deeper shadow for elements that float above content
  /// (FABs, modal headers, sticky CTAs).
  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: AppColors.shadow.withAlpha(30),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// Tight shadow for small interactive controls (icon buttons, chips).
  static List<BoxShadow> get tight => [
    BoxShadow(
      color: AppColors.shadow.withAlpha(15),
      blurRadius: 6,
      offset: const Offset(0, 1),
    ),
  ];
}
