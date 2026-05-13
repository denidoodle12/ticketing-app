import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

/// FFI typedefs for native C functions in libjavaloader.so
///
/// Native signatures:
///   void ffi_sse_start(const char* url, const char* token,
///                      const char* ca_bundle_path,
///                      sse_event_cb on_event, sse_status_cb on_status);
///   void ffi_sse_stop();
///   void ffi_sse_update_token(const char* token);
///   int  ffi_sse_is_running();

// ── Native function types (C signatures) ──
typedef _SseStartNative = Void Function(
  Pointer<Utf8> url,
  Pointer<Utf8> token,
  Pointer<Utf8> caBundle,
  Pointer<NativeFunction<Void Function(Pointer<Utf8>, Pointer<Utf8>)>> onEvent,
  Pointer<NativeFunction<Void Function(Int32, Pointer<Utf8>)>> onStatus,
);
typedef _SseStopNative = Void Function();
typedef _SseUpdateTokenNative = Void Function(Pointer<Utf8> token);
typedef _SseIsRunningNative = Int32 Function();

// ── Dart function types ──
typedef _SseStartDart = void Function(
  Pointer<Utf8> url,
  Pointer<Utf8> token,
  Pointer<Utf8> caBundle,
  Pointer<NativeFunction<Void Function(Pointer<Utf8>, Pointer<Utf8>)>> onEvent,
  Pointer<NativeFunction<Void Function(Int32, Pointer<Utf8>)>> onStatus,
);
typedef _SseStopDart = void Function();
typedef _SseUpdateTokenDart = void Function(Pointer<Utf8> token);
typedef _SseIsRunningDart = int Function();

/// SSE connection status codes (matches SseStatus enum in javaloader.cpp)
enum NativeSseStatus {
  connecting(1),
  connected(2),
  disconnected(3),
  reconnecting(4),
  unauthorized(5),
  fatal(6);

  final int code;
  const NativeSseStatus(this.code);

  static NativeSseStatus fromCode(int code) {
    return NativeSseStatus.values.firstWhere(
      (s) => s.code == code,
      orElse: () => NativeSseStatus.disconnected,
    );
  }
}

/// Dart wrapper around libjavaloader.so native SSE implementation.
///
/// Uses dart:ffi + NativeCallable.listener for async callbacks from the
/// native worker thread.
///
/// IMPORTANT: The native side strdup()'s the callback strings onto the heap.
/// The Dart trampoline MUST malloc.free() them after converting to Dart strings
/// to avoid memory leaks.
class NativeSse {
  NativeSse._();
  static final NativeSse _instance = NativeSse._();
  static NativeSse get instance => _instance;

  late final DynamicLibrary _lib;
  late final _SseStartDart _ffiStart;
  late final _SseStopDart _ffiStop;
  late final _SseUpdateTokenDart _ffiUpdateToken;
  late final _SseIsRunningDart _ffiIsRunning;

  bool _loaded = false;

  // Callbacks
  void Function(String event, String data)? _onEvent;
  void Function(NativeSseStatus status, String? info)? _onStatus;

  // NativeCallable references (must be kept alive)
  NativeCallable<Void Function(Pointer<Utf8>, Pointer<Utf8>)>?
      _nativeEventCallable;
  NativeCallable<Void Function(Int32, Pointer<Utf8>)>? _nativeStatusCallable;

  /// Load the native library. Safe to call multiple times.
  void _ensureLoaded() {
    if (_loaded) return;

    if (!Platform.isAndroid) {
      debugPrint('[NativeSse] Only supported on Android');
      return;
    }

    _lib = DynamicLibrary.open('libjavaloader.so');

    _ffiStart = _lib
        .lookupFunction<_SseStartNative, _SseStartDart>('ffi_sse_start');
    _ffiStop =
        _lib.lookupFunction<_SseStopNative, _SseStopDart>('ffi_sse_stop');
    _ffiUpdateToken = _lib.lookupFunction<_SseUpdateTokenNative,
        _SseUpdateTokenDart>('ffi_sse_update_token');
    _ffiIsRunning = _lib.lookupFunction<_SseIsRunningNative,
        _SseIsRunningDart>('ffi_sse_is_running');

    _loaded = true;
    debugPrint('[NativeSse] library loaded');
  }

  /// Whether the native SSE worker thread is currently running.
  bool get isRunning {
    if (!_loaded) return false;
    return _ffiIsRunning() == 1;
  }

  /// Start the native SSE stream.
  ///
  /// [url] — Full SSE endpoint URL (e.g. `https://example.com/notifications/stream`)
  /// [token] — Bearer access token
  /// [caBundlePath] — Filesystem path to cacert.pem (extracted from assets)
  /// [onEvent] — Called when an SSE event is dispatched (event name + JSON data)
  /// [onStatus] — Called when connection status changes
  void start({
    required String url,
    required String token,
    required String caBundlePath,
    required void Function(String event, String data) onEvent,
    required void Function(NativeSseStatus status, String? info) onStatus,
  }) {
    _ensureLoaded();
    if (!_loaded) return;

    if (isRunning) {
      debugPrint('[NativeSse] already running; updating token instead');
      updateToken(token);
      return;
    }

    _onEvent = onEvent;
    _onStatus = onStatus;

    // Create NativeCallable.listener for async callbacks from native thread
    _nativeEventCallable?.close();
    _nativeStatusCallable?.close();

    _nativeEventCallable =
        NativeCallable<Void Function(Pointer<Utf8>, Pointer<Utf8>)>.listener(
      _trampolineEvent,
    );

    _nativeStatusCallable =
        NativeCallable<Void Function(Int32, Pointer<Utf8>)>.listener(
      _trampolineStatus,
    );

    final urlPtr = url.toNativeUtf8();
    final tokenPtr = token.toNativeUtf8();
    final caPtr = caBundlePath.toNativeUtf8();

    debugPrint('[NativeSse] starting: url=$url, caPath=$caBundlePath');

    _ffiStart(
      urlPtr,
      tokenPtr,
      caPtr,
      _nativeEventCallable!.nativeFunction,
      _nativeStatusCallable!.nativeFunction,
    );

    // Free the Dart-allocated argument strings (native has already copied them)
    malloc.free(urlPtr);
    malloc.free(tokenPtr);
    malloc.free(caPtr);
  }

  /// Update the bearer token for the running SSE connection.
  /// The native side will use this on the next reconnect cycle.
  void updateToken(String token) {
    if (!_loaded) return;
    final ptr = token.toNativeUtf8();
    _ffiUpdateToken(ptr);
    malloc.free(ptr);
    debugPrint('[NativeSse] token updated');
  }

  /// Stop the native SSE worker thread.
  void stop() {
    if (!_loaded) return;
    debugPrint('[NativeSse] stopping...');
    _ffiStop();
    _nativeEventCallable?.close();
    _nativeStatusCallable?.close();
    _nativeEventCallable = null;
    _nativeStatusCallable = null;
    _onEvent = null;
    _onStatus = null;
    debugPrint('[NativeSse] stopped');
  }

  // ── Trampoline callbacks (called from native thread via message port) ──

  /// Event trampoline: native strdup()'d the strings → we must malloc.free()
  static void _trampolineEvent(Pointer<Utf8> eventPtr, Pointer<Utf8> dataPtr) {
    String evt = '';
    String dta = '';

    if (eventPtr != nullptr) {
      evt = eventPtr.toDartString();
      malloc.free(eventPtr);
    }
    if (dataPtr != nullptr) {
      dta = dataPtr.toDartString();
      malloc.free(dataPtr);
    }

    _instance._onEvent?.call(evt, dta);
  }

  /// Status trampoline: native strdup()'d the info string → we must malloc.free()
  static void _trampolineStatus(int statusCode, Pointer<Utf8> infoPtr) {
    String? info;
    if (infoPtr != nullptr) {
      info = infoPtr.toDartString();
      malloc.free(infoPtr);
      if (info.isEmpty) info = null;
    }

    final status = NativeSseStatus.fromCode(statusCode);
    _instance._onStatus?.call(status, info);
  }
}
