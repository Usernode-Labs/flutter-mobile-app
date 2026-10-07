import 'package:flutter/foundation.dart';

/// Whether the screen holding the platform web view shrinks it to end at the
/// on-screen keyboard (the `Scaffold`'s `resizeToAvoidBottomInset`).
///
/// Not on iOS. Flutter animates the keyboard's inset frame by frame, so a
/// resizing `Scaffold` gave the `WKWebView` a new frame on every frame of the
/// keyboard's rise, and WebKit lays the page out again behind each one. A
/// sheet fixed to the foot of the page (the web shell's sign-in sheet) was
/// measured in the iOS simulator jumping to its final place, vanishing,
/// coming back low, then high, then easing up: four movements in half a
/// second. Unresized, `WKWebView` makes room for the keys itself as Safari
/// does (the keys cover the page and the visual viewport shrinks), which the
/// web shell already handles, and the same sheet rose with the keys in one
/// movement.
///
/// Android keeps the resize: its `WebView` makes no room for the keyboard of
/// its own.
bool webViewResizesForKeyboard(TargetPlatform platform) =>
    platform != TargetPlatform.iOS;
