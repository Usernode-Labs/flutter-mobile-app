import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The orientations the app allows, chosen by the screen it is on.
///
/// The app was portrait-only, and on a phone it still is. An iPhone Duo's
/// inner display is 669x951pt, and held sideways it stayed portrait on the
/// iOS 27.1 simulator: the whole page ran sideways across it. (A real Duo
/// rotated anyway, so iOS does not always honour the lock on that display;
/// the app should not depend on that.) Folded, the cover is 466x678pt and is
/// a phone again.
///
/// So the rule follows the space, not the model: a screen whose short side is
/// [largeScreenShortestSide] or more turns with the device; anything smaller
/// stays portrait. Re-checked whenever the screen's size changes, which is
/// what folding, unfolding and Split View do. iOS only: Android's manifest
/// keeps the activity portrait, and a preference set here would override it.
const double largeScreenShortestSide = 600;

const List<DeviceOrientation> portraitOnly = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
];

const List<DeviceOrientation> anyOrientation = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// The orientations for a screen of [logicalSize] on [platform].
List<DeviceOrientation> orientationsFor(
    Size logicalSize, TargetPlatform platform) {
  if (platform != TargetPlatform.iOS) return portraitOnly;
  return logicalSize.shortestSide >= largeScreenShortestSide
      ? anyOrientation
      : portraitOnly;
}

/// Where the iOS side of [OrientationPolicy] asks UIKit to read the list
/// again (ios/Runner/OrientationChannel.swift).
const MethodChannel orientationChannel =
    MethodChannel('com.onhomeroom.app/orientation');

/// How long the screen has to stay put after the list changes before UIKit is
/// asked to read it again.
const Duration orientationSettleDelay = Duration(milliseconds: 500);

/// Applies [orientationsFor] at launch and again whenever the screen changes.
///
/// Flutter hands a new list to UIKit once. When that lands while the scene is
/// moving from the cover to the inner display, UIKit keeps the portrait it read
/// before until the app next comes back from the background: unfolded, the app
/// stayed portrait until a trip home (flutter-mobile-app#635). Sending the same
/// list again does nothing, because Flutter skips a list it already has. So on
/// iOS, once the screen has gone [orientationSettleDelay] without changing
/// after a new list, [orientationChannel] asks UIKit to read it again.
final class OrientationPolicy with WidgetsBindingObserver {
  OrientationPolicy._();

  /// A policy of its own, so a test starts from nothing applied.
  @visibleForTesting
  OrientationPolicy.forTesting();

  static final OrientationPolicy instance = OrientationPolicy._();

  List<DeviceOrientation>? _applied;
  bool _started = false;
  Timer? _reread;

  /// Applies the rule now and follows the screen from here on. Before the
  /// first frame the view can still report no size; that reads as a phone,
  /// and the metrics change that follows applies the real one.
  Future<void> start() async {
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addObserver(this);
    }
    await _apply();
  }

  /// Stops following the screen.
  @visibleForTesting
  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _reread?.cancel();
    _reread = null;
    _started = false;
  }

  @override
  void didChangeMetrics() {
    // Still changing: wait for it to settle before asking UIKit again.
    if (_reread != null) _scheduleReread();
    _apply();
  }

  Future<void> _apply() async {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    final size = view == null || view.devicePixelRatio == 0
        ? Size.zero
        : view.physicalSize / view.devicePixelRatio;
    final next = orientationsFor(size, defaultTargetPlatform);
    if (listEquals(next, _applied)) return;
    _applied = next;
    await SystemChrome.setPreferredOrientations(next);
    _scheduleReread();
  }

  void _scheduleReread() {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    _reread?.cancel();
    _reread = Timer(orientationSettleDelay, () {
      _reread = null;
      orientationChannel.invokeMethod<void>('refresh').catchError((_) {});
    });
  }
}
