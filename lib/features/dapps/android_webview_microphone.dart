import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Installs the Android microphone gate before the WebView loads a document.
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
      return await _channel.invokeMethod<bool>('configure', {
            'webViewIdentifier': webViewIdentifier,
            'trustedOrigin': trustedOrigin,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
