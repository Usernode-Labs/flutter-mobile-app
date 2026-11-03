import 'dart:convert';

import 'package:flutter/widgets.dart';

/// The status bar and navigation bar heights the platform page should keep
/// clear, in logical pixels (the same unit as a web view's CSS pixels).
///
/// The page runs edge to edge under both bars and reserves their height itself,
/// reading `--un-safe-inset-top` and `--un-safe-inset-bottom` with
/// `env(safe-area-inset-*)` as the fallback. An Android `WebView` older than
/// Chrome 135 can report those `env()` values as 0, and has no
/// `safe-area-max-inset-*` for the web shell to fall back on, so the header
/// sits under the clock and the gesture pill crosses the tab labels. Flutter
/// knows the real heights on every WebView version, so it hands them over.
@immutable
class WebViewSystemBarInsets {
  const WebViewSystemBarInsets({required this.top, required this.bottom});

  final double top;
  final double bottom;

  @override
  bool operator ==(Object other) =>
      other is WebViewSystemBarInsets &&
      other.top == top &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(top, bottom);
}

/// The insets to hand the page, or null where it needs none.
///
/// Null off Android: `WKWebView` reports `env()` correctly, so iOS stays as it
/// is. The bottom comes from [padding], which is 0 while the keyboard is up.
/// Android resizes the web view to end at the keyboard, so the navigation bar
/// is no longer under the page then.
WebViewSystemBarInsets? webViewSystemBarInsetsFor(
  TargetPlatform platform, {
  required EdgeInsets viewPadding,
  required EdgeInsets padding,
}) {
  if (platform != TargetPlatform.android) return null;
  return WebViewSystemBarInsets(top: viewPadding.top, bottom: padding.bottom);
}

/// The script that writes [insets] onto the page's `<html>` element. An inline
/// value wins over the web shell's stylesheet rule for the same variable.
///
/// A zero removes the variable instead of writing `0px`: it means Flutter has
/// nothing to add (a bar that is hidden, or a keyboard that is up), and the
/// page's own `env()` fallback should decide.
String webViewSystemBarInsetsScript(WebViewSystemBarInsets insets) {
  final values = jsonEncode({
    '--un-safe-inset-top': _cssLength(insets.top),
    '--un-safe-inset-bottom': _cssLength(insets.bottom),
  });
  return '''
    (function () {
      var root = document.documentElement;
      if (!root) return;
      var values = $values;
      Object.keys(values).forEach(function (name) {
        if (values[name]) {
          root.style.setProperty(name, values[name]);
        } else {
          root.style.removeProperty(name);
        }
      });
    })();
  ''';
}

String? _cssLength(double logicalPixels) =>
    logicalPixels > 0 ? '${logicalPixels.toStringAsFixed(2)}px' : null;
