import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors (Navy Blue) - Main branding & actions
  static const Color primary600 = Color(0xFF1E3A8A); // Dark Navy
  static const Color primary500 = Color(0xFF2563EB); // Standard Navy Blue
  static const Color primary400 = Color(0xFF60A5FA); // Light Navy
  static const Color primary100 = Color(0xFFDBEAFE); // Very Light Navy
  static const Color primary50 = Color(0xFFEFF6FF); // Lightest Navy

  // For backwards compatibility
  static const Color primary = primary500;
  static const Color primaryDark = primary600;
  static const Color primaryLight = primary400;

  // Accent Colors (Teal) - Highlights & secondary actions
  static const Color accent700 = Color(0xFF0F766E); // Dark Teal
  static const Color accent600 = Color(0xFF0D9488); // Darker Teal
  static const Color accent500 = Color(0xFF14B8A6); // Standard Teal
  static const Color accent400 = Color(0xFF2DD4BF); // Light Teal
  static const Color accent300 = Color(0xFF5EEAD4); // Lighter Teal

  // For convenience
  static const Color accent = accent500;
  static const Color accentDark = accent700;
  static const Color accentLight = accent400;

  // Splash Screen
  static const Color splashBackground = Color(0xFF0066FF); // Bright Blue

  // Secondary Colors (Slate) - Text, backgrounds, borders
  static const Color secondary900 = Color(0xFF0F172A); // Almost Black
  static const Color secondary600 = Color(0xFF475569); // Dark Slate
  static const Color secondary500 = Color(0xFF64748B); // Slate Gray
  static const Color secondary200 = Color(0xFFE2E8F0); // Light Slate
  static const Color secondary100 = Color(0xFFF1F5F9); // Very Light Slate

  // For backwards compatibility
  static const Color secondary = secondary500;
  static const Color secondaryDark = secondary600;
  static const Color secondaryLight = secondary200;

  // Status Colors
  // Success (Green) - Completion, positive states
  static const Color success700 = Color(0xFF047857); // Dark Green
  static const Color success500 = Color(0xFF10B981); // Green
  static const Color success100 = Color(0xFFDCFCE7); // Light Green
  static const Color success = success500;

  // Warning (Amber) - Alerts, pending states
  static const Color warning700 = Color(0xFFB45309); // Dark Amber
  static const Color warning500 = Color(0xFFF59E0B); // Amber
  static const Color warning = warning500;

  // Error (Red) - Destructive actions, errors
  static const Color error700 = Color(0xFFB91C1C); // Dark Red
  static const Color error500 = Color(0xFFEF4444); // Red
  static const Color error100 = Color(0xFFFEF3C7); // Light Red/Yellow
  static const Color error = error500;

  // Info (kept as primary blue)
  static const Color info = primary500;

  // Neutral Colors - From Design Pattern
  static const Color neutralWhite = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF8FAFC);
  static const Color neutral100 = Color(0xFFF1F5F9);
  static const Color neutral900 = Color(0xFF0F172A);

  // For backwards compatibility
  static const Color white = neutralWhite;
  static const Color black = neutral900;

  // Legacy grey colors (kept for backwards compatibility)
  static const Color grey50 = neutral50;
  static const Color grey100 = neutral100;
  static const Color grey200 = secondary200;
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = secondary500;
  static const Color grey600 = secondary600;
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey900 = secondary900;

  // Ticket Status Colors (using new color system)
  static const Color statusOpen = primary500; // Navy Blue
  static const Color statusInProgress = warning500; // Amber
  static const Color statusResolved = success500; // Green
  static const Color statusClosed = secondary500; // Slate
  static const Color statusCancelled = error500; // Red

  // Priority Colors (using new color system)
  static const Color priorityLow = success500; // Green
  static const Color priorityMedium = warning500; // Amber
  static const Color priorityHigh = Color(0xFFF97316); // Orange
  static const Color priorityUrgent = error500; // Red

  // Background Colors (using new neutral system)
  static const Color background = neutral50;
  static const Color surface = neutralWhite;
  static const Color scaffoldBackground = neutral100;

  // Text Colors (using new secondary system)
  static const Color textPrimary = secondary900; // Almost black
  static const Color textSecondary = secondary600; // Dark slate
  static const Color textDisabled = secondary500; // Slate
  static const Color textOnPrimary = neutralWhite;

  // Border Colors (using new secondary system)
  static const Color border = secondary200; // Light slate
  static const Color borderDark = secondary500; // Slate

  // Shadow Colors
  static const Color shadow = Color(0x1A000000);
}
