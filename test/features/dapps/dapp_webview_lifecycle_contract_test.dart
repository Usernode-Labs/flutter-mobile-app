import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bridge info exposes the installed Flutter version without privilege',
      () async {
    final dispatch = await File(
      'lib/features/dapps/bridge/dapp_bridge_dispatch.dart',
    ).readAsString();
    final settings = await File(
      'lib/features/dapps/bridge/dapp_bridge_settings.dart',
    ).readAsString();
    final bridgeInfo = dispatch.substring(
      dispatch.indexOf("if (method == 'getBridgeInfo')"),
      dispatch.indexOf("if (method == 'getNodeStatus')"),
    );

    expect(bridgeInfo, contains('value: await _bridgeInfoValue()'));
    expect(dispatch, contains('...await _mobileAppBuildInfo()'));
    expect(settings, contains('PackageInfo.fromPlatform()'));
    expect(settings, contains("'appVersion': packageInfo.version"));
    expect(settings, contains("'buildNumber': packageInfo.buildNumber"));
  });

  test('bridge v5 exposes exact submission without native product receipts',
      () async {
    final dispatch = await File(
      'lib/features/dapps/bridge/dapp_bridge_dispatch.dart',
    ).readAsString();
    final wallet = await File(
      'lib/features/dapps/bridge/dapp_bridge_wallet.dart',
    ).readAsString();

    expect(dispatch, contains('static const int _bridgeVersion = 5;'));
    expect(dispatch, contains("'submitTransaction'"));
    expect(dispatch, isNot(contains("'sendTransaction'")));
    expect(dispatch, isNot(contains("'txObserved'")));
    expect(dispatch, isNot(contains("'getTransactionRecords'")));
    expect(dispatch, isNot(contains("'getProfileInfo'")));
    expect(wallet, contains('SubmitTransactionResult(txId: txId)'));
    expect(
      await File(
        'lib/features/dapps/bridge/dapp_bridge_records.dart',
      ).exists(),
      isFalse,
    );
  });

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
      contains('state != AppLifecycleState.resumed ||'),
    );
    expect(lifecycle, contains('widget.nativeSessionBridge != null'));
    expect(lifecycle, contains('_dispatchAuthStatusEvent();'));
    expect(lifecycle, contains('_dispatchPendingSocialPushEvents();'));
    expect(source, contains('WidgetsBinding.instance.removeObserver(this);'));
  });

  test('the session-end document replacement lives with the WebView owner',
      () async {
    final webview = await File(
      'lib/features/dapps/dapp_webview_screen.dart',
    ).readAsString();
    final shell = await File(
      'lib/features/dapps/sv_shell_screen.dart',
    ).readAsString();

    // Driven by the SETTLED sign-out signal. `authenticated -> anything else`
    // also fires on the synchronous `transitioning` publication (before the
    // token, node and cookie/storage deletion have run) and on terminal
    // boundaries, which have no successor to build.
    expect(
        webview, contains('ref.listenManual<int>(signOutCompletionProvider'));
    expect(shell, isNot(contains('authStatusProvider')));

    // Every trusted realm is covered, not just the shell: a same-origin pin
    // falls back to a standalone DappWebViewScreen, whose loaded DOM would
    // otherwise stay rendered after a successful logout.
    final listener = webview.substring(
      webview.indexOf('ref.listenManual<int>(signOutCompletionProvider'),
    );
    expect(listener, contains('_replaceRetiredSessionDocument();'));
    final replacementStart = webview.indexOf(
      'void _replaceRetiredSessionDocument()',
    );
    final replacement = webview.substring(
      replacementStart,
      webview.indexOf('// First main-frame load outcome', replacementStart),
    );
    expect(replacement, contains('final delegate = widget.onSessionEnded;'));
    expect(
      replacement,
      contains('unawaited(_controller.loadRequest(parseDappUrl(widget.url)));'),
    );
    expect(shell, contains('onSessionEnded: _reloadForSessionEnd,'));
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
