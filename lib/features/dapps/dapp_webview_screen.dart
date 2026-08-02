import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart'
    show buildEnvProvider, debugModeProvider;
import 'package:crypto_mobile_app/core/providers/top_status_node_status_provider.dart';
import 'package:crypto_mobile_app/core/providers/wallet_provider.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_service.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_state_store.dart';
import 'package:crypto_mobile_app/core/services/node_lifecycle_coordinator.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/widgets/node_status_icon.dart';
import 'package:crypto_mobile_app/core/widgets/tx_confirmation_page.dart';
import 'package:crypto_mobile_app/design_system/src/button.dart';
import 'package:crypto_mobile_app/design_system/src/top_status_app_bar.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_sizing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_typography.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart'
    show AuthSession, Participant;
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart'
    show authStatusProvider, identityProvider;
import 'package:crypto_mobile_app/features/onboarding/data/node_account_provisioning.dart'
    show nodeAccountReconcilerProvider;
import 'package:crypto_mobile_app/features/dapps/home_shortcuts_channel.dart';
import 'package:crypto_mobile_app/features/dapps/providers/dapps_provider.dart';
import 'package:crypto_mobile_app/features/dapps/providers/pinned_dapps_provider.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/features/zkpassport/zk_challenge_reset.dart'
    show resetChallengeState;
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart'
    show zkPassportFlowControllerProvider, zkPassportSettingsProvider;
import 'package:crypto_mobile_app/src/rust/account.dart' as frb_account;
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

extension on WebViewController {
  /// Debug-only: exposes the webview to Safari Web Inspector (iOS 16.4+)
  /// and chrome://inspect (Android). No-op in release builds.
  void setInspectableForDebug() {
    if (!kDebugMode) return;
    final platformController = platform;
    if (platformController is WebKitWebViewController) {
      platformController.setInspectable(true);
    } else if (platformController is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
    }
  }
}

enum _TxStatus { denied, error, queued }

class _TxRecord {
  final String id;
  final DateTime sentAt;
  final String from;
  final String to;
  final BigInt amount;
  final String memo;
  final _TxStatus status;
  final String? errorMessage;
  final DateTime? confirmedAt;
  final int? inclusionLatencyMs;
  final int? blockHeight;
  final int? onChainTimestampMs;
  final String? onChainStatus;
  // Wall-clock ms of when the dapp's bridge poll (or an explicit
  // window.usernode.acknowledgeTransaction call) first surfaced this tx
  // on-chain. Independent of [confirmedAt], which is the slower
  // explorer-poll observation. The first ack wins so this stays stable
  // across re-polls, refreshes, and explicit calls.
  final int? dappObservedAtMs;

  const _TxRecord({
    required this.id,
    required this.sentAt,
    required this.from,
    required this.to,
    required this.amount,
    required this.memo,
    required this.status,
    this.errorMessage,
    this.confirmedAt,
    this.inclusionLatencyMs,
    this.blockHeight,
    this.onChainTimestampMs,
    this.onChainStatus,
    this.dappObservedAtMs,
  });

  _TxRecord copyWith({
    DateTime? confirmedAt,
    int? inclusionLatencyMs,
    int? blockHeight,
    int? onChainTimestampMs,
    String? onChainStatus,
    int? dappObservedAtMs,
  }) {
    return _TxRecord(
      id: id,
      sentAt: sentAt,
      from: from,
      to: to,
      amount: amount,
      memo: memo,
      status: status,
      errorMessage: errorMessage,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      inclusionLatencyMs: inclusionLatencyMs ?? this.inclusionLatencyMs,
      blockHeight: blockHeight ?? this.blockHeight,
      onChainTimestampMs: onChainTimestampMs ?? this.onChainTimestampMs,
      onChainStatus: onChainStatus ?? this.onChainStatus,
      dappObservedAtMs: dappObservedAtMs ?? this.dappObservedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sentAt': sentAt.millisecondsSinceEpoch,
        'from': from,
        'to': to,
        'amount': amount.toString(),
        'memo': memo,
        'status': status.name,
        if (errorMessage != null) 'error': errorMessage,
        if (confirmedAt != null)
          'confirmedAt': confirmedAt!.millisecondsSinceEpoch,
        if (inclusionLatencyMs != null)
          'inclusionLatencyMs': inclusionLatencyMs,
        if (blockHeight != null) 'blockHeight': blockHeight,
        if (onChainTimestampMs != null)
          'onChainTimestampMs': onChainTimestampMs,
        if (onChainStatus != null) 'onChainStatus': onChainStatus,
        if (dappObservedAtMs != null) 'dappObservedAtMs': dappObservedAtMs,
      };

  // ── Latency helpers ─────────────────────────────────────────────────────
  //
  // Two independent observation channels feed timing data: the explorer poll
  // (sets `confirmedAt` + `inclusionLatencyMs`) and the dapp ack via the
  // bridge's `txObserved` JS-channel message (sets `dappObservedAtMs`,
  // optionally also `inclusionLatencyMs` when the bridge had a matched tx
  // in hand).
  //
  // Each channel contributes a "total" (observed_at − sentAt) and, when
  // inclusion latency is also known, a "last mile" (total − inclusion).
  // The fastest signal wins for the headline metrics, but the per-channel
  // numbers are still exposed so the latency row can show both side-by-side.
  int get _sentMs => sentAt.millisecondsSinceEpoch;

  int? get explorerTotalMs {
    if (confirmedAt == null) return null;
    final ms = confirmedAt!.millisecondsSinceEpoch - _sentMs;
    return ms >= 0 ? ms : null;
  }

  int? get dappTotalMs {
    if (dappObservedAtMs == null) return null;
    final ms = dappObservedAtMs! - _sentMs;
    return ms >= 0 ? ms : null;
  }

  int? get bestTotalMs {
    final e = explorerTotalMs;
    final d = dappTotalMs;
    if (e != null && d != null) return e < d ? e : d;
    return e ?? d;
  }

  int? get explorerLastMileMs {
    final e = explorerTotalMs;
    final inc = inclusionLatencyMs;
    if (e == null || inc == null) return null;
    final lm = e - inc;
    return lm >= 0 ? lm : null;
  }

  int? get dappLastMileMs {
    final d = dappTotalMs;
    final inc = inclusionLatencyMs;
    if (d == null || inc == null) return null;
    final lm = d - inc;
    return lm >= 0 ? lm : null;
  }

  factory _TxRecord.fromJson(Map<String, dynamic> j) {
    return _TxRecord(
      id: j['id'] as String,
      sentAt: DateTime.fromMillisecondsSinceEpoch(j['sentAt'] as int),
      from: j['from'] as String,
      to: j['to'] as String,
      amount: BigInt.parse(j['amount'] as String),
      memo: j['memo'] as String,
      status: _TxStatus.values.byName(j['status'] as String),
      errorMessage: j['error'] as String?,
      confirmedAt: j['confirmedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(j['confirmedAt'] as int)
          : null,
      inclusionLatencyMs: (j['inclusionLatencyMs'] as num?)?.toInt(),
      blockHeight: (j['blockHeight'] as num?)?.toInt(),
      onChainTimestampMs: (j['onChainTimestampMs'] as num?)?.toInt(),
      onChainStatus: j['onChainStatus'] as String?,
      dappObservedAtMs: (j['dappObservedAtMs'] as num?)?.toInt(),
    );
  }
}

class DappWebViewScreen extends ConsumerStatefulWidget {
  final String url;
  final String name;

  /// When true, the AppBar's leading "Home" button is hidden. Set this when
  /// the screen is mounted as the root of a bottom-nav tab (not pushed on
  /// the navigator) so the leading icon doesn't pop the surrounding shell.
  /// System back / WebView back-history handling is unaffected.
  final bool embedded;

  /// Full-screen shell mode (app-as-SV-chrome): no Flutter app bar at all —
  /// the web page owns its own header. Back handling, the JS bridge, and the
  /// tx confirmation chrome are unaffected. Implies the tab-root behavior of
  /// [embedded] (no leading "Home" button, because there is no bar).
  final bool chromeless;

  /// Fired exactly once with the outcome of the first main-frame load:
  /// `true` on the first successful [onPageFinished], `false` if a
  /// main-frame resource error lands first. Used by the shell's
  /// first-launch gate ("has SV ever rendered on this install?").
  final void Function(bool ok)? onFirstLoadResult;

  const DappWebViewScreen({
    super.key,
    required this.url,
    required this.name,
    this.embedded = false,
    this.chromeless = false,
    this.onFirstLoadResult,
  });

  @override
  ConsumerState<DappWebViewScreen> createState() => _DappWebViewScreenState();
}

class _DappWebViewScreenState extends ConsumerState<DappWebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;

  /// The app-scoped Riverpod container, captured so JS-channel handlers — which
  /// the WebView can invoke after this screen is disposed — read through it
  /// instead of the widget `ref` (which throws once disposed).
  ProviderContainer? _providersContainer;
  ProviderContainer get _providers => _providersContainer!;

  // True once the embedded hub has navigated into a dapp (web `pushState`
  // history exists). Drives the tab-root bar: shell affordances at the hub
  // root (`false`), browser chrome once drilled in (`true`). Kept in sync with
  // `_controller.canGoBack()` on every navigation callback. Only meaningful in
  // embedded (tab-root) mode; non-embedded pushes always show browser chrome.
  bool _canGoBack = false;

  static const _jsChannelName = 'Usernode';

  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  bool _showUrlEditor = false;

  // Mirrors `document.title` of the page currently loaded in the WebView,
  // refreshed on every full navigation (onPageFinished), SPA pushState
  // (onUrlChange), and via the `titleChanged` JS-channel method that the
  // page can post when it mutates `document.title` outside of a real
  // navigation (e.g. SV's `App.setHeaderTitle` after `/api/apps/:slug`
  // resolves). Falls back to [widget.name] when null/empty.
  String? _pageTitle;

  // First main-frame load outcome has been reported via
  // widget.onFirstLoadResult (shell first-launch gate). Never reset.
  bool _firstLoadReported = false;

  // Set to true the first time the page posts a `titleChanged` message via
  // the JS channel. Once true, we stop trusting `_controller.getTitle()` in
  // `_refreshPageTitle` — WKWebView's cached title lags behind the page's
  // own `document.title = ...` writes by enough frames that
  // onUrlChange-triggered refreshes routinely come back with the *previous*
  // screen's title and clobber the just-arrived channel value. The page
  // promised it would tell us about every title change, so honor that.
  //
  // Reset on every full navigation (onPageStarted) so pages that don't
  // wire up the channel still get title refreshes via the legacy
  // `getTitle()` polling path.
  bool _titleFromChannel = false;
  final Set<String> _dappTxIds = {};
  final Map<String, _TxRecord> _txRecords = {};
  Timer? _confirmPoller;
  String? _cachedChainId;

  static const _maxPersistedIds = 200;
  static const _maxTxRecords = 500;

  String get _dappTxIdsPrefsKey => 'dapp_tx_ids:${widget.url}';
  String get _txRecordsPrefsKey => 'tx_records:${widget.url}';

  Future<void> _loadDappTxIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dappTxIdsPrefsKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _dappTxIds.addAll(list.cast<String>());
    } catch (_) {}
  }

  Future<void> _saveDappTxIds() async {
    final prefs = await SharedPreferences.getInstance();
    if (_dappTxIds.length > _maxPersistedIds) {
      final sorted =
          _dappTxIds.where((id) => _txRecords.containsKey(id)).toList()
            ..sort((a, b) {
              final ra = _txRecords[a]!;
              final rb = _txRecords[b]!;
              return rb.sentAt.compareTo(ra.sentAt);
            });
      final kept = sorted.take(_maxPersistedIds).toSet();
      _dappTxIds
        ..clear()
        ..addAll(kept);
    }
    await prefs.setString(_dappTxIdsPrefsKey, jsonEncode(_dappTxIds.toList()));
  }

  Future<void> _loadTxRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_txRecordsPrefsKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in map.entries) {
        _txRecords[entry.key] =
            _TxRecord.fromJson(entry.value as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _saveTxRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _txRecords.entries.toList()
      ..sort((a, b) => b.value.sentAt.compareTo(a.value.sentAt));

    final map = <String, dynamic>{};
    for (final e in entries.take(_maxTxRecords)) {
      map[e.key] = e.value.toJson();
    }

    if (entries.length > _maxTxRecords) {
      final kept = entries.take(_maxTxRecords).map((e) => e.key).toSet();
      _txRecords.removeWhere((k, _) => !kept.contains(k));
    }

    await prefs.setString(_txRecordsPrefsKey, jsonEncode(map));
  }

  // Stamp a tx with the wall-clock time the dapp's bridge first observed
  // it on-chain, surfaced via the `txObserved` JS channel message. Distinct
  // from [_TxRecord.confirmedAt], which is set by our own (slower) explorer
  // poll. First ack wins so re-emits and explicit acks don't reset the
  // timestamp.
  //
  // When the bridge has the matched tx in hand (the typical post-send
  // inclusion-poll path), it also forwards `block_height` and
  // `block_timestamp_ms`. We use those to populate the same fields the
  // explorer poll sets (`onChainStatus`, `blockHeight`, `onChainTimestampMs`,
  // `inclusionLatencyMs`) so the badge, the header pill, and the
  // inclusion / last-mile columns can all flip to "confirmed" without
  // waiting on the slower explorer poll. Explicit
  // `window.usernode.acknowledgeTransaction(txId)` callers don't have a
  // matched tx and just omit those fields — we still mark the tx confirmed
  // (the ack itself is evidence the tx is on chain) but leave inclusion
  // metrics for the explorer poll to fill in later.
  Future<void> _handleTxObserved(Map<String, dynamic> payload) async {
    final args = payload['args'];
    if (args is! Map<String, dynamic>) return;
    final txId = (args['tx_id'] as String?)?.trim();
    final observedAtMs = (args['observed_at_ms'] as num?)?.toInt();
    if (txId == null || txId.isEmpty || observedAtMs == null) return;

    final rec = _txRecords[txId];
    if (rec == null) return;
    if (rec.dappObservedAtMs != null) return;

    final blockHeight = (args['block_height'] as num?)?.toInt();
    final blockTimestampMs = (args['block_timestamp_ms'] as num?)?.toInt();

    // Inclusion latency = block timestamp − sent timestamp. Skip when we
    // can't compute it (no block_timestamp_ms, or negative due to clock
    // skew between phone and node).
    int? inclusionLatencyMs;
    if (blockTimestampMs != null) {
      final ms = blockTimestampMs - rec.sentAt.millisecondsSinceEpoch;
      if (ms >= 0) inclusionLatencyMs = ms;
    }

    final updated = rec.copyWith(
      dappObservedAtMs: observedAtMs,
      // Don't clobber values the explorer poll may have already filled in.
      onChainStatus: rec.onChainStatus ?? 'confirmed',
      blockHeight: rec.blockHeight ?? blockHeight,
      onChainTimestampMs: rec.onChainTimestampMs ?? blockTimestampMs,
      inclusionLatencyMs: rec.inclusionLatencyMs ?? inclusionLatencyMs,
    );
    if (mounted) {
      setState(() {
        _txRecords[txId] = updated;
      });
    } else {
      _txRecords[txId] = updated;
    }
    await _saveTxRecords();
  }

  void _addRecord(_TxRecord record) {
    _dappTxIds.add(record.id);
    _txRecords[record.id] = record;
    _saveDappTxIds();
    _saveTxRecords();
  }

  // Transaction confirmation uses Navigator.push with an opaque route instead
  // of showModalBottomSheet. A known Flutter engine bug (fixed in 3.41.0)
  // corrupts WKWebView's gesture recognizer when a translucent modal barrier
  // overlaps the platform view. An opaque route fully obscures the WebView,
  // so Flutter doesn't coordinate gestures with it during the confirmation.

  @override
  void initState() {
    super.initState();
    // iOS: opt this webview into App-Bound Domains (WKAppBoundDomains in
    // Info.plist). This unlocks Service Workers — SV's offline PWA mode —
    // at the cost of restricting navigation to the bound domains. All dapp
    // surfaces we host live on those domains; external links route through
    // the openExternal bridge method / system browser instead.
    final PlatformWebViewControllerCreationParams creationParams;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      creationParams = WebKitWebViewControllerCreationParams(
        limitsNavigationsToAppBoundDomains: true,
      );
    } else {
      creationParams = const PlatformWebViewControllerCreationParams();
    }
    _controller = WebViewController.fromPlatformCreationParams(creationParams)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Pipe WebView console.* output (including the iframe-relay tracing in
      // usernode-bridge.js) into Flutter's debug logs so it shows up in
      // `flutter run` — no Safari/remote inspector required.
      ..setOnConsoleMessage((msg) {
        debugPrint('[webview ${msg.level.name}] ${msg.message}');
      })
      // Debug builds only: allow attaching Safari Web Inspector (iOS 16.4+)
      // and chrome://inspect (Android) to the dapp webview, so bridge
      // methods can be exercised from a desktop console during development.
      ..setInspectableForDebug()
      // webview_flutter has NO default UI for window.alert() — without this
      // handler every page-side alert (dapps report errors this way) is
      // silently dropped and a failing action looks like a no-op. Surface it
      // as a SnackBar rather than a dialog: a translucent modal barrier over
      // the platform view triggers the WKWebView gesture bug described above.
      ..setOnJavaScriptAlertDialog((request) async {
        debugPrint('[webview alert] ${request.message}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(request.message),
            duration: const Duration(seconds: 6),
          ),
        );
      })
      ..addJavaScriptChannel(
        _jsChannelName,
        onMessageReceived: (message) async {
          try {
            final payload = jsonDecode(message.message) as Map<String, dynamic>;
            final method = payload['method'] as String?;
            final id = payload['id'] as String?;
            debugPrint('[Usernode JS-channel] method=$method id=$id');
            if (method == null) return;

            // `titleChanged` is a fire-and-forget signal from the page that
            // `document.title` has been updated outside of a real navigation
            // (e.g. an SPA route change without a pushState, or a deferred
            // title set after data finishes loading). webview_flutter's
            // onUrlChange-based `_refreshPageTitle` only catches title
            // changes that happen at navigation moments; without this
            // channel, the AppBar's `_pageTitle` lags one navigation
            // behind the page's actual title. Unlike the other methods
            // here, there's no pending JS promise to resolve, so we don't
            // require `id`.
            if (method == 'titleChanged') {
              // Use `.toString()` rather than `as String?` so we don't
              // throw on unexpected payload shapes (the cast surfaced as
              // a silent setState-skip when the value happened to come
              // back as a non-String).
              final raw = payload['value']?.toString().trim();
              final newTitle = (raw == null || raw.isEmpty) ? null : raw;
              debugPrint(
                '[Usernode JS-channel] titleChanged value="$newTitle" '
                'current="$_pageTitle" mounted=$mounted',
              );
              if (!mounted) return;
              // Pin to the channel as the source of truth for this page
              // load. Without this, the very next pushState-driven
              // onUrlChange will run `_refreshPageTitle`, see WKWebView's
              // stale getTitle() value (the *previous* screen's title)
              // and clobber the value we're about to set with setState
              // below — visible as `titleChanged value="dApps"` followed
              // by `build _pageTitle="whiteboard"` in the logs.
              _titleFromChannel = true;
              if (newTitle == _pageTitle) return;
              setState(() => _pageTitle = newTitle);
              return;
            }

            if (id == null) return;

            // Any handler that throws before resolving would otherwise leave
            // the page's JS promise pending forever (the outer catch below
            // only logs, and by then the id may be unknown). Reject here so a
            // bridge caller always settles instead of hanging.
            try {
              if (method == 'getNodeAddress') {
                final address = _bridgeWalletIdentity()?.address;
                if (address == null || address.isEmpty) {
                  await _resolveJsPromise(
                    id: id,
                    value: null,
                    error: 'No active account/address available',
                  );
                } else {
                  await _resolveJsPromise(id: id, value: address, error: null);
                }
              }

              if (method == 'sendTransaction') {
                await _handleSendTransaction(id, payload);
              }

              if (method == 'signMessage') {
                await _handleSignMessage(id, payload);
              }

              if (method == 'txObserved') {
                await _handleTxObserved(payload);
              }

              if (method == 'getHomeScreenShortcutSupport') {
                await _handleGetHomeScreenShortcutSupport(id);
              }

              if (method == 'addHomeScreenShortcut') {
                await _handleAddHomeScreenShortcut(id, payload);
              }

              if (method == 'getHomeScreenShortcuts') {
                await _handleGetHomeScreenShortcuts(id);
              }

              if (method == 'removeHomeScreenShortcut') {
                await _handleRemoveHomeScreenShortcut(id, payload);
              }

              if (method == 'reorderHomeScreenShortcuts') {
                await _handleReorderHomeScreenShortcuts(id, payload);
              }

              if (method == 'openExternal') {
                await _handleOpenExternal(id, payload);
              }

              if (method == 'getBridgeInfo') {
                await _resolveJsPromise(
                  id: id,
                  value: {
                    'version': _bridgeVersion,
                    'capabilities': _bridgeCapabilities,
                  },
                  error: null,
                );
              }

              if (method == 'getNodeStatus') {
                await _resolveJsPromise(
                  id: id,
                  value: _nodeStatusSnapshot(),
                  error: null,
                );
              }

              if (method == 'getWalletState') {
                await _handleGetWalletState(id);
              }

              if (method == 'getTransactionRecords') {
                await _handleGetTransactionRecords(id);
              }

              if (method == 'openNativeScreen') {
                await _handleOpenNativeScreen(id, payload);
              }

              if (method == 'getProfileInfo') {
                await _handleGetProfileInfo(id);
              }

              if (method == 'getSettingsState') {
                await _handleGetSettingsState(id);
              }

              if (method == 'setNodeSleepEnabled') {
                await _handleSetNodeSleepEnabled(id, payload);
              }

              if (method == 'setDebugMode') {
                await _handleSetDebugMode(id, payload);
              }

              if (method == 'setFacematchStrict') {
                await _handleSetFacematchStrict(id, payload);
              }

              if (method == 'resetZkChallenge') {
                await _handleResetZkChallenge(id);
              }

              if (method == 'requestPermissions') {
                await _handleRequestPermissions(id);
              }

              if (method == 'openBatterySettings') {
                await _handleOpenBatterySettings(id);
              }

              if (method == 'logout') {
                await _handleLogout(id);
              }

              if (method == 'completeLogin') {
                await _handleCompleteLogin(id, payload);
              }

              if (method == 'startNode') {
                await _handleStartNode(id, payload);
              }

              if (method == 'stopNode') {
                await _handleStopNode(id);
              }

              if (method == 'getAuthStatus') {
                await _handleGetAuthStatus(id);
              }
            } catch (e, st) {
              debugPrint(
                  '[Usernode JS-channel] handler error method=$method id=$id: '
                  '$e\n$st');
              await _resolveJsPromise(
                  id: id, value: null, error: 'Internal error');
            }
          } catch (e, st) {
            // Surface dispatch failures so we don't end up with a silently
            // hung pending promise on the JS side. The id may not have been
            // parsed yet, in which case there is no resolver to call.
            debugPrint('[Usernode JS-channel] dispatch error: $e\n$st');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            // A full page load wipes any JS state, so the channel-owns-title
            // latch has to be cleared too — the new page hasn't told us
            // anything yet, and we want `_refreshPageTitle` (firing from
            // onPageFinished below) to populate `_pageTitle` from the
            // initial `document.title` for pages that don't wire up the
            // channel. SPA pushState navigations don't fire onPageStarted,
            // so this won't clear the latch mid-session in dapps like SV.
            _titleFromChannel = false;
            setState(() => _progress = 0);
            _refreshCanGoBack();
          },
          onProgress: (progress) {
            if (!mounted) return;
            if (progress != _progress) {
              setState(() => _progress = progress);
            }
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _progress = 100);
            _reportFirstLoadResult(true);
            _refreshPageTitle();
            _refreshCanGoBack();
            _logServiceWorkerStateForDebug();
            // Seed the freshly loaded page with the current node status so
            // SV chrome renders the pill immediately (no first-poll gap).
            _dispatchNodeStatusEvent();
            // Same for the identity phase (bridge v4 boot orchestration).
            _dispatchAuthStatusEvent();
          },
          onUrlChange: (_) {
            // SPA pushState navigation — title typically changes too.
            _refreshPageTitle();
            _refreshCanGoBack();
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            setState(() => _progress = 100);
            // Sub-resource failures (an image, a beacon) don't mean the
            // page failed; only main-frame errors flunk the first-load gate.
            if (error.isForMainFrame != false) {
              _reportFirstLoadResult(false);
            }
          },
        ),
      )
      ..loadRequest(parseDappUrl(widget.url));
    // Android WebView shows no OS file chooser for <input type="file">
    // unless the host app registers one (WebChromeClient.onShowFileChooser)
    // — without this, upload controls in dapps (including cross-origin
    // iframes like staging previews) silently no-op. iOS WKWebView
    // presents its own picker natively, so this is Android-only.
    final platformController = _controller.platform;
    if (platformController is AndroidWebViewController) {
      platformController.setOnShowFileSelector(_showAndroidFileSelector);
    }
    // Push node pill-state transitions into the page (SV header pill).
    // Chrome-level provider only changes on real state flips (hysteresis
    // inside), so this doesn't spam the page with the 1s status poll.
    // Subscription is auto-closed when this State is disposed.
    ref.listenManual(
      topStatusChromeNodeStatusProvider,
      (_, __) => _dispatchNodeStatusEvent(),
    );
    // Push identity phase transitions into the page (bridge v4) so SV
    // chrome can render login/provisioning progress and request node
    // start once the identity settles.
    ref.listenManual(
      identityProvider,
      (previous, next) {
        if (previous?.phase == next.phase &&
            previous?.address == next.address) {
          return;
        }
        _dispatchAuthStatusEvent();
        // A standalone dapp surface may have been entered while the
        // identity was still reconciling — retry the node ensure once it
        // settles to ready.
        if (next.phase == IdentityPhase.ready) {
          unawaited(_ensureNodeForStandaloneDappEntry());
        }
      },
    );
    _loadTxRecords();
    _loadDappTxIds();
    unawaited(_ensureNodeForStandaloneDappEntry());
  }

  /// Standalone dapp surfaces (widget/shortcut deep links to
  /// `/dapps/pinned/<id>`, `/dapps/<slug>` routes) can be entered on a cold
  /// start without the SV shell ever loading — and the shell is the only
  /// thing that requests a node start over bridge v4. Sends from every dapp
  /// surface go through the local node's wallet RPC, so without this a
  /// shell-bypassing entry leaves the node stopped and every send failing
  /// with "Node RPC unavailable". Mirrors the bridge `startNode` handler:
  /// identity-gated (startNode itself refuses unsettled identities), and
  /// block production stays gated by bp_released inside NodeService, so
  /// this cannot start producing for an unreleased user.
  ///
  /// No-op for the SV shell instance ([DappWebViewScreen.chromeless]) —
  /// the platform owns node lifecycle there — and while app sleep is
  /// active (the sleep service owns the node then).
  Future<void> _ensureNodeForStandaloneDappEntry() async {
    if (widget.chromeless) return;
    if (!mounted) return;
    if (RustBackendService.instance.isRunning) return;
    if (AppSleepStateStore.isSleeping) return;
    if (ref.read(identityProvider).phase != IdentityPhase.ready) return;
    // Same Android block-production wiring as the bridge startNode handler,
    // via the shared coordinator.
    await NodeLifecycleCoordinator.instance.startNode(
      reason: 'standalone_dapp_entry',
    );
  }

  /// Presents the OS file picker for a WebView `<input type="file">` tap
  /// and returns the chosen file URIs (empty list = user cancelled).
  Future<List<String>> _showAndroidFileSelector(
      FileSelectorParams params) async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
        type: _pickerTypeForAcceptTypes(params.acceptTypes),
      );
      if (result == null) return const [];
      return result.paths
          .whereType<String>()
          .map((path) => Uri.file(path).toString())
          .toList();
    } catch (e, st) {
      debugPrint('[webview file-chooser] pick failed: $e\n$st');
      return const [];
    }
  }

  /// Maps the input's `accept` MIME types to the closest picker filter.
  /// Mixed or unknown accept lists fall back to the unfiltered picker —
  /// the page still validates what it receives, this is just UX.
  FileType _pickerTypeForAcceptTypes(List<String> acceptTypes) {
    final types = acceptTypes
        .expand((t) => t.split(','))
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();
    if (types.isEmpty) return FileType.any;
    if (types.every((t) => t.startsWith('image/'))) return FileType.image;
    if (types.every((t) => t.startsWith('video/'))) return FileType.video;
    if (types.every((t) => t.startsWith('audio/'))) return FileType.audio;
    if (types.every((t) => t.startsWith('image/') || t.startsWith('video/'))) {
      return FileType.media;
    }
    return FileType.any;
  }

  /// `openExternal` JS-channel method: opens the given http(s) URL in the
  /// system browser. Non-web schemes are rejected so pages can't silently
  /// fire intent://, tel:, etc. through this path.
  Future<void> _handleOpenExternal(
      String id, Map<String, dynamic> payload) async {
    final args = payload['args'];
    final url = args is Map<String, dynamic> ? args['url']?.toString() : null;
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'openExternal requires an http(s) url',
      );
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    await _resolveJsPromise(
      id: id,
      value: launched,
      error: launched ? null : 'Could not open URL',
    );
  }

  /// Bridge protocol version. Bump only on breaking changes; additive
  /// methods just append to [_bridgeCapabilities] so SV chrome can
  /// feature-detect (`capabilities.includes(...)`) instead of duck-typing.
  static const int _bridgeVersion = 4;
  static const List<String> _bridgeCapabilities = [
    'getNodeAddress',
    'sendTransaction',
    'signMessage',
    'txObserved',
    'getHomeScreenShortcutSupport',
    'addHomeScreenShortcut',
    'getHomeScreenShortcuts',
    'removeHomeScreenShortcut',
    'reorderHomeScreenShortcuts',
    'openExternal',
    'getBridgeInfo',
    'getNodeStatus',
    'nodeStatusEvents',
    'getWalletState',
    'getTransactionRecords',
    'openNativeScreen',
    'getProfileInfo',
    'getSettingsState',
    'setNodeSleepEnabled',
    'setDebugMode',
    'setFacematchStrict',
    'resetZkChallenge',
    'requestPermissions',
    'openBatterySettings',
    'logout',
    // Bridge v4 (thin-shell migration): platform login + node lifecycle.
    'completeLogin',
    'startNode',
    'stopNode',
    'getAuthStatus',
    'authStatusEvents',
  ];

  /// One JSON shape shared by the `getNodeStatus` reply and the pushed
  /// `usernode:node-status` CustomEvent, so SV renders both identically.
  /// `status` is the chrome-level pill state (hysteresis applied):
  /// synced | syncing | connecting | offline.
  Map<String, dynamic> _nodeStatusSnapshot() {
    final chrome = ref.read(topStatusChromeNodeStatusProvider);
    final node = ref.read(nodeStatusProvider).valueOrNull;
    return {
      'status': chrome.name,
      'localBestHeight': node?.localBestHeight,
      'networkBestHeight': node?.networkBestHeight,
      'connectedPeers': node?.connectedPeers,
      'totalPeers': node?.totalPeers,
    };
  }

  /// Pushes the current node status into the page as a
  /// `usernode:node-status` CustomEvent, so SV's header pill can update
  /// without polling. Fired on chrome pill-state transitions and once per
  /// page load (see initState / onPageFinished).
  void _dispatchNodeStatusEvent() {
    final detail = jsonEncode(_nodeStatusSnapshot());
    _controller
        .runJavaScript('window.dispatchEvent(new CustomEvent('
            '"usernode:node-status", { detail: $detail }));')
        .catchError((_) {});
  }

  /// One JSON shape shared by the `getAuthStatus` reply and the pushed
  /// `usernode:auth-status` CustomEvent (bridge v4). `phase` is the
  /// identity phase name (unknown | transitioning | unauthenticated |
  /// guest | reconciling | ready); `address` is non-null only for a ready
  /// identity that owns a wallet — exactly what SV chrome needs to know
  /// when it may request a node start.
  Map<String, dynamic> _authStatusSnapshot() {
    final identity = ref.read(identityProvider);
    return {
      'phase': identity.phase.name,
      'address':
          identity.phase == IdentityPhase.ready ? identity.address : null,
    };
  }

  /// Pushes the current identity phase into the page as a
  /// `usernode:auth-status` CustomEvent (same convention as
  /// `usernode:node-status`) so SV chrome can render login/provisioning
  /// progress and knows when to request a node start.
  void _dispatchAuthStatusEvent() {
    final detail = jsonEncode(_authStatusSnapshot());
    _controller
        .runJavaScript('window.dispatchEvent(new CustomEvent('
            '"usernode:auth-status", { detail: $detail }));')
        .catchError((_) {});
  }

  /// `completeLogin` (bridge v4): the platform hands over the mobile
  /// bearer token it minted from its own web session
  /// (POST /api/v4/mobile/auth/from-session) plus that response's `user`
  /// object. Runs the same identity transition a native sign-in used to:
  /// SessionController.completeLogin stages the credential and suspends
  /// the node, then the reconciler provisions/imports the custodial
  /// wallet. Resolves the settled auth snapshot — WITHOUT starting the
  /// node (node lifecycle is platform-controlled; SV calls startNode).
  Future<void> _handleCompleteLogin(
      String id, Map<String, dynamic> payload) async {
    if (!await _requireTrustedChromeOrigin(id, 'completeLogin')) return;
    final args = payload['args'];
    final token =
        args is Map<String, dynamic> ? args['token']?.toString() : null;
    final user = args is Map<String, dynamic> && args['user'] is Map
        ? (args['user'] as Map).cast<String, dynamic>()
        : null;
    if (token == null || token.isEmpty || user == null || user['id'] is! num) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'args.token (string) and args.user ({id, ...}) are required',
      );
      return;
    }
    final session = AuthSession(
      token: token,
      participant: Participant(
        id: (user['id'] as num).toInt(),
        // Web-only platform accounts may have no email; the identity
        // machinery keys off the participant id, so an empty string is
        // safe here.
        email: user['email']?.toString() ?? '',
        emailConfirmed: user['email_confirmed'] == true,
        displayName: user['display_name']?.toString(),
      ),
    );

    // Idempotent boot handoff: SV re-runs this on every shell boot. When
    // the same user is already settled, don't tear the identity down just
    // to rebuild it.
    final current = ref.read(identityProvider);
    if (current.phase == IdentityPhase.ready &&
        current.participantId == session.participant.id) {
      await _resolveJsPromise(
          id: id, value: _authStatusSnapshot(), error: null);
      return;
    }

    await ref.read(identityProvider.notifier).completeLogin(session);
    // The identity driver also reacts to the reconciling publish; the
    // reconciler coalesces per epoch so this direct call just gives the
    // page a Future that settles when provisioning is done.
    try {
      await ref.read(nodeAccountReconcilerProvider).reconcile();
    } catch (e) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Wallet provisioning failed: $e',
      );
      return;
    }
    await _resolveJsPromise(id: id, value: _authStatusSnapshot(), error: null);
  }

  /// `startNode` (bridge v4): platform-requested node start, bound to the
  /// current identity's wallet. Refused unless the identity is settled
  /// (ready) and the requested address (when provided) matches it — the
  /// page can never start the node under someone else's account.
  Future<void> _handleStartNode(String id, Map<String, dynamic> payload) async {
    if (!await _requireTrustedChromeOrigin(id, 'startNode')) return;
    final args = payload['args'];
    final address =
        args is Map<String, dynamic> ? args['address']?.toString() : null;
    final identity = ref.read(identityProvider);
    if (identity.phase != IdentityPhase.ready) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Identity is ${identity.phase.name}; node start requires a '
            'settled (ready) identity',
      );
      return;
    }
    if (address != null && address.isNotEmpty && address != identity.address) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'address does not belong to the current identity',
      );
      return;
    }
    // The coordinator owns the Android block-production wiring (watchdog
    // recovery, audit, foreground service) atomically with the start.
    final started = await NodeLifecycleCoordinator.instance.startNode(
      reason: 'platform_start',
    );
    await _resolveJsPromise(
      id: id,
      value: {'started': started, 'nodeStatus': _nodeStatusSnapshot()},
      error: started ? null : 'Node failed to start',
    );
  }

  /// `stopNode` (bridge v4): platform-requested node stop. Idempotent —
  /// stopping an already-stopped node resolves normally.
  Future<void> _handleStopNode(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'stopNode')) return;
    await NodeLifecycleCoordinator.instance.stopNode(reason: 'platform_stop');
    await _resolveJsPromise(id: id, value: {'stopped': true}, error: null);
  }

  /// `getAuthStatus` (bridge v4): poll-style twin of the
  /// `usernode:auth-status` event, for boot-time orchestration.
  Future<void> _handleGetAuthStatus(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'getAuthStatus')) return;
    await _resolveJsPromise(id: id, value: _authStatusSnapshot(), error: null);
  }

  /// Reports the first main-frame load outcome exactly once (shell
  /// first-launch gate). Success and failure race; whichever navigation
  /// callback lands first wins.
  void _reportFirstLoadResult(bool ok) {
    if (_firstLoadReported) return;
    _firstLoadReported = true;
    widget.onFirstLoadResult?.call(ok);
  }

  Future<void> _handleGetWalletState(String id) async {
    // Unavailable-shaped response (all nulls) unless the identity owns a
    // wallet: mid-reconcile and guest sessions must not be served the
    // registry's active account or its cached balance.
    final identity = _bridgeWalletIdentity();
    if (identity == null) {
      await _resolveJsPromise(
        id: id,
        value: {
          'address': null,
          'balance': null,
          'tokenAmount': null,
          'tokenSymbol': null,
          'lastUpdatedMs': null,
        },
        error: null,
      );
      return;
    }
    final address = identity.address;
    // First read lazily initializes the provider; wait briefly for the
    // initial load so a fresh page doesn't always see nulls, but never
    // hang the page's promise on a slow node.
    WalletState? wallet;
    try {
      wallet = await ref
          .read(walletProvider.future)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      wallet = ref.read(walletProvider).valueOrNull;
    }
    final balance = wallet?.balance;
    await _resolveJsPromise(
      id: id,
      value: {
        'address': address,
        // Base units as a string (BigInt-safe for JS consumers).
        'balance': balance?.totalBalance.toString(),
        'tokenAmount': balance?.tokenAmount,
        'tokenSymbol': balance?.tokenSymbol,
        'lastUpdatedMs': balance?.lastUpdated?.millisecondsSinceEpoch,
      },
      error: null,
    );
  }

  /// Returns this webview's persisted dapp-transaction receipts (the same
  /// `_TxRecord` list backing the native receipts sheet), newest first.
  Future<void> _handleGetTransactionRecords(String id) async {
    final records = _txRecords.values.toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    await _resolveJsPromise(
      id: id,
      value: {
        'items': [for (final r in records.take(100)) r.toJson()],
      },
      error: null,
    );
  }

  /// `openNativeScreen` JS-channel method: pushes an allowlisted native
  /// route. Escape hatch for the tooling that stays native — diagnostics,
  /// the device benchmark, and the HTTP log viewer (debugging UIs over
  /// native-only data). Only the trusted SV origin may drive native
  /// navigation — sub-apps get a rejection.
  Future<void> _handleOpenNativeScreen(
      String id, Map<String, dynamic> payload) async {
    const allowedScreens = <String, String>{
      'diagnostics': AppRoutes.diagnostics,
      'benchmark': AppRoutes.deviceBenchmark,
      'httpLogs': AppRoutes.httpDebugLogs,
    };
    final args = payload['args'];
    final screen =
        args is Map<String, dynamic> ? args['screen']?.toString() : null;
    final route = screen == null ? null : allowedScreens[screen];
    if (route == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Unknown screen; allowed: ${allowedScreens.keys.join(', ')}',
      );
      return;
    }
    if (!await _isTrustedShortcutOrigin()) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'openNativeScreen is only available to the dapps home',
      );
      return;
    }
    if (!mounted) return;
    context.push(route);
    await _resolveJsPromise(id: id, value: true, error: null);
  }

  /// Shared gate for the bridge v3 profile/settings methods: they read and
  /// mutate app-level native state, so only the trusted SV origin may call
  /// them. Rejects the JS promise and returns false for anyone else.
  Future<bool> _requireTrustedChromeOrigin(String id, String method) async {
    if (await _isTrustedShortcutOrigin()) return true;
    await _resolveJsPromise(
      id: id,
      value: null,
      error: '$method is only available to the dapps home',
    );
    return false;
  }

  bool _identityScopeIsCurrent(Identity identity) =>
      mounted && identity.sameScopeAs(ref.read(identityProvider));

  Future<void> _rejectStaleIdentityScope(String id, String method) async {
    if (!mounted) return;
    await _resolveJsPromise(
      id: id,
      value: null,
      error: '$method was cancelled because the active identity changed',
    );
  }

  /// `getProfileInfo`: the leaderboard participant id SV's #profile screen
  /// needs to query /me/ranking and /me/breakdown. Null when this install
  /// hasn't registered with the leaderboard yet.
  Future<void> _handleGetProfileInfo(String id) async {
    final identity = ref.read(identityProvider);
    if (!await _requireTrustedChromeOrigin(id, 'getProfileInfo')) return;
    if (!_identityScopeIsCurrent(identity)) {
      await _rejectStaleIdentityScope(id, 'getProfileInfo');
      return;
    }
    await _resolveJsPromise(
      id: id,
      // Use only the captured identity. The participant-id provider may still
      // hold the previous bucket's value while an identity transition settles.
      value: {'participantId': identity.participantId},
      error: null,
    );
  }

  /// One JSON shape shared by `getSettingsState` and every settings setter
  /// (each setter resolves with the refreshed state so SV re-renders from a
  /// single source of truth). Mirrors what the native settings screen shows.
  Future<Map<String, dynamic>> _settingsStateSnapshot() async {
    // Permission checks mirror the native QuickSettingsPanel wiring.
    bool exactAlarmGranted = false;
    bool? batteryOptDisabled;
    String? deviceManufacturer;
    try {
      await PlatformAlarmService.instance.initialize();
      exactAlarmGranted = PlatformAlarmService.instance.hasPermissions;
      if (defaultTargetPlatform == TargetPlatform.android) {
        batteryOptDisabled =
            await PlatformAlarmService.instance.isBatteryOptimizationDisabled();
        deviceManufacturer =
            await PlatformAlarmService.instance.getDeviceManufacturer();
      }
    } catch (e) {
      debugPrint('[Usernode JS-channel] permission probe failed: $e');
    }

    PackageInfo? packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {}

    String? nodeVersion;
    String? commitHash;
    String? branch;
    try {
      final env = ref.read(buildEnvProvider);
      nodeVersion = env.version;
      final hash = env.git.commitHash;
      commitHash = hash.length >= 7 ? hash.substring(0, 7) : hash;
      branch = env.git.branch;
    } catch (_) {}

    final facematchStrict = ref
            .read(zkPassportSettingsProvider)
            .whenOrNull(data: (s) => s.facematchStrict) ??
        true;

    return {
      'buildInfo': {
        'appVersion': packageInfo?.version,
        'buildNumber': packageInfo?.buildNumber,
        'nodeVersion': nodeVersion,
        'commitHash': commitHash,
        'branch': branch,
      },
      'nodeSleepEnabled': AppSleepService.instance.isEnabled,
      'debugMode': ref.read(debugModeProvider),
      'facematchStrict': facematchStrict,
      // Terms moved to the SV web settings (session-authed /challenges-api
      // terms routes) — no native terms state remains.
      'authStatus': ref.read(authStatusProvider).name,
      'permissions': {
        'platform':
            defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios',
        'exactAlarmGranted': exactAlarmGranted,
        'batteryOptDisabled': batteryOptDisabled,
        'deviceManufacturer': deviceManufacturer,
      },
    };
  }

  Future<void> _handleGetSettingsState(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'getSettingsState')) return;
    await _resolveJsPromise(
      id: id,
      value: await _settingsStateSnapshot(),
      error: null,
    );
  }

  /// Extracts a required bool from `payload.args[key]`; rejects the promise
  /// and returns null when missing or mistyped.
  Future<bool?> _requireBoolArg(
      String id, Map<String, dynamic> payload, String key) async {
    final args = payload['args'];
    final value = args is Map<String, dynamic> ? args[key] : null;
    if (value is bool) return value;
    await _resolveJsPromise(
      id: id,
      value: null,
      error: 'args.$key (bool) is required',
    );
    return null;
  }

  Future<void> _handleSetNodeSleepEnabled(
      String id, Map<String, dynamic> payload) async {
    if (!await _requireTrustedChromeOrigin(id, 'setNodeSleepEnabled')) return;
    final enabled = await _requireBoolArg(id, payload, 'enabled');
    if (enabled == null) return;
    await AppSleepService.instance.setEnabled(enabled);
    await _resolveJsPromise(
      id: id,
      value: await _settingsStateSnapshot(),
      error: null,
    );
  }

  Future<void> _handleSetDebugMode(
      String id, Map<String, dynamic> payload) async {
    if (!await _requireTrustedChromeOrigin(id, 'setDebugMode')) return;
    final enabled = await _requireBoolArg(id, payload, 'enabled');
    if (enabled == null) return;
    await ref.read(debugModeProvider.notifier).set(enabled);
    await _resolveJsPromise(
      id: id,
      value: await _settingsStateSnapshot(),
      error: null,
    );
  }

  Future<void> _handleSetFacematchStrict(
      String id, Map<String, dynamic> payload) async {
    if (!await _requireTrustedChromeOrigin(id, 'setFacematchStrict')) return;
    final enabled = await _requireBoolArg(id, payload, 'enabled');
    if (enabled == null) return;
    await ref.read(zkPassportFlowControllerProvider).setFacematchStrict(
          enabled,
        );
    await _resolveJsPromise(
      id: id,
      value: await _settingsStateSnapshot(),
      error: null,
    );
  }

  /// `resetZkChallenge`: same reset the native settings screen offers.
  /// Confirmation happens web-side; this is the commit.
  Future<void> _handleResetZkChallenge(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'resetZkChallenge')) return;
    if (!mounted) return;
    final reset = await resetChallengeState(ref, context);
    if (!reset) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error:
            'A zkPassport proof is still being processed. Try again shortly.',
      );
      return;
    }
    await _resolveJsPromise(id: id, value: true, error: null);
  }

  Future<void> _handleRequestPermissions(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'requestPermissions')) return;
    final granted = await PlatformAlarmService.instance.requestPermissions();
    final state = await _settingsStateSnapshot();
    await _resolveJsPromise(
      id: id,
      value: {...state, 'granted': granted},
      error: null,
    );
  }

  Future<void> _handleOpenBatterySettings(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'openBatterySettings')) return;
    await PlatformAlarmService.instance.openBatteryOptimizationSettings();
    await _resolveJsPromise(id: id, value: true, error: null);
  }

  /// `logout`: web-side confirm, native commit. The router's auth guard
  /// takes over from here (post-logout flow stays native chrome, same
  /// category as onboarding).
  Future<void> _handleLogout(String id) async {
    final identity = ref.read(identityProvider);
    if (!await _requireTrustedChromeOrigin(id, 'logout')) return;
    if (!_identityScopeIsCurrent(identity)) {
      await _rejectStaleIdentityScope(id, 'logout');
      return;
    }
    final loggedOut = await ref
        .read(identityProvider.notifier)
        .logout(expectedIdentity: identity);
    if (!loggedOut) {
      await _rejectStaleIdentityScope(id, 'logout');
      return;
    }
    await _resolveJsPromise(id: id, value: true, error: null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _providersContainer ??= ProviderScope.containerOf(context, listen: false);
    _controller.setBackgroundColor(
        Theme.of(context).colorScheme.surfaceContainerLowest);
  }

  @override
  void dispose() {
    _confirmPoller?.cancel();
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  /// Debug builds only: reports whether the page can (and did) register a
  /// service worker. On iOS this verifies the App-Bound Domains opt-in took
  /// effect (without it, `navigator.serviceWorker` is undefined in
  /// WKWebView). Output lands in the piped webview console logs.
  void _logServiceWorkerStateForDebug() {
    if (!kDebugMode) return;
    _controller.runJavaScript('''
      (function () {
        if (!('serviceWorker' in navigator)) {
          console.log('[sw-check] navigator.serviceWorker unavailable');
          return;
        }
        navigator.serviceWorker.getRegistration().then(function (reg) {
          console.log('[sw-check] serviceWorker available; registration: '
            + (reg ? reg.scope : 'none'));
        }).catch(function (e) {
          console.log('[sw-check] getRegistration failed: ' + e);
        });
      })();
    ''').catchError((_) {});
  }

  Future<void> _refreshPageTitle() async {
    // The page is driving titles via the JS channel, so getTitle() is no
    // longer a reliable source — WKWebView lags behind the page's own
    // `document.title` writes by enough that an onUrlChange-triggered
    // refresh routinely returns the *previous* screen's title. Bail out
    // and trust whatever the channel set on us.
    if (_titleFromChannel) return;
    try {
      final title = await _controller.getTitle();
      if (!mounted) return;
      // Re-check the latch after the async gap; a `titleChanged` message
      // may have arrived while we were awaiting getTitle().
      if (_titleFromChannel) return;
      final normalized = title?.trim();
      if (normalized == _pageTitle) return;
      setState(() {
        _pageTitle = normalized;
      });
    } catch (_) {
      // Ignore — title is purely cosmetic, fallback is widget.name.
    }
  }

  // Refreshes [_canGoBack] from the WebView session history so the tab-root
  // bar can flip between shell affordances (hub root) and browser chrome
  // (drilled into a dapp). No-op visual cost when the value is unchanged.
  Future<void> _refreshCanGoBack() async {
    if (!widget.embedded) return;
    try {
      final canGoBack = await _controller.canGoBack();
      if (!mounted || canGoBack == _canGoBack) return;
      setState(() => _canGoBack = canGoBack);
    } catch (_) {
      // Ignore — bar mode is cosmetic; defaults to shell at the root.
    }
  }

  void _toggleUrlEditor() {
    setState(() {
      _showUrlEditor = !_showUrlEditor;
    });

    if (!_showUrlEditor) return;

    () async {
      try {
        final current = await _controller.currentUrl();
        if (!mounted) return;
        if (!_showUrlEditor) return;
        if (_urlController.text.trim().isNotEmpty) return;
        _urlController.text = current ?? '';
      } catch (_) {
        // Ignore.
      }
    }();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _urlFocusNode.requestFocus();
    });
  }

  Future<void> _loadUrlFromInput() async {
    final trimmed = _urlController.text.trim();
    if (trimmed.isEmpty) return;
    final uri = parseDappUrl(trimmed);
    await _controller.loadRequest(uri);
  }

  /// The identity whose wallet this bridge may expose, or null when there is
  /// none: reconciling/unknown (account ownership unsettled) and guest
  /// sessions (the active registry account may belong to a previously
  /// signed-in user) get nothing. When non-null, [Identity.address] is the
  /// confirmed wallet address — handlers use it instead of reading the
  /// registry's active account, so a mid-transition registry state can never
  /// leak another identity's address.
  Identity? _bridgeWalletIdentity() {
    final identity = IdentitySnapshots.current;
    if (!identity.allowsSigning) return null;
    return identity;
  }

  Future<void> _resolveJsPromise({
    required String id,
    required Object? value,
    required String? error,
  }) async {
    final js = 'window.__usernodeResolve(${jsonEncode(id)},'
        ' ${jsonEncode(value)}, ${jsonEncode(error)});';
    try {
      await _controller.runJavaScript(js);
    } catch (_) {
      // Ignore callback failures.
    }
  }

  Future<void> _handleSendTransaction(
      String id, Map<String, dynamic> payload) async {
    // Route-level gating cannot cover this bridge (every dApp webview can
    // request a send) — enforce identity readiness at the signing chokepoint
    // itself. While a reconcile is pending the active account may still
    // belong to a previous user; guests never sign. The snapshot is CAPTURED
    // here and revalidated right before the RPC send: this handler spans a
    // user-paced confirmation dialog, during which a login/logout/rollover
    // can replace the identity out from under the entry check.
    final signingIdentity = _bridgeWalletIdentity();
    if (signingIdentity == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Account is being set up; please retry in a moment.',
      );
      return;
    }
    final args = payload['args'];
    if (args is! Map<String, dynamic>) {
      await _resolveJsPromise(id: id, value: null, error: 'Missing args');
      return;
    }

    final destinationPubkey = (args['destination_pubkey'] as String?)?.trim();
    final amountRaw = args['amount'];
    final memoString = _parseMemoString(args['memo']);
    final confirmTitle = (args['confirm_title'] as String?)?.trim();
    final confirmSubtitle = (args['confirm_subtitle'] as String?)?.trim();

    if (destinationPubkey == null || destinationPubkey.isEmpty) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'destination_pubkey is required',
      );
      return;
    }

    final amount = _parseAmountToBigInt(amountRaw);
    if (amount == null) {
      await _resolveJsPromise(id: id, value: null, error: 'Invalid amount');
      return;
    }

    if (memoString == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Invalid memo; expected UTF-8 string',
      );
      return;
    }
    final memo = frb_types.Memo.fromUtf8Str(s: memoString);

    // The sender is the CAPTURED identity's confirmed address — never the
    // registry's active account, which a mid-transition reconcile may have
    // already switched to another user's.
    final fromAddress = signingIdentity.address;
    if (fromAddress == null || fromAddress.isEmpty) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'No active account/address available',
      );
      return;
    }

    final userConfirmed = await _requestTransactionConfirmation(
      from: fromAddress,
      to: destinationPubkey,
      amount: amount,
      memo: memoString,
      confirmTitle: confirmTitle,
      confirmSubtitle: confirmSubtitle,
    );

    if (!userConfirmed) {
      _addRecord(_TxRecord(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        sentAt: DateTime.now(),
        from: fromAddress,
        to: destinationPubkey,
        amount: amount,
        memo: memoString,
        status: _TxStatus.denied,
      ));
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'User denied the transaction',
      );
      return;
    }

    if (AppConfig.viewOnly) {
      const errorMessage = 'Transactions are disabled in view-only mode.';
      _addRecord(_TxRecord(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        sentAt: DateTime.now(),
        from: fromAddress,
        to: destinationPubkey,
        amount: amount,
        memo: memoString,
        status: _TxStatus.error,
        errorMessage: errorMessage,
      ));
      await _resolveJsPromise(
        id: id,
        value: null,
        error: errorMessage,
      );
      return;
    }

    // Effect-point revalidation: the confirmation dialog above is unbounded
    // user time. If the identity transitioned since capture, the runtime's
    // wallet signer no longer (or may no longer) belong to the identity the
    // user confirmed for — refuse instead of signing as someone else.
    if (IdentitySnapshots.current.epoch != signingIdentity.epoch) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'The signed-in account changed; please retry the transaction.',
      );
      return;
    }

    final fromPkHash = frb_types.publicKeyHashFromString(s: fromAddress);
    final toPkHash = frb_types.publicKeyHashFromString(s: destinationPubkey);

    final rpc = RustBackendService.instance.rpc;
    if (rpc == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Node RPC unavailable',
      );
      return;
    }

    final resp = await rpc.wallet().txSendResult(
          fromPkHash: fromPkHash,
          amount: amount,
          toPkHash: toPkHash,
          memo: memo,
        );

    final rpcError = resp?.error;
    final isQueued = resp?.queued ?? false;
    final recordId =
        resp?.txId ?? 'local_${DateTime.now().millisecondsSinceEpoch}';
    _addRecord(_TxRecord(
      id: recordId,
      sentAt: DateTime.now(),
      from: fromAddress,
      to: destinationPubkey,
      amount: amount,
      memo: memoString,
      status: isQueued ? _TxStatus.queued : _TxStatus.error,
      errorMessage: rpcError,
    ));

    if (isQueued && resp?.txId != null) {
      _ensureConfirmPoller();
    }

    await _resolveJsPromise(
      id: id,
      value: <String, dynamic>{
        'queued': isQueued,
        'error': rpcError,
      },
      error: null,
    );
  }

  Future<void> _handleSignMessage(
      String id, Map<String, dynamic> payload) async {
    // Same identity gate as _handleSendTransaction: this handler loads the
    // active account's private key, which must never happen while account
    // ownership is unsettled or for a guest. Captured once, revalidated at
    // the key-load effect point below.
    final signingIdentity = _bridgeWalletIdentity();
    if (signingIdentity == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Account is being set up; please retry in a moment.',
      );
      return;
    }
    final args = payload['args'];
    if (args is! Map<String, dynamic>) {
      await _resolveJsPromise(id: id, value: null, error: 'Missing args');
      return;
    }

    final message = (args['message'] as String?)?.trim();
    if (message == null || message.isEmpty) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'message is required',
      );
      return;
    }

    final repo = await _providers.read(accountsProvider.future);
    final active = await repo.getActive();
    if (active == null || active.address != signingIdentity.address) {
      // The registry's active account must be the captured identity's — a
      // mismatch means a transition is mutating the registry mid-request.
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'No active account available',
      );
      return;
    }

    final confirmed = await _requestSignatureConfirmation();
    if (!confirmed) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'User denied the signature request',
      );
      return;
    }

    // Effect-point revalidation after the user-paced confirmation dialog —
    // the private key is loaded on the next line.
    if (IdentitySnapshots.current.epoch != signingIdentity.epoch) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'The signed-in account changed; please retry the request.',
      );
      return;
    }

    final secretKey = await repo.getSecretKey(active.id);
    if (secretKey == null || secretKey.isEmpty) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Secret key unavailable',
      );
      return;
    }

    if (!signingIdentity.sameScopeAs(IdentitySnapshots.current)) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'The signed-in account changed; please retry the request.',
      );
      return;
    }

    try {
      final signature = frb_account.signMessage(
        secretKey: secretKey,
        message: message,
      );
      await _resolveJsPromise(
        id: id,
        value: <String, dynamic>{
          'pubkey': active.address,
          'publicKey': active.publicKey,
          'signature': signature,
        },
        error: null,
      );
    } catch (e) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Signing failed: $e',
      );
    }
  }

  Future<bool> _requestSignatureConfirmation() async {
    if (!mounted) return false;
    final theme = Theme.of(context);

    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder<bool>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (ctx, _, __) {
          final spacing = Theme.of(ctx).extension<AppSpacing>()!;
          final sizing = Theme.of(ctx).extension<AppSizing>()!;
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => Navigator.pop(ctx, false),
                icon: const Icon(Symbols.close),
              ),
              title: const Text('Verify Identity'),
              titleSpacing: 0,
            ),
            body: Padding(
              padding: EdgeInsets.all(spacing.space24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Symbols.verified_user,
                    size: sizing.iconDisplay,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(height: spacing.space16),
                  Text(
                    '${widget.name} is requesting to verify your identity',
                    style: Theme.of(ctx).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.space12),
                  Text(
                    'This will sign a challenge with your private key to '
                    'prove you own this wallet. No transaction will be sent '
                    'and no tokens will be spent.',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Button(
                          label: 'Deny',
                          variant: ButtonVariant.outlined,
                          onTap: () => Navigator.pop(ctx, false),
                        ),
                      ),
                      SizedBox(width: spacing.space12),
                      Expanded(
                        child: Button(
                          label: 'Approve',
                          variant: ButtonVariant.primary,
                          onTap: () => Navigator.pop(ctx, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            )),
            child: child,
          );
        },
      ),
    );
    return result ?? false;
  }

  // ── Homescreen shortcuts (bridge) ─────────────────────────────────────
  //
  // `addHomeScreenShortcut` lets a dapp request a device-homescreen entry
  // that reopens the app at `usernode://app/dapps/pinned/<id>`. Android
  // pins a real launcher shortcut; iOS mirrors the pinned registry into the
  // App Group storage consumed by the UsernodeWidgets WidgetKit extension.

  static const _maxShortcutNameLength = 48;
  static const _maxShortcutIconBytes = 2 * 1024 * 1024;

  Future<Map<String, dynamic>> _shortcutSupport() async {
    if (HomeShortcutsChannel.isAndroid) {
      final supported = await HomeShortcutsChannel.isPinShortcutSupported();
      return {'mechanism': supported ? 'pinned-shortcut' : 'unsupported'};
    }
    if (HomeShortcutsChannel.isIOS) {
      final installed = await HomeShortcutsChannel.isWidgetInstalled();
      return {'mechanism': 'widget', 'widgetInstalled': installed};
    }
    return {'mechanism': 'unsupported'};
  }

  Future<void> _handleGetHomeScreenShortcutSupport(String id) async {
    await _resolveJsPromise(
      id: id,
      value: await _shortcutSupport(),
      error: null,
    );
  }

  static bool _isLocalDevHost(String host) =>
      host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';

  /// Accepts https URLs, plus http for local development hosts only.
  ///
  /// Deliberately NOT `uri.isAbsolute`: that is false for any URL carrying
  /// a `#fragment` (RFC 3986 "absolute URI"), which rejected legitimate
  /// SPA deep links like `https://host/#app/slug`. Scheme + host checks
  /// below are what we actually need.
  static Uri? _parseShortcutUrl(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme == 'https') return uri;
    if (uri.scheme == 'http' && _isLocalDevHost(uri.host)) return uri;
    return null;
  }

  /// Inline `data:image/*;base64,...` icons. The dapps home renders its
  /// emoji/letter tiles to a canvas PNG so the homescreen widget shows
  /// the exact same tile — no server round-trip, same size cap as
  /// downloads.
  static Uint8List? _decodeDataUriIcon(Object? raw) {
    if (raw is! String || !raw.startsWith('data:image/')) return null;
    try {
      final bytes = UriData.parse(raw).contentAsBytes();
      if (bytes.isEmpty || bytes.length > _maxShortcutIconBytes) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _downloadShortcutIcon(Uri iconUri) async {
    final client = http.Client();
    try {
      // followRedirects: false so a 3xx can't bounce us to a loopback/internal
      // host that _parseShortcutUrl already rejected for the original URL
      // (SSRF). Anything other than a direct 200 is treated as a miss.
      final request = http.Request('GET', iconUri)..followRedirects = false;
      final res =
          await client.send(request).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;

      // Reject up front when the server declares an oversized body, then cap
      // again while streaming so a missing/lying Content-Length can't OOM the
      // device before the post-hoc length check would have run.
      final declaredLength = res.contentLength;
      if (declaredLength != null && declaredLength > _maxShortcutIconBytes) {
        return null;
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk
          in res.stream.timeout(const Duration(seconds: 10))) {
        builder.add(chunk);
        if (builder.length > _maxShortcutIconBytes) return null;
      }
      if (builder.isEmpty) return null;
      return builder.takeBytes();
    } catch (e) {
      debugPrint('[HomeShortcuts] icon download failed: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// True when the top frame currently shows the configured dapps-tab
  /// home (social vibecoding) — the only page trusted to manage
  /// homescreen shortcuts. Sub-apps live on their own subdomains (or are
  /// iframes whose relayed calls the SV bridge refuses to forward), so
  /// an exact origin match on the current URL is the boundary. Local-dev
  /// hosts pass so `--local-dev` SV builds stay testable.
  Future<bool> _isTrustedShortcutOrigin() async {
    final raw = await _controller.currentUrl();
    final current = raw == null ? null : Uri.tryParse(raw);
    if (current == null || current.host.isEmpty) return false;
    if (_isLocalDevHost(current.host)) return true;
    final trusted = Uri.tryParse(AppConfig.dappsTabUrl);
    if (trusted == null || trusted.host.isEmpty) return false;
    return current.scheme == trusted.scheme &&
        current.host == trusted.host &&
        current.port == trusted.port;
  }

  /// Shared deny-path for the shortcut management handlers. Returns
  /// false (after rejecting the JS promise) when the calling page isn't
  /// the dapps home.
  Future<bool> _guardTrustedShortcutOrigin(String id) async {
    if (await _isTrustedShortcutOrigin()) return true;
    await _resolveJsPromise(
      id: id,
      value: null,
      error: 'Homescreen shortcuts can only be managed by the dapps home',
    );
    return false;
  }

  Future<void> _handleAddHomeScreenShortcut(
      String id, Map<String, dynamic> payload) async {
    // Trust gate instead of a confirmation screen: the dapps-tab home
    // (social vibecoding) curates its own "add to widget/homescreen" UX,
    // so requests from it are auto-approved; every other page is denied
    // outright. Shortcuts only deep-link back into this app, so the
    // blast radius of a bad add is a launcher tile — not funds.
    if (!await _guardTrustedShortcutOrigin(id)) return;
    final args = payload['args'];
    if (args is! Map<String, dynamic>) {
      await _resolveJsPromise(id: id, value: null, error: 'Missing args');
      return;
    }

    var name = (args['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      await _resolveJsPromise(id: id, value: null, error: 'name is required');
      return;
    }
    if (name.length > _maxShortcutNameLength) {
      name = name.substring(0, _maxShortcutNameLength);
    }

    final url = _parseShortcutUrl(args['url']);
    if (url == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'url must be a valid https URL',
      );
      return;
    }

    final support = await _shortcutSupport();
    if (support['mechanism'] == 'unsupported') {
      await _resolveJsPromise(
        id: id,
        value: <String, dynamic>{'added': false, ...support},
        error: null,
      );
      return;
    }

    final rawIcon = args['icon_url'];
    Uint8List? iconBytes = _decodeDataUriIcon(rawIcon);
    Uri? iconUri;
    if (iconBytes == null) {
      iconUri = _parseShortcutUrl(rawIcon);
      if (iconUri != null) iconBytes = await _downloadShortcutIcon(iconUri);
    }

    final pinned = await _providers.read(pinnedDappsProvider.notifier).pin(
          name: name,
          url: url.toString(),
          // Data-URI icons are not persisted in the registry (kilobytes
          // of base64 in prefs for no reader); the PNG lands in the App
          // Group icon store below either way.
          iconUrl: iconUri?.toString() ?? '',
        );
    final deepLink = 'usernode://app${AppRoutes.dappPinnedFor(pinned.id)}';

    if (HomeShortcutsChannel.isAndroid) {
      final requested = await HomeShortcutsChannel.requestPinShortcut(
        id: pinned.id,
        label: pinned.name,
        deepLink: deepLink,
        iconBytes: iconBytes,
      );
      await _resolveJsPromise(
        id: id,
        value: <String, dynamic>{
          'added': requested,
          'mechanism': 'pinned-shortcut',
        },
        error: null,
      );
      return;
    }

    // iOS: mirror the registry into the App Group so the widget extension
    // can render it, then walk the user through adding the widget if it
    // isn't on the homescreen yet.
    if (iconBytes != null) {
      await HomeShortcutsChannel.saveWidgetIcon(pinned.id, iconBytes);
    }
    // Report the real sync result rather than a hardcoded true: if the App
    // Group is unavailable the native side returns false and nothing reaches
    // the widget, so a caller that trusted `added: true` would show the dapp
    // as pinned over an empty widget.
    final added = await _syncPinnedToWidget();
    // `widgetInstalled` was already fetched by `_shortcutSupport()` above
    // (whether the widget is on the homescreen doesn't change from pinning),
    // so reuse it instead of a second platform round-trip.
    final widgetInstalled = support['widgetInstalled'] == true;
    // silent: background refresh (icon heal) — never interrupt with the
    // add-the-widget walkthrough.
    final silent = args['silent'] == true;
    // Resolve the JS promise before showing the (modal, pop-to-dismiss)
    // walkthrough — otherwise the page's `await addHomeScreenShortcut(...)`
    // stays pending for as long as the user leaves the walkthrough open.
    await _resolveJsPromise(
      id: id,
      value: <String, dynamic>{
        'added': added,
        'mechanism': 'widget',
        'widgetInstalled': widgetInstalled,
      },
      error: null,
    );
    if (added && !widgetInstalled && !silent && mounted) {
      await _showWidgetInstructions(name);
    }
  }

  /// Mirrors the pinned registry (in registry order — the widget grid
  /// renders the synced JSON array as-is) into the App Group defaults and
  /// reloads the widget timelines. Returns whether the native write
  /// succeeded; treats non-iOS as a successful no-op.
  Future<bool> _syncPinnedToWidget() async {
    if (!HomeShortcutsChannel.isIOS) return true;
    final dapps = await _providers.read(pinnedDappsProvider.future);
    return HomeShortcutsChannel.syncPinnedDapps(jsonEncode([
      for (final d in dapps)
        {
          'id': d.id,
          'name': d.name,
          'deepLink': 'usernode://app${AppRoutes.dappPinnedFor(d.id)}',
          'pinnedAtMs': d.pinnedAtMs,
        },
    ]));
  }

  /// Registry snapshot for the page: ids, names, urls and pin order. The
  /// url lets the caller match entries back to its own content (e.g. SV
  /// matching `#app/<slug>` deep links to its app cards). This is launcher
  /// metadata the page's own user created; no secrets involved.
  ///
  /// `has_icon` (iOS only) flags entries whose PNG made it into the App
  /// Group icon store. Entries pinned before the page sent icons — or
  /// whose icon download failed — report false, and the dapps home heals
  /// them by re-calling addHomeScreenShortcut (re-pinning is idempotent:
  /// same URL, same id).
  Future<void> _handleGetHomeScreenShortcuts(String id) async {
    if (!await _guardTrustedShortcutOrigin(id)) return;
    // These three reads are independent — fetch them concurrently rather than
    // paying a prefs read plus two platform round-trips in series.
    final (dapps, iconIds, support) = await (
      _providers.read(pinnedDappsProvider.future),
      HomeShortcutsChannel.isIOS
          ? HomeShortcutsChannel.listWidgetIconIds()
          : Future.value(const <String>{}),
      _shortcutSupport(),
    ).wait;
    await _resolveJsPromise(
      id: id,
      value: <String, dynamic>{
        ...support,
        'items': [
          for (final d in dapps)
            {
              'id': d.id,
              'name': d.name,
              'url': d.url,
              'pinnedAtMs': d.pinnedAtMs,
              'has_icon': !HomeShortcutsChannel.isIOS || iconIds.contains(d.id),
            },
        ],
      },
      error: null,
    );
  }

  /// Removes a pinned entry and re-syncs the iOS widget. No native
  /// confirmation: launcher entries are low-stakes and the calling UI
  /// (e.g. SV's widget section) puts the control behind a deliberate tap.
  /// On Android this only clears the registry — launchers offer no
  /// programmatic un-pin, so the callers there never expose remove.
  Future<void> _handleRemoveHomeScreenShortcut(
      String id, Map<String, dynamic> payload) async {
    if (!await _guardTrustedShortcutOrigin(id)) return;
    final args = payload['args'];
    final shortcutId =
        args is Map<String, dynamic> ? (args['id'] as String?)?.trim() : null;
    if (shortcutId == null || shortcutId.isEmpty) {
      await _resolveJsPromise(id: id, value: null, error: 'id is required');
      return;
    }
    await _providers.read(pinnedDappsProvider.notifier).unpin(shortcutId);
    // Drop the icon PNG too, otherwise it lingers in the App Group store
    // forever and a later re-pin of the same URL would show the stale image.
    await HomeShortcutsChannel.deleteWidgetIcon(shortcutId);
    await _syncPinnedToWidget();
    await _resolveJsPromise(
      id: id,
      value: <String, dynamic>{'removed': true},
      error: null,
    );
  }

  /// Reorders the pinned registry to the given id list and re-syncs the
  /// iOS widget. Unknown ids are ignored and missing ids are appended, so
  /// a stale caller can never drop entries (see PinnedDappsNotifier).
  Future<void> _handleReorderHomeScreenShortcuts(
      String id, Map<String, dynamic> payload) async {
    if (!await _guardTrustedShortcutOrigin(id)) return;
    final args = payload['args'];
    final rawIds = args is Map<String, dynamic> ? args['ids'] : null;
    if (rawIds is! List) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'ids must be a list of shortcut ids',
      );
      return;
    }
    final ids = [for (final v in rawIds) v.toString()];
    final updated =
        await _providers.read(pinnedDappsProvider.notifier).reorder(ids);
    await _syncPinnedToWidget();
    await _resolveJsPromise(
      id: id,
      value: <String, dynamic>{
        'order': [for (final d in updated) d.id],
      },
      error: null,
    );
  }

  /// One-time iOS walkthrough shown after a pin when the Usernode widget
  /// isn't on the homescreen yet.
  Future<void> _showWidgetInstructions(String dappName) async {
    if (!mounted) return;

    await Navigator.push<void>(
      context,
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (ctx, _, __) {
          final l10n = AppLocalizations.of(ctx);
          final theme = Theme.of(ctx);
          final spacing = theme.extension<AppSpacing>()!;
          final sizing = theme.extension<AppSizing>()!;

          Widget step(int number, String text) {
            return Padding(
              padding: EdgeInsets.only(bottom: spacing.space12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: spacing.space8),
                  Expanded(
                    child: Text(text, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Symbols.close),
              ),
              title: Text(l10n.widgetInstructionsTitle),
              titleSpacing: 0,
            ),
            body: Padding(
              padding: EdgeInsets.all(spacing.space24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Symbols.widgets,
                    size: sizing.iconDisplay,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(height: spacing.space16),
                  Text(
                    l10n.widgetInstructionsBody(dappName),
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.space24),
                  step(1, l10n.widgetInstructionsStep1),
                  step(2, l10n.widgetInstructionsStep2),
                  step(3, l10n.widgetInstructionsStep3),
                  const Spacer(),
                  Button(
                    label: l10n.widgetInstructionsDone,
                    variant: ButtonVariant.primary,
                    onTap: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
          );
        },
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            )),
            child: child,
          );
        },
      ),
    );
  }

  void _ensureConfirmPoller() {
    if (_confirmPoller != null) return;
    _confirmPoller = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollForConfirmations();
    });
  }

  Future<void> _pollForConfirmations() async {
    final pending = <String, DateTime>{};
    for (final id in _dappTxIds) {
      final rec = _txRecords[id];
      if (rec == null) continue;
      if (rec.status != _TxStatus.queued) continue;
      if (rec.id.startsWith('local_')) continue;
      if (rec.confirmedAt != null) continue;
      pending[rec.id] = rec.sentAt;
    }

    if (pending.isEmpty) {
      _confirmPoller?.cancel();
      _confirmPoller = null;
      return;
    }

    final address = _bridgeWalletIdentity()?.address;
    if (address == null || address.isEmpty) return;

    final dappUri = parseDappUrl(widget.url);
    final base = Uri(
      scheme: dappUri.scheme,
      host: dappUri.host,
      port: dappUri.port,
    );

    try {
      if (_cachedChainId == null) {
        final chainRes =
            await http.get(base.resolve('/explorer-api/active_chain'));
        if (chainRes.statusCode != 200) return;
        final chainData = jsonDecode(chainRes.body) as Map<String, dynamic>;
        _cachedChainId = chainData['chain_id'] as String?;
        if (_cachedChainId == null) return;
      }

      final earliest = pending.values.reduce(
        (a, b) => a.isBefore(b) ? a : b,
      );
      final fromTs = earliest.millisecondsSinceEpoch - 60000;

      final txUrl = base.resolve('/explorer-api/$_cachedChainId/transactions');
      final txRes = await http.post(
        txUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': address,
          'from_timestamp': fromTs,
          'limit': 50,
        }),
      );
      if (txRes.statusCode != 200) return;

      final txData = jsonDecode(txRes.body) as Map<String, dynamic>;
      final items = (txData['items'] as List<dynamic>?) ?? [];
      final now = DateTime.now();
      var found = false;

      for (final item in items) {
        final j = item as Map<String, dynamic>;
        final txId =
            (j['tx_id'] ?? j['id'] ?? j['txid'] ?? j['hash'] ?? '') as String;
        final status = j['status'] as String?;
        if (txId.isNotEmpty &&
            status == 'confirmed' &&
            pending.containsKey(txId)) {
          final rec = _txRecords[txId];
          if (rec != null && rec.confirmedAt == null) {
            _txRecords[txId] = rec.copyWith(
              confirmedAt: now,
              inclusionLatencyMs: (j['inclusion_latency_ms'] as num?)?.toInt(),
              blockHeight: (j['block_height'] as num?)?.toInt(),
              onChainTimestampMs: (j['timestamp_ms'] as num?)?.toInt(),
              onChainStatus: status,
            );
            found = true;
          }
        }
      }

      if (found) {
        _saveTxRecords();
        if (mounted) setState(() {});
      }
    } catch (_) {
      // Silently ignore — will retry on next tick.
    }
  }

  /// Pushes a full-screen opaque route for transaction confirmation.
  /// Returns `true` if confirmed, `false` if denied.
  Future<bool> _requestTransactionConfirmation({
    required String from,
    required String to,
    required BigInt amount,
    required String memo,
    String? confirmTitle,
    String? confirmSubtitle,
  }) async {
    if (!mounted) return false;

    return requestTransactionConfirmation(
      context,
      from: from,
      to: to,
      amount: amount,
      memo: memo,
      confirmTitle: confirmTitle,
      confirmSubtitle: confirmSubtitle,
    );
  }

  BigInt? _parseAmountToBigInt(Object? amountRaw) {
    if (amountRaw is num) return BigInt.from(amountRaw.round());
    if (amountRaw is String) {
      final trimmed = amountRaw.trim();
      if (trimmed.isEmpty) return null;
      final parsed = double.tryParse(trimmed);
      if (parsed == null) return null;
      return BigInt.from(parsed.round());
    }
    return null;
  }

  String? _parseMemoString(Object? memoRaw) {
    if (memoRaw is String) return memoRaw.trim();
    if (memoRaw == null) return '';
    return null;
  }

  Future<void> _openTxDebugPanel() async {
    final userAddress = _bridgeWalletIdentity()?.address;
    final dappUri = parseDappUrl(widget.url);
    final explorerOrigin = Uri(
      scheme: dappUri.scheme,
      host: dappUri.host,
      port: dappUri.port,
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => _TxDebugPanel(
          dappTxIds: _dappTxIds,
          txRecords: _txRecords,
          userAddress: userAddress,
          explorerOrigin: explorerOrigin,
          onRecordsUpdated: () {
            _saveTxRecords();
          },
        ),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            )),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tab root (embedded hub home) shows compact shared shell affordances; once
    // the user drills into a dapp (web history exists) the bar becomes white
    // pushed-detail chrome. Only the `appBar:` swaps — the WebViewWidget body
    // stays mounted, so flipping modes never reloads the page.
    //
    // The webview lives directly in the Scaffold body (NOT inside a
    // CustomScrollView/SliverFillRemaining): hosting the WebView's SurfaceView
    // platform view inside a scrollable starves it of buffers and ANRs the app
    // (BLASTBufferQueue "can't acquire next buffer"). That rules out the
    // sliver-based TopStatusAppBar here, so the root uses the preferred-size
    // compact variant instead.
    final isShellRoot = widget.embedded && !_canGoBack;
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      // Take over the route-pop handler so the device/system back button
      // walks the WebView's session history first (pushState entries
      // from the dapp's own client-side router count as history) and
      // only pops the Flutter route once we're at the WebView root.
      // Without this the Android back button would always exit the
      // dapp, regardless of how deep the user has navigated inside it.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: colors.surfaceContainerLowest,
        // Chromeless (full-screen SV shell): the page owns its own header,
        // so no Flutter bar at all — just keep the webview out from under
        // the OS status bar.
        appBar: widget.chromeless
            ? null
            : isShellRoot
                ? _buildShellAppBar(context)
                : _buildBrowserAppBar(context),
        body: ColoredBox(
          color: colors.surfaceContainerLowest,
          child: widget.chromeless
              ? SafeArea(
                  bottom: false,
                  child: WebViewWidget(controller: _controller),
                )
              : WebViewWidget(controller: _controller),
        ),
      ),
    );
  }

  /// Tab-root shell bar: the compact TopStatusAppBar shape used by app roots,
  /// exposed as a preferred-size widget so the WebView can stay out of slivers.
  PreferredSizeWidget _buildShellAppBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return TopStatusAppBar.scaffoldCompact(
      title: l10n.navDapps,
      nodeStatus: ref.watch(topStatusChromeNodeStatusProvider),
      // Profile and node detail screens moved into SV — this legacy
      // (non-chromeless) shell bar keeps the status glyph display-only.
      onProfilePressed: null,
      onNodePressed: null,
    );
  }

  IconButton _buildBrowserLeading(BuildContext context, AppSizing sizing) {
    if (widget.embedded) {
      return IconButton(
        tooltip: 'Back',
        onPressed: _handleBack,
        icon: Icon(Symbols.arrow_back_sharp, size: sizing.iconRegular),
      );
    }

    return IconButton(
      tooltip: 'Home',
      // Deep-linked entries (homescreen widget/shortcut) have nothing
      // underneath on the stack — popping the last route leaves a black
      // screen, so fall through to the dapps tab (this button lives on
      // dapp browser chrome; challenges would be a non-sequitur).
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.dapps);
        }
      },
      icon: Icon(Symbols.home_sharp, size: sizing.iconRegular),
    );
  }

  List<Widget> _buildBrowserActions(BuildContext context) {
    return [
      const NodeStatusIcon(),
      IconButton(
        tooltip: 'Transaction log',
        onPressed: _openTxDebugPanel,
        icon: const Icon(Symbols.receipt_long),
      ),
    ];
  }

  /// Drilled-in / non-embedded browser chrome: back, live page title (tap for
  /// the URL editor), loading bar, node indicator, and the transaction log.
  PreferredSizeWidget _buildBrowserAppBar(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final showLoading = _progress < 100;

    final bottomWidgets = <Widget>[
      if (showLoading)
        LinearProgressIndicator(
          minHeight: 2,
          value: _progress <= 0 ? null : _progress / 100,
        ),
      if (_showUrlEditor)
        Padding(
          padding: EdgeInsets.all(spacing.space12),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                // Walks WebView session history first (covers in-page
                // pushState navigation), falling through to the route
                // pop only at WebView root — identical to the system
                // back button's behavior.
                onPressed: _handleBack,
                icon: const Icon(Symbols.arrow_back_sharp),
              ),
              SizedBox(width: spacing.space8),
              Expanded(
                child: TextField(
                  controller: _urlController,
                  focusNode: _urlFocusNode,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _loadUrlFromInput(),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Enter URL (e.g. localhost:8000)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(width: spacing.space12),
              Button(
                label: 'Go',
                variant: ButtonVariant.primary,
                size: ButtonSize.small,
                onTap: _loadUrlFromInput,
              ),
              SizedBox(width: spacing.space8),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => _controller.reload(),
                icon: const Icon(Symbols.refresh_sharp),
              ),
            ],
          ),
        ),
    ];

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: colors.surfaceContainerLowest,
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      toolbarHeight: sizing.iconContainerXLarge,
      // Embedded nested view drills back through web history (mirrors the
      // Profile/Node pushed-page back button); non-embedded jumps to the
      // dapp list. The system back button still walks history via
      // PopScope.onPopInvokedWithResult above.
      leading: _buildBrowserLeading(context, sizing),
      title: GestureDetector(
        onTap: _toggleUrlEditor,
        behavior: HitTestBehavior.opaque,
        child: Text(
          _pageTitle?.isNotEmpty == true ? _pageTitle! : widget.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      titleSpacing: 0,
      actions: _buildBrowserActions(context),
      actionsPadding: EdgeInsetsDirectional.only(end: spacing.space16),
      bottom: bottomWidgets.isEmpty
          ? null
          : PreferredSize(
              preferredSize: Size.fromHeight(
                (showLoading ? 2 : 0) + (_showUrlEditor ? 62 : 0),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(color: colors.surfaceContainerLowest),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: bottomWidgets,
                ),
              ),
            ),
    );
  }

  // Single back-button entry point shared by the AppBar leading icon
  // and the PopScope's onPopInvokedWithResult. Walks the WebView's
  // session history first (covers in-page pushState navigation in
  // dapps like social-vibecoding: home → app → group-chat → back goes
  // to app, not out of the dapp) and only falls through to popping
  // the Flutter route once the WebView is at its root.
  Future<void> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }
}

// ---------------------------------------------------------------------------
// Transaction debug panel (opaque route — no WebView overlap)
// ---------------------------------------------------------------------------

class _TxDebugPanel extends StatefulWidget {
  final Set<String> dappTxIds;
  final Map<String, _TxRecord> txRecords;
  final String? userAddress;
  final Uri explorerOrigin;
  final VoidCallback onRecordsUpdated;

  const _TxDebugPanel({
    required this.dappTxIds,
    required this.txRecords,
    required this.userAddress,
    required this.explorerOrigin,
    required this.onRecordsUpdated,
  });

  @override
  State<_TxDebugPanel> createState() => _TxDebugPanelState();
}

class _TxDebugPanelState extends State<_TxDebugPanel> {
  bool _loading = false;
  String? _fetchError;
  int? _expandedIndex;
  late final Timer _ageTicker;

  @override
  void initState() {
    super.initState();
    _ageTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _fetchExplorerData();
  }

  @override
  void dispose() {
    _ageTicker.cancel();
    super.dispose();
  }

  List<_TxRecord> _sortedRecords() {
    final records = <_TxRecord>[];
    for (final id in widget.dappTxIds) {
      final rec = widget.txRecords[id];
      if (rec != null) records.add(rec);
    }
    records.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return records;
  }

  Future<void> _refresh() async {
    setState(() {
      _fetchError = null;
      _loading = true;
    });
    await _fetchExplorerData();
  }

  Future<void> _fetchExplorerData() async {
    final address = widget.userAddress;
    if (address == null || address.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final pending = <String, DateTime>{};
    for (final id in widget.dappTxIds) {
      final rec = widget.txRecords[id];
      if (rec == null) continue;
      if (rec.status != _TxStatus.queued) continue;
      if (rec.id.startsWith('local_')) continue;
      if (rec.confirmedAt != null) continue;
      pending[rec.id] = rec.sentAt;
    }

    if (pending.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    try {
      final base = widget.explorerOrigin;
      final chainRes =
          await http.get(base.resolve('/explorer-api/active_chain'));
      if (chainRes.statusCode != 200) {
        throw Exception('Chain discovery failed (${chainRes.statusCode})');
      }
      final chainData = jsonDecode(chainRes.body) as Map<String, dynamic>;
      final chainId = chainData['chain_id'] as String?;
      if (chainId == null) throw Exception('No chain_id in response');

      final earliest = pending.values.reduce(
        (a, b) => a.isBefore(b) ? a : b,
      );
      final fromTs = earliest.millisecondsSinceEpoch - 60000;

      final txUrl = base.resolve('/explorer-api/$chainId/transactions');
      final txRes = await http.post(
        txUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': address,
          'from_timestamp': fromTs,
          'limit': 50,
        }),
      );
      if (txRes.statusCode != 200) {
        throw Exception('Transaction fetch failed (${txRes.statusCode})');
      }

      final txData = jsonDecode(txRes.body) as Map<String, dynamic>;
      final items = (txData['items'] as List<dynamic>?) ?? [];
      var found = false;
      final now = DateTime.now();

      for (final item in items) {
        final j = item as Map<String, dynamic>;
        final txId =
            (j['tx_id'] ?? j['id'] ?? j['txid'] ?? j['hash'] ?? '') as String;
        final status = j['status'] as String?;
        if (txId.isNotEmpty &&
            status == 'confirmed' &&
            pending.containsKey(txId)) {
          final rec = widget.txRecords[txId];
          if (rec != null && rec.confirmedAt == null) {
            widget.txRecords[txId] = rec.copyWith(
              confirmedAt: now,
              inclusionLatencyMs: (j['inclusion_latency_ms'] as num?)?.toInt(),
              blockHeight: (j['block_height'] as num?)?.toInt(),
              onChainTimestampMs: (j['timestamp_ms'] as num?)?.toInt(),
              onChainStatus: status,
            );
            found = true;
          }
        }
      }

      if (found) widget.onRecordsUpdated();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _fetchError = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final radii = theme.extension<AppRadii>()!;
    final muted = theme.colorScheme.onSurfaceVariant;
    final records = _sortedRecords();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Symbols.arrow_back_sharp),
        ),
        title: const Text('Transaction Log'),
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading)
              Padding(
                padding: EdgeInsets.all(spacing.space16),
                child: const LinearProgressIndicator(minHeight: 2),
              ),
            if (_fetchError != null)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.space16,
                  vertical: spacing.space8,
                ),
                child: Text(
                  'Explorer fetch failed: $_fetchError',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: records.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: spacing.space16 * 6),
                          Center(
                            child: Text(
                              'No transactions yet',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: muted),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(spacing.space16),
                        itemCount: records.length,
                        itemBuilder: (ctx, index) {
                          final rec = records[index];
                          final isExpanded = _expandedIndex == index;
                          final isConfirmed = rec.status == _TxStatus.queued &&
                              rec.onChainStatus == 'confirmed';

                          final (Color badgeColor, String badgeLabel) =
                              switch (rec.status) {
                            _TxStatus.denied => (
                                theme.colorScheme.error,
                                'Denied'
                              ),
                            _TxStatus.error => (
                                theme.colorScheme.error,
                                'Error'
                              ),
                            _TxStatus.queued
                                when rec.onChainStatus == 'confirmed' =>
                              (const Color(0xFF4CAF50), 'Confirmed'),
                            _TxStatus.queued
                                when rec.onChainStatus == 'orphaned' =>
                              (theme.colorScheme.error, 'Orphaned'),
                            _TxStatus.queued => (
                                const Color(0xFFFFA726),
                                'Pending'
                              ),
                          };

                          String memoType = '';
                          try {
                            final parsed =
                                jsonDecode(rec.memo) as Map<String, dynamic>;
                            memoType = parsed['type'] as String? ?? '';
                          } catch (_) {}

                          final age = DateTime.now().difference(rec.sentAt);
                          final ageStr = age.inMinutes < 1
                              ? 'sent ${age.inSeconds}s ago'
                              : age.inHours < 1
                                  ? 'sent ${age.inMinutes}m ago'
                                  : age.inDays < 1
                                      ? 'sent ${age.inHours}h ago'
                                      : 'sent ${age.inDays}d ago';

                          // Header pill: fastest "total" signal we have for
                          // a confirmed tx (best of explorer/dapp, then
                          // explorer-only inclusion latency as a final
                          // fallback for the explorer-comes-first case
                          // before its `confirmedAt` lands).
                          String? confirmTimeStr;
                          int? confirmTotalSecs;
                          if (isConfirmed) {
                            final totalMs =
                                rec.bestTotalMs ?? rec.inclusionLatencyMs;
                            if (totalMs != null && totalMs >= 0) {
                              final secs = totalMs ~/ 1000;
                              confirmTotalSecs = secs;
                              confirmTimeStr = secs < 60
                                  ? '${secs}s'
                                  : '${secs ~/ 60}m ${secs % 60}s';
                            }
                          }

                          final txHash =
                              rec.id.startsWith('local_') ? null : rec.id;

                          return Padding(
                            padding: EdgeInsets.only(bottom: spacing.space8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _expandedIndex = isExpanded ? null : index;
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.all(spacing.space12),
                                decoration: BoxDecoration(
                                  color: theme
                                      .colorScheme.surfaceContainerHighest
                                      .withAlpha(100),
                                  borderRadius: radii.borderRadiusMedium,
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant
                                        .withAlpha(80),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withAlpha(30),
                                            borderRadius:
                                                radii.borderRadiusXSmall,
                                          ),
                                          child: Text(
                                            badgeLabel,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: badgeColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        if (confirmTimeStr != null)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(right: 6),
                                            child: Text(
                                              '\u{23F1} $confirmTimeStr',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                color: _latencyColor(
                                                    confirmTotalSecs ?? 0),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          ageStr,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(color: muted),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: spacing.space8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'To: ${_truncate(rec.to, 20)}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              fontFamily: kMonoFontFamily,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Amt: ${rec.amount}',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                    if (memoType.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(
                                            top: spacing.space4),
                                        child: Text(
                                          'type: $memoType',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(color: muted),
                                        ),
                                      ),
                                    if (txHash != null && txHash.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(
                                            top: spacing.space4),
                                        child: Text(
                                          'tx: ${_truncate(txHash, 24)}',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            fontFamily: kMonoFontFamily,
                                            color: muted,
                                          ),
                                        ),
                                      ),
                                    if (rec.status == _TxStatus.error &&
                                        rec.errorMessage != null)
                                      Padding(
                                        padding: EdgeInsets.only(
                                            top: spacing.space4),
                                        child: Text(
                                          rec.errorMessage!,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: theme.colorScheme.error,
                                          ),
                                        ),
                                      ),
                                    if (isExpanded) ...[
                                      const Divider(height: 16),
                                      if ((isConfirmed &&
                                              rec.inclusionLatencyMs != null) ||
                                          rec.dappObservedAtMs != null)
                                        _buildLatencyRow(
                                          theme: theme,
                                          muted: muted,
                                          rec: rec,
                                        ),
                                      _detailRow(theme, muted, 'From', rec.from,
                                          mono: true),
                                      _detailRow(theme, muted, 'To', rec.to,
                                          mono: true),
                                      _detailRow(theme, muted, 'Amount',
                                          rec.amount.toString()),
                                      if (txHash != null && txHash.isNotEmpty)
                                        _detailRow(
                                            theme, muted, 'Tx Hash', txHash,
                                            mono: true),
                                      if (rec.blockHeight != null)
                                        _detailRow(theme, muted, 'Block',
                                            rec.blockHeight.toString()),
                                      _detailRow(theme, muted, 'Memo',
                                          _formatMemo(rec.memo)),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatencyRow({
    required ThemeData theme,
    required Color muted,
    required _TxRecord rec,
  }) {
    // Per-channel totals + last-mile come from the helpers on _TxRecord —
    // see the doc-comment there. "Total" is the best-of, so the user sees
    // the fastest path; the per-channel last-mile columns stay split so
    // it's clear which path delivered first.
    final bestTotalMs = rec.bestTotalMs;
    final explorerLastMileMs = rec.explorerLastMileMs;
    final dappLastMileMs = rec.dappLastMileMs;
    final inclusionMs = rec.inclusionLatencyMs;

    String fmt(int? ms) {
      if (ms == null) return '--';
      final s = ms ~/ 1000;
      return s < 60 ? '${s}s' : '${s ~/ 60}m ${s % 60}s';
    }

    Color? totalColor;
    if (bestTotalMs != null) {
      totalColor = _latencyColor(bestTotalMs ~/ 1000);
    }

    Widget col(String label, String value, {Color? color}) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.labelSmall?.copyWith(color: muted)),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: color != null ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          col(
            'Total',
            bestTotalMs != null ? '\u{23F1} ${fmt(bestTotalMs)}' : '--',
            color: totalColor,
          ),
          col('Inclusion', fmt(inclusionMs)),
          col('Last mile (explorer)', fmt(explorerLastMileMs)),
          col('Last mile (dapp)', fmt(dappLastMileMs)),
        ],
      ),
    );
  }

  static Widget _detailRow(
    ThemeData theme,
    Color muted,
    String label,
    String value, {
    bool mono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(color: muted)),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: mono ? kMonoFontFamily : null,
            ),
          ),
        ],
      ),
    );
  }

  static Color _latencyColor(int totalSecs) {
    if (totalSecs < 20) return const Color(0xFF4CAF50);
    if (totalSecs <= 40) return const Color(0xFFFFA726);
    return const Color(0xFFF44336);
  }

  static String _truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    final half = (maxLen - 1) ~/ 2;
    return '${s.substring(0, half)}\u{2026}${s.substring(s.length - half)}';
  }

  static String _formatMemo(String memo) {
    try {
      final parsed = jsonDecode(memo);
      return const JsonEncoder.withIndent('  ').convert(parsed);
    } catch (_) {
      return memo;
    }
  }
}
