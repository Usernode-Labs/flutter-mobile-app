import Flutter
import ObjectiveC.runtime
import UIKit
import WebKit
import webview_flutter_wkwebview

/// Native side of the `com.onhomeroom.app/webview_keyboard` MethodChannel.
///
/// While a field is focused in a `WKWebView`, iOS draws WebKit's form
/// accessory bar above the keyboard: previous/next chevrons and a Done
/// checkmark. Native apps don't have one, so the platform's web views drop it
/// and the page gets that height back.
///
/// WebKit has no public switch for the bar. The web view's first responder
/// while a field is focused is its private `WKContentView`, which answers
/// UIKit's `inputAccessoryView` query with the bar. `hideBar(in:)` re-classes
/// that one content view to a runtime subclass whose `inputAccessoryView` is
/// nil (the per-instance technique react-native-webview's
/// `hideKeyboardAccessoryView` uses), so any other `WKWebView` in the process
/// keeps its bar. If a future WebKit renames the content view, nothing is
/// changed and the bar simply stays.
///
/// What still shows: the keyboard's own predictive (QuickType) row, which is
/// where iOS offers Passwords and AutoFill suggestions, because it belongs to
/// the keyboard rather than to the accessory view.
enum WebViewFormAccessory {
  static let channelName = "com.onhomeroom.app/webview_keyboard"

  /// Suffix of the runtime subclass; also how an already-hidden view is
  /// recognised, even after KVO re-classes it again.
  static let subclassSuffix = "_HomeroomNoFormAccessory"

  /// Handles `hideFormAccessoryBar` with `{webViewIdentifier: Int}`, the Dart
  /// `WebKitWebViewController.webViewIdentifier`. Answers whether the bar is
  /// now hidden for that web view.
  static func makeChannel(
    binaryMessenger: FlutterBinaryMessenger,
    pluginRegistry: FlutterPluginRegistry
  ) -> FlutterMethodChannel {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { [weak pluginRegistry] call, result in
      guard call.method == "hideFormAccessoryBar" else {
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
      result(hideBar(in: webView))
    }
    return channel
  }

  /// Hides the form accessory bar for `webView` only. Idempotent; returns
  /// false (and changes nothing) when the content view can't be found.
  @discardableResult
  static func hideBar(in webView: WKWebView) -> Bool {
    guard let contentView = contentView(of: webView) else { return false }
    if isHidden(contentView) { return true }
    guard let currentClass = object_getClass(contentView),
          let subclass = noAccessorySubclass(of: currentClass) else {
      return false
    }
    object_setClass(contentView, subclass)
    if contentView.isFirstResponder {
      contentView.reloadInputViews()
    }
    return true
  }

  /// The web view's `WKContentView`: a direct subview of its scroll view on
  /// every iOS this app supports, with a tree search as a fallback.
  private static func contentView(of webView: WKWebView) -> UIView? {
    guard let contentViewClass = NSClassFromString("WKContentView") else { return nil }
    if let direct = webView.scrollView.subviews.first(where: { $0.isKind(of: contentViewClass) }) {
      return direct
    }
    var queue: [UIView] = [webView]
    while !queue.isEmpty {
      let view = queue.removeFirst()
      if view.isKind(of: contentViewClass) { return view }
      queue.append(contentsOf: view.subviews)
    }
    return nil
  }

  private static func isHidden(_ view: UIView) -> Bool {
    var cls: AnyClass? = object_getClass(view)
    while let current = cls {
      if NSStringFromClass(current).hasSuffix(subclassSuffix) { return true }
      cls = class_getSuperclass(current)
    }
    return false
  }

  /// A subclass of `base` (registered once per base class) whose
  /// `inputAccessoryView` is nil. Everything else, including the input view,
  /// text selection and autofill, is inherited unchanged.
  private static func noAccessorySubclass(of base: AnyClass) -> AnyClass? {
    let name = NSStringFromClass(base) + subclassSuffix
    if let existing = NSClassFromString(name) { return existing }
    let selector = #selector(getter: UIResponder.inputAccessoryView)
    guard let inherited = class_getInstanceMethod(base, selector),
          let subclass = objc_allocateClassPair(base, name, 0) else {
      return nil
    }
    let noAccessory: @convention(block) (AnyObject) -> UIView? = { _ in nil }
    class_addMethod(
      subclass,
      selector,
      imp_implementationWithBlock(noAccessory),
      method_getTypeEncoding(inherited)
    )
    objc_registerClassPair(subclass)
    return subclass
  }
}
