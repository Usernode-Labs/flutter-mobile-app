import 'dart:async';
import 'dart:convert';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/widgets/node_status_icon.dart';
import 'package:crypto_mobile_app/core/widgets/tx_confirmation_page.dart';
import 'package:crypto_mobile_app/design_system/src/button.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_typography.dart';
import 'package:crypto_mobile_app/features/dapps/providers/dapps_provider.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/account.dart' as frb_account;
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

  const DappWebViewScreen({
    super.key,
    required this.url,
    required this.name,
  });

  @override
  ConsumerState<DappWebViewScreen> createState() => _DappWebViewScreenState();
}

class _DappWebViewScreenState extends ConsumerState<DappWebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;

  static const _jsChannelName = 'Usernode';

  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  final List<DateTime> _secretTaps = <DateTime>[];
  Timer? _secretTapResetTimer;
  bool _showUrlEditor = false;
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
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Pipe WebView console.* output (including the iframe-relay tracing in
      // usernode-bridge.js) into Flutter's debug logs so it shows up in
      // `flutter run` — no Safari/remote inspector required.
      ..setOnConsoleMessage((msg) {
        debugPrint('[webview ${msg.level.name}] ${msg.message}');
      })
      ..addJavaScriptChannel(
        _jsChannelName,
        onMessageReceived: (message) async {
          try {
            final payload = jsonDecode(message.message) as Map<String, dynamic>;
            final method = payload['method'] as String?;
            final id = payload['id'] as String?;
            debugPrint('[Usernode JS-channel] method=$method id=$id');
            if (method == null || id == null) return;

            if (method == 'getNodeAddress') {
              final address = await _getActiveNodeAddress();
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
            setState(() => _progress = 0);
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
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() => _progress = 100);
          },
        ),
      )
      ..loadRequest(parseDappUrl(widget.url));
    _loadTxRecords();
    _loadDappTxIds();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.setBackgroundColor(Theme.of(context).colorScheme.surface);
  }

  @override
  void dispose() {
    _confirmPoller?.cancel();
    _secretTapResetTimer?.cancel();
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  void _onSecretTap() {
    final now = DateTime.now();
    _secretTaps.add(now);
    if (_secretTaps.length > 3) {
      _secretTaps.removeAt(0);
    }

    _secretTapResetTimer?.cancel();
    _secretTapResetTimer = Timer(const Duration(milliseconds: 900), () {
      _secretTaps.clear();
    });

    if (_secretTaps.length == 3) {
      final first = _secretTaps.first;
      final last = _secretTaps.last;
      final delta = last.difference(first);
      if (delta <= const Duration(milliseconds: 800)) {
        setState(() {
          _showUrlEditor = !_showUrlEditor;
        });

        if (_showUrlEditor) {
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
      }
      _secretTaps.clear();
    }
  }

  Future<void> _loadUrlFromInput() async {
    final trimmed = _urlController.text.trim();
    if (trimmed.isEmpty) return;
    final uri = parseDappUrl(trimmed);
    await _controller.loadRequest(uri);
  }

  Future<String?> _getActiveNodeAddress() async {
    final repo = await ref.read(accountsProvider.future);
    final active = await repo.getActive();
    return active?.address;
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

    final fromAddress = await _getActiveNodeAddress();
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

    final resp = await rpc.wallet().txSend(
          fromPkHash: fromPkHash,
          amount: amount,
          toPkHash: toPkHash,
          memo: memo,
        );

    final rpcError = resp?.error;
    final isQueued = rpcError == null || rpcError.isEmpty;
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
        'queued': resp?.queued ?? false,
        'error': rpcError,
      },
      error: null,
    );
  }

  Future<void> _handleSignMessage(
      String id, Map<String, dynamic> payload) async {
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

    final repo = await ref.read(accountsProvider.future);
    final active = await repo.getActive();
    if (active == null) {
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

    final secretKey = await repo.getSecretKey(active.id);
    if (secretKey == null || secretKey.isEmpty) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Secret key unavailable',
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
                    size: 48,
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

    final address = await _getActiveNodeAddress();
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
    final userAddress = await _getActiveNodeAddress();
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
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final showLoading = _progress < 100;
    final theme = Theme.of(context);

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
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Home',
            // Tap = jump straight back to the dapp list, regardless of how
            // deep the user has navigated inside the WebView. The Android
            // system back button (PopScope.onPopInvokedWithResult above)
            // still walks WebView history step-by-step via _handleBack.
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Symbols.home_sharp),
          ),
          title: GestureDetector(
            onTap: _onSecretTap,
            behavior: HitTestBehavior.opaque,
            child: Text(widget.name),
          ),
          titleSpacing: 0,
          actions: [
            const NodeStatusIcon(),
            IconButton(
              tooltip: 'Transaction log',
              onPressed: _openTxDebugPanel,
              icon: const Icon(Symbols.receipt_long),
            ),
          ],
          bottom: bottomWidgets.isEmpty
              ? null
              : PreferredSize(
                  preferredSize: Size.fromHeight(
                    (showLoading ? 2 : 0) + (_showUrlEditor ? 62 : 0),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: theme.colorScheme.surface),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: bottomWidgets,
                    ),
                  ),
                ),
        ),
        body: WebViewWidget(controller: _controller),
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
