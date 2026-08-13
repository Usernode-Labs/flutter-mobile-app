import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Captures the currently visible native app window for trusted Social UI.
///
/// Android and iOS own the actual pixel capture. Keeping the byte validation
/// here gives the WebView bridge the same one-image, 4 MB contract as the
/// feedback upload endpoint before a large payload is base64-encoded into JS.
class NativeScreenCapture {
  const NativeScreenCapture();

  static const channelName = 'com.usernode.app/screenshot';
  static const maxUploadBytes = 4 * 1024 * 1024;
  static const MethodChannel _channel = MethodChannel(channelName);

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<Map<String, String>> capture() async {
    final bytes = await _channel.invokeMethod<Uint8List>('capture');
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Native screen capture returned no image');
    }
    if (bytes.lengthInBytes > maxUploadBytes) {
      throw StateError('Native screen capture exceeds the upload limit');
    }
    return {'contentType': 'image/jpeg', 'base64': base64Encode(bytes)};
  }
}
