import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// Makes WebKit apply its partitioned-cookie (CHIPS) setting to the platform
/// web view, so a private app framed from another site can keep the access
/// cookie the app gate sets for it.
///
/// On iOS 26, WebKit can leave an app's only web view blocking every
/// third-party cookie, partitioned ones included, and the app then shows
/// "can't open here" inside Homeroom. `ios/Runner/WebKitCookiePartitioning.swift`
/// explains the WebKit bug and what the native side does about it. Call this
/// each time the web view starts a main-frame navigation. Android's WebView
/// is not affected, so this is iOS-only.
class WebKitCookiePartitioning {
  const WebKitCookiePartitioning();

  static const channelName = 'com.onhomeroom.app/webkit_cookie_partitioning';
  static const MethodChannel _channel = MethodChannel(channelName);

  /// Refreshes the setting for [controller]'s web view. Resolves to whether
  /// native made the refresh; a failure changes nothing and never throws.
  Future<bool> refreshFor(WebViewController controller) async {
    final platformController = controller.platform;
    if (platformController is! WebKitWebViewController) return false;
    return refreshForWebView(platformController.webViewIdentifier);
  }

  /// Refreshes the setting for the `WKWebView` with this
  /// `WebKitWebViewController.webViewIdentifier`.
  @visibleForTesting
  Future<bool> refreshForWebView(int webViewIdentifier) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      final refreshed = await _channel.invokeMethod<bool>(
        'refreshCookiePartitioning',
        {'webViewIdentifier': webViewIdentifier},
      );
      if (refreshed != true) {
        debugPrint('[webview] cookie partitioning setting not refreshed');
      }
      return refreshed ?? false;
    } on PlatformException catch (error) {
      debugPrint('[webview] cookie partitioning setting not refreshed: $error');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
