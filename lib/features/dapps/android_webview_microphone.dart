import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Installs the Android microphone gate on a WebView before it loads a document.
///
/// The pinned WebView package's Dart permission callback omits the requesting
/// origin. Native code checks it directly, including for cross-origin frames.
class AndroidWebViewMicrophone {
  const AndroidWebViewMicrophone();

  static const channelName = 'com.onhomeroom.app/webview_microphone';
  static const MethodChannel _channel = MethodChannel(channelName);

  Future<bool> configure(
    AndroidWebViewController controller, {
    required String trustedOrigin,
  }) =>
      configureForWebView(controller.webViewIdentifier,
          trustedOrigin: trustedOrigin);

  @visibleForTesting
  Future<bool> configureForWebView(
    int webViewIdentifier, {
    required String trustedOrigin,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final configured = await _channel.invokeMethod<bool>('configure', {
            'webViewIdentifier': webViewIdentifier,
            'trustedOrigin': trustedOrigin,
          }) ??
          false;
      if (!configured) {
        debugPrint('[webview microphone] not configured; dictation is off');
      }
      return configured;
    } on PlatformException catch (e) {
      debugPrint('[webview microphone] configure failed: $e');
      return false;
    } on MissingPluginException catch (e) {
      debugPrint('[webview microphone] configure failed: $e');
      return false;
    }
  }
}
