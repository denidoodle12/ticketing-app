import 'package:package_info_plus/package_info_plus.dart';

/// Utility class to get app information dynamically
class AppInfo {
  static PackageInfo? _packageInfo;

  /// Initialize package info - call this in main.dart
  static Future<void> init() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  /// Get app version (e.g., "0.1.0")
  static String get version => _packageInfo?.version ?? '0.0.0';

  /// Get build number (e.g., "1")
  static String get buildNumber => _packageInfo?.buildNumber ?? '0';

  /// Get full version string (e.g., "0.1.0+1")
  static String get fullVersion => '$version+$buildNumber';

  /// Get app name
  static String get appName => _packageInfo?.appName ?? 'Ticketing App';

  /// Get package name
  static String get packageName => _packageInfo?.packageName ?? '';
}
