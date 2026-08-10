import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resuming the app replays authoritative state into the WebView',
      () async {
    final source = await File(
      'lib/features/dapps/dapp_webview_screen.dart',
    ).readAsString();
    final lifecycleStart = source.indexOf(
      'void didChangeAppLifecycleState(AppLifecycleState state)',
    );
    final lifecycle = source.substring(
      lifecycleStart,
      source.indexOf('  /// Presents the OS file picker', lifecycleStart),
    );

    expect(source, contains('WidgetsBindingObserver,'));
    expect(source, contains('WidgetsBinding.instance.addObserver(this);'));
    expect(
      lifecycle,
      contains('state != AppLifecycleState.resumed || !mounted'),
    );
    expect(lifecycle, contains('_dispatchAuthStatusEvent();'));
    expect(lifecycle, contains('_dispatchPendingSocialPushEvents();'));
    expect(source, contains('WidgetsBinding.instance.removeObserver(this);'));
  });

  test('login admits authenticated services without awaiting a wallet',
      () async {
    final source = await File(
      'lib/features/dapps/bridge/dapp_bridge_auth_node.dart',
    ).readAsString();
    final completeLogin = source.substring(
      source.indexOf('Future<void> _handleCompleteLogin'),
      source.indexOf('  /// `startNode`',
          source.indexOf('Future<void> _handleCompleteLogin')),
    );

    expect(completeLogin, contains('_admitAuthenticatedSession'));
    expect(completeLogin, contains("phase == IdentityPhase.ready"));
    expect(completeLogin, isNot(contains('nodeAccountReconcilerProvider')));
    expect(completeLogin, isNot(contains('Wallet provisioning failed')));
  });
}
