part of '../dapp_webview_screen.dart';

/// `setBuildActivity` — the iOS Live Activity for a project's first version
/// being built (see [BuildLiveActivity] for the contract).
///
/// Privileged and trusted-top-frame only, like the notification and settings
/// actions: it puts the page's words on the Lock Screen, which no hosted app
/// may do. It touches no native session, so it is not a lifecycle method and
/// needs no session claim.
mixin _BridgeBuildActivity on _DappWebViewScreenStateBase {
  Future<void> _handleSetBuildActivity(
    String id,
    Map<String, dynamic> payload,
  ) async {
    const method = 'setBuildActivity';
    if (!await _requireTrustedChromeOrigin(id, method)) return;
    if (!await _revalidatePrivilegedBridgeLease(id, method)) return;
    try {
      final value = await BuildLiveActivity.instance.apply(payload['args']);
      await _resolveJsPromise(id: id, value: value, error: null);
    } on BuildActivityException catch (error) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: error.message,
        errorInfo: {'code': error.code},
      );
    }
  }
}
