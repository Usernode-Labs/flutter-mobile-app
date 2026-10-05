part of '../dapp_webview_screen.dart';

/// `signInWithProvider` — the app's own Sign in with Apple or Google sheet
/// for the web shell's sign-in sheet (see [NativeSignIn]).
///
/// Privileged and trusted-top-frame only. It waits on the person, so it is
/// not a lifecycle method and does not hold the bridge's lifecycle queue: it
/// neither starts nor ends a native session, and the page's ordinary
/// session mint follows the platform's answer.
mixin _BridgeSignIn on _DappWebViewScreenStateBase {
  Future<void> _handleSignInWithProvider(
    String id,
    Map<String, dynamic> payload,
  ) async {
    if (!await _requireTrustedChromeOrigin(id, 'signInWithProvider')) return;
    if (!await _revalidatePrivilegedBridgeLease(id, 'signInWithProvider')) {
      return;
    }
    try {
      final idToken = await NativeSignIn.instance.signIn(payload['args']);
      await _resolveJsPromise(id: id, value: {'idToken': idToken}, error: null);
    } on NativeSignInException catch (error) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: error.message,
        errorInfo: {'code': error.code},
      );
    } catch (error) {
      debugPrint('[DappWebView] signInWithProvider failed: $error');
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Sign-in did not finish.',
        errorInfo: const {'code': 'failed'},
      );
    }
  }
}
