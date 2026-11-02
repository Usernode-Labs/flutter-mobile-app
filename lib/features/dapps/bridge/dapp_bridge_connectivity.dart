part of '../dapp_webview_screen.dart';

/// Tells the trusted page what the phone itself knows about its network.
///
/// The page gets `usernode:native-connectivity` on the main frame's `window`,
/// with `{ online, via }` ([ConnectivitySnapshot.toJson]) as its detail, and
/// the same object at `window.__usernodeNativeConnectivity`, set first, for
/// a listener installed later. It is sent:
///
/// - on each change from [NativeConnectivity.changes] that differs from what
///   this page was last sent;
/// - with the current state after each main-frame page finish, which also
///   forgets what the previous document was sent;
/// - with the current state when a realm becomes ready, because that is the
///   first moment a page can receive anything: a page that finishes loading
///   before it has said it is ready would otherwise start with no state.
///
/// Delivery goes through the ready main-frame lease, so only the trusted
/// Homeroom document hears it, never a child frame or another origin. Every
/// [DappWebViewScreen] is the SV shell's (see [_BridgeSocialPush]), so this
/// runs unconditionally like the social-push events.
mixin _BridgeConnectivity on _DappWebViewScreenStateBase {
  static const _nativeConnectivityEvent = 'usernode:native-connectivity';

  late final NativeConnectivity _nativeConnectivity;
  StreamSubscription<List<ConnectivityResult>>? _nativeConnectivityChanges;

  /// What this page was last sent. Null until something has been delivered,
  /// and again after each page finish.
  ConnectivitySnapshot? _nativeConnectivitySent;

  /// Bumped by each change and each read of the current state, so a read
  /// that a change or a later read has overtaken is dropped instead of
  /// sending an older state over a newer one.
  int _nativeConnectivityRevision = 0;

  void _listenForNativeConnectivity(NativeConnectivity source) {
    _nativeConnectivity = source;
    _nativeConnectivityChanges = source.changes.listen(
      (results) => _onNativeConnectivityChanged(
        ConnectivitySnapshot.of(results),
      ),
      // Observational, like the node-status events: a broken stream leaves
      // the page on its own `navigator.onLine`.
      onError: (Object _) {},
    );
  }

  void _disposeNativeConnectivity() {
    unawaited(_nativeConnectivityChanges?.cancel());
  }

  void _onNativeConnectivityChanged(ConnectivitySnapshot snapshot) {
    _nativeConnectivityRevision++;
    if (snapshot == _nativeConnectivitySent) return;
    unawaited(_sendNativeConnectivity(snapshot));
  }

  void _sendNativeConnectivityAfterPageFinished() {
    _nativeConnectivitySent = null;
    unawaited(_sendCurrentNativeConnectivity());
  }

  @override
  void _replayNativeConnectivity() {
    unawaited(_sendCurrentNativeConnectivity());
  }

  Future<void> _sendCurrentNativeConnectivity() async {
    final revision = ++_nativeConnectivityRevision;
    final List<ConnectivityResult> results;
    try {
      results = await _nativeConnectivity.check();
    } catch (_) {
      return;
    }
    if (!mounted || revision != _nativeConnectivityRevision) return;
    await _sendNativeConnectivity(ConnectivitySnapshot.of(results));
  }

  Future<void> _sendNativeConnectivity(ConnectivitySnapshot snapshot) async {
    final lease = _readyMainFrameLease;
    if (lease == null) return;
    final detail = jsonEncode(snapshot.toJson());
    final delivered = await _runInReadyMainFrame(
      'const detail = $detail;'
      'window.__usernodeNativeConnectivity = detail;'
      'window.dispatchEvent(new CustomEvent('
      '${jsonEncode(_nativeConnectivityEvent)}, { detail: detail }));',
    );
    if (delivered && mounted && lease.marker == _readyMainFrameLease?.marker) {
      _nativeConnectivitySent = snapshot;
    }
  }
}
