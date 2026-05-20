import 'dart:async';

import 'package:flutter/widgets.dart';

import '../network/connectivity_service.dart';

/// Centralised connectivity tracking for screens that need to react to
/// online/offline transitions.
///
/// Before this mixin existed, every screen with offline awareness was
/// declaring the same `StreamSubscription`, the same `_isOffline` flag, and
/// the same listener body — 12+ near-identical copies of the connectivity
/// boilerplate. Mixing this in collapses all of that into the
/// implementation below.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen>
///     with OfflineAwareStateMixin<MyScreen> {
///   @override
///   void onConnectionRestored() => _refresh();
/// }
/// ```
///
/// The mixin reads the current connection from [ConnectivityService] on
/// `initState`, subscribes to its `connectionStream` (which emits `true`
/// when connected, `false` when offline), and toggles [isOffline] only on
/// genuine transitions so consumers don't rebuild unnecessarily.
mixin OfflineAwareStateMixin<T extends StatefulWidget> on State<T> {
  late final StreamSubscription<bool> _connectivitySubscription;
  bool _isOffline = false;

  /// Whether the device is currently considered offline.
  bool get isOffline => _isOffline;

  @override
  void initState() {
    super.initState();
    _isOffline = !ConnectivityService().isConnected;
    _connectivitySubscription =
        ConnectivityService().connectionStream.listen(_handleChange);
  }

  void _handleChange(bool isConnected) {
    final offline = !isConnected;
    if (offline == _isOffline) return;
    if (!mounted) return;

    setState(() => _isOffline = offline);
    if (!offline) onConnectionRestored();
  }

  /// Called once whenever the device transitions from offline → online.
  ///
  /// Override to refetch data, retry an in-flight request, etc. Default is
  /// a no-op so screens that only care about the offline indicator don't
  /// need to override anything.
  void onConnectionRestored() {}

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }
}
