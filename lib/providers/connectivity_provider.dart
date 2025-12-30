import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isConnected = true;
  bool _isInitialized = false;

  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;

  ConnectivityProvider() {
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
      _isInitialized = true;
      notifyListeners();

      _subscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectionStatus,
      );
    } catch (e) {
      _isConnected = true;
      _isInitialized = true;
      notifyListeners();
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final wasConnected = _isConnected;
    _isConnected = result.isNotEmpty &&
                   !result.contains(ConnectivityResult.none);

    if (wasConnected != _isConnected) {
      notifyListeners();
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
      return _isConnected;
    } catch (e) {
      return true;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
