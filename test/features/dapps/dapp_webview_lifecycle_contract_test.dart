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
    expect(listener, contains('final delegate = widget.onSessionEnded;'));
    expect(
      listener,
      contains('unawaited(_controller.loadRequest(parseDappUrl(widget.url)));'),
    );
    expect(shell, contains('onSessionEnded: _reloadForSessionEnd,'));
  });

  test('dapp transaction receipts are bound to the identity that owns them',
      () async {
    final records = await File(
      'lib/features/dapps/bridge/dapp_bridge_records.dart',
    ).readAsString();
    final webview = await File(
      'lib/features/dapps/dapp_webview_screen.dart',
    ).readAsString();

    // Receipts carry sender, recipient, amount, memo and timing. Keyed by URL
    // alone they were resolvable by every later WebView on the same URL,
    // whoever was signed in.
    expect(records, isNot(contains("=> 'dapp_tx_ids:")));
    expect(records, isNot(contains("=> 'tx_records:")));
    expect(records, contains('NetworkPrefs.prefixAccountKeyFor('));
    expect(records, contains('_recordsBucket ?? NetworkPrefs.activeBucket'));
    // Pre-bucket keys belong to a user this app can no longer identify.
    expect(records, contains('Future<void> _removeUnbucketedRecords()'));
    // In-memory maps are dropped on the identity edge, not just on disk.
    final bind = records.substring(
      records.indexOf('Future<void> _bindTxRecordsToActiveIdentity()'),
    );
    expect(bind, contains('_dappTxIds.clear();'));
    expect(bind, contains('_txRecords.clear();'));
    expect(webview, contains('unawaited(_bindTxRecordsToActiveIdentity());'));
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
