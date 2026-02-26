import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/utils/toast_helper.dart';
import '../../features/tickets/repositories/ticket_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ticket_provider.dart';
import 'offline_banner.dart';
import 'offline_page.dart';

/// Smart connectivity wrapper that handles offline mode gracefully:
/// - Logged in + offline → show content with an offline banner (user can browse cached data)
/// - Not logged in + offline → show dedicated offline page (cannot authenticate)
/// - Connection restored → auto-sync in background + hide banner
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper>
    with WidgetsBindingObserver {
  final ConnectivityService _connectivityService = ConnectivityService();
  StreamSubscription<bool>? _subscription;

  bool _isConnected = true;
  bool _isRetrying = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initConnectivity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkConnectivity();
    }
  }

  Future<void> _initConnectivity() async {
    // Listen for connectivity changes
    _subscription = _connectivityService.connectionStream.listen(
      _onConnectivityChanged,
    );

    // Small delay to ensure providers are ready
    await Future.delayed(const Duration(milliseconds: 800));

    // Wire up cache cleanup callback for logout
    _setupLogoutCacheCleanup();

    // Initial check
    await _checkConnectivity();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  /// Wire up the AuthProvider to clear local cache on logout
  void _setupLogoutCacheCleanup() {
    try {
      final authProvider = context.read<AuthProvider>();
      final ticketRepo = context.read<TicketRepository>();
      authProvider.setOnLogoutCallback(() {
        ticketRepo.localDatasource?.clearAllCache();
      });
    } catch (_) {
      // Providers not yet available, will be set up later
    }
  }

  void _onConnectivityChanged(bool isConnected) {
    if (!mounted) return;

    final wasConnected = _isConnected;

    setState(() {
      _isConnected = isConnected;
    });

    if (isConnected && !wasConnected) {
      // Connection restored → auto-sync
      _onConnectionRestored();
    } else if (!isConnected && wasConnected) {
      // Connection lost → check cache and show appropriate UI
      _onConnectionLost();
    }
  }

  Future<void> _checkConnectivity() async {
    final isConnected = await _connectivityService.checkConnectivity();

    if (mounted) {
      setState(() {
        _isConnected = isConnected;
      });
    }
  }

  void _onConnectionLost() {
    // No action needed — build() reactively shows banner/OfflinePage
  }

  void _onConnectionRestored() {
    _connectivityService.notifyConnectionRestored();

    // Auto-sync data in background
    _autoSync();

    if (mounted) {
      try {
        ToastHelper.showSuccess(
          context,
          'Back Online',
          description: 'Connection restored. Syncing data...',
        );
      } catch (_) {
        // Toast may fail on screens without Navigator (e.g., login)
      }
    }
  }

  /// Auto-sync data when connection is restored
  void _autoSync() {
    try {
      final ticketProvider = context.read<TicketProvider>();
      // Refresh home data (stats + recent tickets)
      ticketProvider.loadHomeData();
      // Refresh categories and statuses
      ticketProvider.loadCategories();
      ticketProvider.loadStatuses();
    } catch (_) {
      // Silently fail — data will sync on next manual navigation
    }
  }

  Future<void> _onRetry() async {
    if (_isRetrying) return;

    setState(() {
      _isRetrying = true;
    });

    final isConnected = await _connectivityService.checkConnectivity();

    if (mounted) {
      setState(() {
        _isConnected = isConnected;
        _isRetrying = false;
      });

      if (isConnected) {
        _onConnectionRestored();
      } else {
        try {
          ToastHelper.showError(
            context,
            'No Connection',
            description: 'Still no internet connection. Please try again.',
          );
        } catch (_) {
          // Toast may fail on screens without Navigator (e.g., login)
          // The "No Internet Connection" overlay is already visible
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Not initialized yet — show the app normally
    if (!_isInitialized) {
      return widget.child;
    }

    // Watch auth state reactively — rebuilds when auth changes (e.g., logout)
    final isLoggedIn = _checkIsLoggedIn(context);

    // Offline + not logged in → show full offline page
    if (!_isConnected && !isLoggedIn) {
      return OfflinePage(onRetry: _onRetry, isRetrying: _isRetrying);
    }

    // Online or Offline with logged in → show app content with optional banner
    return Column(
      children: [
        // Offline banner slides in/out
        OfflineBanner(
          isVisible: !_isConnected && isLoggedIn,
          onRetry: _onRetry,
        ),
        // App content
        Expanded(child: widget.child),
      ],
    );
  }

  /// Check auth state reactively using context.watch
  bool _checkIsLoggedIn(BuildContext context) {
    try {
      final authProvider = context.watch<AuthProvider>();
      return authProvider.isAuthenticated;
    } catch (_) {
      return false;
    }
  }
}
