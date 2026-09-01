part of '../dapp_webview_screen.dart';

/// The lifecycle bridge has one path: Social establishes or retires the
/// private native session, and every retained session-bound method enters the
/// exact runner with the claim minted for this document realm.
mixin _BridgeAuthNode on _DappWebViewScreenStateBase {
  Future<void> _handleGetNodeStatus(
    String id,
    Map<String, dynamic> payload,
  ) =>
      _resolveClaimedSessionOperation(
        id: id,
        payload: payload,
        method: 'getNodeStatus',
        body: (_, operation) async =>
            (await operation.readNodeStatus()).toBridgeJson(),
      );

  Future<void> _dispatchNodeStatusEvent() async {
    final access = widget._sessionAccess.current;
    if (access.identity.status != SessionProjectionStatus.ready) return;
    try {
      final status = await access.operations.run(
        (operation) => operation.readNodeStatus(),
      );
      final detail = jsonEncode(status.toBridgeJson());
      await _runInReadyMainFrame(
        'window.dispatchEvent(new CustomEvent('
        '"usernode:node-status", { detail: $detail }));',
      );
    } on SessionAdmissionClosedException {
      // Logout closed this exact publication before the event was sampled.
    } catch (_) {
      // Status events are observational. Explicit reads still report errors.
    }
  }

  Future<void> _handleEstablishNativeSession(
    String id,
    Map<String, dynamic> payload,
  ) async {
    if (!await _requireTrustedChromeOrigin(id, 'establishNativeSession')) {
      return;
    }
    final lease = _activePrivilegedBridgeLease;
    if (lease == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Secure native session establishment is unavailable',
      );
      return;
    }
    if (!await _revalidatePrivilegedBridgeLease(
      id,
      'establishNativeSession',
    )) {
      return;
    }
    try {
      final response = await widget._nativeSessionBridge.establishNativeSession(
        payload: payload,
        realmMarker: lease.marker,
      );
      await _resolveJsPromise(id: id, value: response, error: null);
      unawaited(_dispatchNodeStatusEvent());
    } on NativeSessionException catch (error) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: error.message,
        errorInfo: {'code': error.code},
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[Usernode JS-channel] native establishment failed: '
        '$error\n$stackTrace',
      );
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Secure native session establishment failed',
      );
    }
  }

  /// An anonymous trusted Social realm has no claim for a native session
  /// recovered before this document existed. The privileged process-root
  /// ingress may retire that private authority, but exposes nothing about it
  /// to JavaScript and does not replace the document on success.
  Future<void> _handlePrepareForLogin(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'prepareForLogin')) return;
    final lease = _activePrivilegedBridgeLease;
    if (lease == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Secure native login preparation is unavailable',
      );
      return;
    }
    if (!await _revalidatePrivilegedBridgeLease(id, 'prepareForLogin')) {
      return;
    }
    try {
      await widget._nativeSessionBridge.prepareForLogin(
        realmMarker: lease.marker,
      );
      await _resolveJsPromise(id: id, value: true, error: null);
    } on NativeSessionException catch (error) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: error.message,
        errorInfo: {'code': error.code},
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[Usernode JS-channel] native login preparation failed: '
        '$error\n$stackTrace',
      );
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Secure native login preparation failed',
      );
    }
  }

  /// Social closes its page-side admission first. Native then closes runner
  /// admission synchronously, drains every admitted child/effect, commits the
  /// durable logout, retires the vault record, and only then acknowledges.
  Future<void> _handleLogout(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'logout')) return;
    final lease = _activePrivilegedBridgeLease;
    if (lease == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Secure native logout is unavailable',
      );
      return;
    }
    if (!await _revalidatePrivilegedBridgeLease(id, 'logout')) return;
    try {
      await widget._nativeSessionBridge.logoutNativeSession(
        realmMarker: lease.marker,
      );
      await _resolveJsPromise(id: id, value: true, error: null);
      _replaceRetiredSessionDocument();
    } on NativeSessionException catch (error) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: error.message,
        errorInfo: {'code': error.code},
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[Usernode JS-channel] native logout failed: $error\n$stackTrace',
      );
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Secure native logout failed',
      );
    }
  }
}
