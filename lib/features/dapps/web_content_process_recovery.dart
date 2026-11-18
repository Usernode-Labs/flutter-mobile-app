import 'dart:async';

import 'package:flutter/widgets.dart';

/// Brings a WebView's page back after the system kills its content process.
///
/// iOS reclaims the WKWebView WebContent process of a backgrounded app when
/// memory runs short. WebKit reports it once
/// (`webViewWebContentProcessDidTerminate`, which webview_flutter_wkwebview
/// hands over as a main-frame `webContentProcessTerminated` resource error)
/// and from then on paints only the web view's background colour, until
/// something loads a page again. Safari and native apps reload the page the
/// person was on, and so does this: at once while the app is in the
/// foreground, otherwise on the next [AppLifecycleState.resumed], so nothing
/// is loaded in the background for the system to reclaim again.
///
/// A page that takes its process down on every load must not reload forever.
/// After an automatic reload, another termination within [loopWindow], with
/// the app in the foreground the whole time, is taken for that loop:
/// [onGaveUp] runs instead of a reload and the page stays down. Leaving the
/// foreground closes the window (the system reclaiming memory from an app
/// that is away is not the page crashing), so the next resume is a fresh
/// chance.
final class WebContentProcessRecovery {
  WebContentProcessRecovery({
    required this.reload,
    required this.onGaveUp,
    AppLifecycleState? lifecycleState,
    this.loopWindow = defaultLoopWindow,
  }) : _lifecycleState = lifecycleState;

  static const defaultLoopWindow = Duration(seconds: 30);

  /// Loads the page again. Called at most once per termination.
  final VoidCallback reload;

  /// The page lost its process again too soon after an automatic reload.
  /// May run more than once for the same termination; owners treat it as
  /// idempotent.
  final VoidCallback onGaveUp;

  final Duration loopWindow;

  /// Null until the engine reports a state. Taken for the foreground, like
  /// the first load, which does not wait for one either.
  AppLifecycleState? _lifecycleState;

  /// The content process is gone and the page has not been reloaded since.
  bool _terminated = false;

  /// Runs from an automatic reload until [loopWindow] has passed or the app
  /// leaves the foreground.
  Timer? _loopWindow;

  bool _disposed = false;

  bool get _inForeground =>
      _lifecycleState == null || _lifecycleState == AppLifecycleState.resumed;

  void noteProcessTerminated() {
    if (_disposed) return;
    _terminated = true;
    _recover();
  }

  void noteLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    _lifecycleState = state;
    switch (state) {
      case AppLifecycleState.resumed:
        _recover();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _closeLoopWindow();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void dispose() {
    _disposed = true;
    _closeLoopWindow();
  }

  void _recover() {
    if (!_terminated || !_inForeground) return;
    if (_loopWindow != null) {
      onGaveUp();
      return;
    }
    _terminated = false;
    _loopWindow = Timer(loopWindow, () => _loopWindow = null);
    reload();
  }

  void _closeLoopWindow() {
    _loopWindow?.cancel();
    _loopWindow = null;
  }
}
