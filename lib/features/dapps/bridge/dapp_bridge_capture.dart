part of '../dapp_webview_screen.dart';

/// Trusted top-frame bridge handler for the feedback screenshot action.
mixin _BridgeCapture on _DappWebViewScreenStateBase {
  final NativeScreenCapture _nativeScreenCapture = const NativeScreenCapture();

  Future<void> _handleCaptureScreenshot(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'captureScreenshot')) return;
    if (!await _revalidatePrivilegedBridgeLease(id, 'captureScreenshot')) {
      return;
    }
    try {
      final payload = await _nativeScreenCapture.capture();
      await _resolveJsPromise(id: id, value: payload, error: null);
    } catch (e, st) {
      debugPrint('[screen capture] failed: $e\n$st');
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Could not capture the current screen',
      );
    }
  }
}
