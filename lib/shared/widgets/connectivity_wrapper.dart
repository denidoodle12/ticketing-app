import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/utils/toast_helper.dart';
import '../../routes/app_routes.dart';
import 'no_internet_dialog.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({
    super.key,
    required this.child,
  });

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> with WidgetsBindingObserver {
  final ConnectivityService _connectivityService = ConnectivityService();
  StreamSubscription<bool>? _subscription;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initConnectivity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndShowDialog();
    }
  }

  Future<void> _initConnectivity() async {
    // Listen for connectivity changes from service
    _subscription = _connectivityService.connectionStream.listen((isConnected) {
      if (!isConnected && !_isDialogShowing) {
        _showNoInternetDialog();
      } else if (isConnected && _isDialogShowing) {
        _hideNoInternetDialog();
      }
    });

    // Small delay to ensure navigator is ready, then do initial check
    await Future.delayed(const Duration(milliseconds: 800));
    await _checkAndShowDialog();
  }

  Future<void> _checkAndShowDialog() async {
    final isConnected = await _connectivityService.checkConnectivity();

    if (!isConnected && !_isDialogShowing) {
      _showNoInternetDialog();
    } else if (isConnected && _isDialogShowing) {
      _hideNoInternetDialog();
    }
  }

  void _showNoInternetDialog() {
    final navigatorContext = AppRoutes.navigatorKey.currentContext;

    if (navigatorContext == null || _isDialogShowing) return;

    _isDialogShowing = true;

    showDialog(
      context: navigatorContext,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: NoInternetDialog(
          onRefresh: () async {
            final isNowConnected = await _connectivityService.checkConnectivity();

            if (isNowConnected) {
              _connectivityService.notifyConnectionRestored();
              _hideNoInternetDialog();
            } else {
              if (dialogContext.mounted) {
                ToastHelper.showError(
                  dialogContext,
                  'No Connection',
                  description: 'Still no internet connection. Please try again.',
                );
              }
            }
          },
        ),
      ),
    ).then((_) {
      _isDialogShowing = false;
      // If still no connection, show dialog again
      if (!_connectivityService.isConnected) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _showNoInternetDialog();
        });
      }
    });
  }

  void _hideNoInternetDialog() {
    if (!_isDialogShowing) return;

    final navigatorState = AppRoutes.navigatorKey.currentState;
    if (navigatorState != null && navigatorState.canPop()) {
      navigatorState.pop();
      _isDialogShowing = false;
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
    return widget.child;
  }
}
