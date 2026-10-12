import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Claims OS links that arrive before the app's router exists.
///
/// While the native session boots, the root is a splash `MaterialApp` with no
/// routes. A link offered to it is pushed as a named route, which throws, so
/// the engine reports the link unhandled. On iOS an unhandled universal link
/// is then reopened in Safari while the app lands on its root.
///
/// Register this observer before that splash is built. Until [close], it
/// answers every link and keeps the newest one, which the router then starts
/// from exactly like a cold link it was launched with.
class PendingLaunchLink with WidgetsBindingObserver {
  String? _link;
  bool _open = true;

  /// Stops claiming links, so later ones reach the router directly, and
  /// returns the newest link that arrived while waiting, if any.
  String? close() {
    _open = false;
    return _link;
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    if (!_open) return SynchronousFuture<bool>(false);
    _link = routeInformation.uri.toString();
    return SynchronousFuture<bool>(true);
  }
}
