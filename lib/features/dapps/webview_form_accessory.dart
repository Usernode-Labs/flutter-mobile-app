import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// Hides the bar iOS draws above the keyboard while a web page field is
/// focused (previous/next chevrons and a Done checkmark), so the platform's
/// web view gets that height back. Native apps don't show one.
///
/// WebKit has no public option for it; `ios/Runner/WebViewFormAccessory.swift`
/// removes it from the one `WKWebView` named here. The keyboard's QuickType
/// row, with its Passwords/AutoFill suggestions, is part of the keyboard and
/// stays. Android's WebView draws no such bar, so this is iOS-only.
class WebViewFormAccessory {
  const WebViewFormAccessory();

  static const channelName = 'com.onhomeroom.app/webview_keyboard';
  static const MethodChannel _channel = MethodChannel(channelName);

  /// Hides the bar for [controller]'s web view. Resolves to whether it is now
  /// hidden; a failure leaves the bar in place and never throws.
  Future<bool> hideFor(WebViewController controller) async {
    final platformController = controller.platform;
    if (platformController is! WebKitWebViewController) return false;
    return hideForWebView(platformController.webViewIdentifier);
  }

  /// Hides the bar for the `WKWebView` with this
  /// `WebKitWebViewController.webViewIdentifier`.
  @visibleForTesting
  Future<bool> hideForWebView(int webViewIdentifier) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      final hidden = await _channel.invokeMethod<bool>(
        'hideFormAccessoryBar',
        {'webViewIdentifier': webViewIdentifier},
      );
      if (hidden != true) {
        debugPrint('[webview] keyboard accessory bar left in place');
      }
      return hidden ?? false;
    } on PlatformException catch (error) {
      debugPrint('[webview] keyboard accessory bar not hidden: $error');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
