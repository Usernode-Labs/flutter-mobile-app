import Flutter
import WebKit
import webview_flutter_wkwebview

/// Native side of the `com.onhomeroom.app/webkit_cookie_partitioning`
/// MethodChannel.
///
/// Private apps open in a cross-site frame (`<slug>.onhomeroom.app` inside
/// `app.onhomeroom.com`), where the only cookie WebKit keeps is a partitioned
/// one (CHIPS: `SameSite=None; Secure; Partitioned`). The platform's app gate
/// sets that cookie when the frame first loads and expects it back on every
/// later request.
///
/// WebKit before 315043@main ("Partitioned cookies may not be sent on
/// resource requests", https://bugs.webkit.org/show_bug.cgi?id=316066) applies
/// that setting to its network process only from
/// `WebsiteDataStore::propagateSettingUpdates()`, which returns early while
/// the network process does not exist yet. None of WebKit's 7623.x or 7624.x
/// release tags (the iOS 26.2 to 26.x line) has the fix. In an app with one
/// web view, the page can be registered before that process starts, and
/// nothing calls the function again. Third-party cookie blocking then stays
/// at "all" instead of "all except partitioned", the partitioned cookie is
/// never stored, and the frame shows the gate's "can't open here" page.
/// Safari on the same iOS 26.2 keeps the cookie.
///
/// WebKit also runs the function whenever a page is added to a web process.
/// `refresh(sharing:)` adds one: a throwaway `WKWebView` on the same data
/// store, released straight away, which loads nothing. Nothing about the
/// platform web view changes: not its configuration, its page or its bridge.
/// Where WebKit already has the fix, the extra page changes nothing.
enum WebKitCookiePartitioning {
  static let channelName = "com.onhomeroom.app/webkit_cookie_partitioning"

  /// Handles `refreshCookiePartitioning` with `{webViewIdentifier: Int}`,
  /// the Dart `WebKitWebViewController.webViewIdentifier`. Answers whether a
  /// refresh was made for that web view's data store.
  static func makeChannel(
    binaryMessenger: FlutterBinaryMessenger,
    pluginRegistry: FlutterPluginRegistry
  ) -> FlutterMethodChannel {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { [weak pluginRegistry] call, result in
      guard call.method == "refreshCookiePartitioning" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let identifier = (args["webViewIdentifier"] as? NSNumber)?.int64Value else {
        result(FlutterError(
          code: "invalid_args",
          message: "webViewIdentifier is required",
          details: nil
        ))
        return
      }
      // The plugin's supported lookup from a Dart identifier to its WKWebView.
      guard let pluginRegistry,
            let webView = FWFWebViewFlutterWKWebViewExternalAPI.webView(
              forIdentifier: identifier,
              withPluginRegistry: pluginRegistry
            ) else {
        result(false)
        return
      }
      refresh(sharing: webView)
      result(true)
    }
    return channel
  }

  /// Makes WebKit send its current cookie partitioning setting for
  /// `webView`'s data store to the network process. Call it once the web
  /// view has started a navigation, so that its page is registered and the
  /// network process exists.
  static func refresh(sharing webView: WKWebView) {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = webView.configuration.websiteDataStore
    // Matches the platform web view, so the throwaway one never stands out
    // from the app's App-Bound Domains choice.
    configuration.limitsNavigationsToAppBoundDomains =
      webView.configuration.limitsNavigationsToAppBoundDomains
    let throwaway = WKWebView(frame: .zero, configuration: configuration)
    // Creating it registered its page, which is what runs the update.
    // Releasing it on the next turn removes the page again.
    DispatchQueue.main.async { withExtendedLifetime(throwaway) {} }
  }
}
