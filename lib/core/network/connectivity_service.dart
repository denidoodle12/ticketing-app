import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Global connectivity service for checking and waiting for internet connection
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final _connectionController = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isConnected = true;
  Completer<void>? _waitingCompleter;

  bool get isConnected => _isConnected;
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Initialize the service - call this once at app startup
  Future<void> initialize() async {
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);

    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    _isConnected = result.isNotEmpty && !result.contains(ConnectivityResult.none);

    _connectionController.add(_isConnected);

    // If connection restored and someone is waiting, complete the future
    if (_isConnected && _waitingCompleter != null && !_waitingCompleter!.isCompleted) {
      _waitingCompleter!.complete();
      _waitingCompleter = null;
    }
  }

  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _isConnected = result.isNotEmpty && !result.contains(ConnectivityResult.none);
    _connectionController.add(_isConnected);
    return _isConnected;
  }

  /// Wait until internet connection is available
  /// Returns immediately if already connected
  Future<void> waitForConnection() async {
    // Check current status first
    await checkConnectivity();

    if (_isConnected) return;

    // Create a completer to wait for connection
    _waitingCompleter = Completer<void>();
    return _waitingCompleter!.future;
  }

  /// Notify that connection is restored (called from UI when user confirms)
  void notifyConnectionRestored() {
    if (_waitingCompleter != null && !_waitingCompleter!.isCompleted) {
      _waitingCompleter!.complete();
      _waitingCompleter = null;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _connectionController.close();
  }
}
