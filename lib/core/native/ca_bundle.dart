import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Extracts the CA bundle (cacert.pem) from Flutter assets to the filesystem.
///
/// Native C++ (libcurl) cannot read Flutter assets directly — they live inside
/// the APK archive. This helper copies the bundle to the app's support directory
/// so we can pass a real filesystem path to curl's CURLOPT_CAINFO.
class CaBundle {
  CaBundle._();

  static String? _cachedPath;

  /// Returns the filesystem path to cacert.pem, extracting it if needed.
  ///
  /// The file is cached — subsequent calls skip the copy if the file exists.
  static Future<String> ensureExtracted() async {
    if (_cachedPath != null && File(_cachedPath!).existsSync()) {
      return _cachedPath!;
    }

    final dir = await getApplicationSupportDirectory();
    final outFile = File('${dir.path}/cacert.pem');

    if (!outFile.existsSync()) {
      debugPrint('[CaBundle] extracting cacert.pem → ${outFile.path}');
      final data = await rootBundle.load('assets/certs/cacert.pem');
      await outFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      debugPrint('[CaBundle] extracted (${data.lengthInBytes} bytes)');
    } else {
      debugPrint('[CaBundle] already exists at ${outFile.path}');
    }

    _cachedPath = outFile.path;
    return _cachedPath!;
  }
}
