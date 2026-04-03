import 'dart:async';
import 'dart:convert';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/design_system/src/button.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_typography.dart';
import 'package:crypto_mobile_app/features/dapps/providers/dapps_provider.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum _TxStatus { denied, error, queued }

class _TxLogEntry {
  final DateTime timestamp;
  final String from;
  final String to;
  final BigInt amount;
  final String memo;
  final _TxStatus status;
  final String? errorMessage;
  final String? txHash;

  const _TxLogEntry({
    required this.timestamp,
    required this.from,
    required this.to,
    required this.amount,
    required this.memo,
    required this.status,
    this.errorMessage,
    this.txHash,
  });
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
  final List<_TxLogEntry> _txLog = [];
  List<_OnChainTx> _onChainTxCache = [];
  final Map<String, DateTime> _txConfirmedAt = {};
  Timer? _confirmPoller;
  String? _cachedChainId;

  String get _confirmedAtPrefsKey => 'dapp_tx_confirmed_at:${widget.url}';

  Future<void> _loadConfirmedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_confirmedAtPrefsKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in map.entries) {
        _txConfirmedAt[e.key] =
            DateTime.fromMillisecondsSinceEpoch(e.value as int);
      }
    } catch (_) {}
  }

  Future<void> _saveConfirmedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, int>{};
    for (final e in _txConfirmedAt.entries) {
      map[e.key] = e.value.millisecondsSinceEpoch;
    }
    await prefs.setString(_confirmedAtPrefsKey, jsonEncode(map));
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
      ..addJavaScriptChannel(
        _jsChannelName,
        onMessageReceived: (message) async {
          try {
            final payload = jsonDecode(message.message) as Map<String, dynamic>;
            final method = payload['method'] as String?;
            final id = payload['id'] as String?;
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
          } catch (_) {
            // Ignore malformed messages.
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
    _loadConfirmedAt();
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
      _txLog.insert(
        0,
        _TxLogEntry(
          timestamp: DateTime.now(),
          from: fromAddress,
          to: destinationPubkey,
          amount: amount,
          memo: memoString,
          status: _TxStatus.denied,
        ),
      );
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'User denied the transaction',
      );
      return;
    }

    if (AppConfig.viewOnly) {
      const errorMessage = 'Transactions are disabled in view-only mode.';
      _txLog.insert(
        0,
        _TxLogEntry(
          timestamp: DateTime.now(),
          from: fromAddress,
          to: destinationPubkey,
          amount: amount,
          memo: memoString,
          status: _TxStatus.error,
          errorMessage: errorMessage,
        ),
      );
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
    _txLog.insert(
      0,
      _TxLogEntry(
        timestamp: DateTime.now(),
        from: fromAddress,
        to: destinationPubkey,
        amount: amount,
        memo: memoString,
        status: isQueued ? _TxStatus.queued : _TxStatus.error,
        errorMessage: rpcError,
        txHash: resp?.txId,
      ),
    );

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

  void _ensureConfirmPoller() {
    if (_confirmPoller != null) return;
    _confirmPoller = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollForConfirmations();
    });
  }

  Future<void> _pollForConfirmations() async {
    final pending = <String, DateTime>{};
    for (final entry in _txLog) {
      if (entry.status != _TxStatus.queued) continue;
      if (entry.txHash == null) continue;
      if (_txConfirmedAt.containsKey(entry.txHash)) continue;
      pending[entry.txHash!] = entry.timestamp;
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
            pending.containsKey(txId) &&
            !_txConfirmedAt.containsKey(txId)) {
          _txConfirmedAt[txId] = now;
          final oc = _OnChainTx.fromJson(j);
          _onChainTxCache =
              _onChainTxCache.where((c) => c.txId != txId).toList()..add(oc);
          found = true;
        }
      }

      if (found) {
        _saveConfirmedAt();
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

    final confirmed = await Navigator.push<bool>(
      context,
      PageRouteBuilder<bool>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => _TxConfirmationPage(
          from: from,
          to: to,
          amount: amount,
          memo: memo,
          confirmTitle: confirmTitle,
          confirmSubtitle: confirmSubtitle,
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

    return confirmed ?? false;
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
          txLog: _txLog,
          userAddress: userAddress,
          explorerOrigin: explorerOrigin,
          initialOnChainTxs: _onChainTxCache,
          onOnChainTxsUpdated: (txs) => _onChainTxCache = txs,
          confirmedAt: _txConfirmedAt,
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Symbols.arrow_back_sharp),
        ),
        title: GestureDetector(
          onTap: _onSecretTap,
          behavior: HitTestBehavior.opaque,
          child: Text(widget.name),
        ),
        titleSpacing: 0,
        actions: [
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
    );
  }
}

// ---------------------------------------------------------------------------
// Full-screen confirmation page (opaque route — no WebView overlap)
// ---------------------------------------------------------------------------

/// Pushed as a full opaque [MaterialPageRoute] so no Flutter widget ever
/// overlaps the WKWebView platform view, avoiding the gesture recognizer bug.
class _TxConfirmationPage extends StatefulWidget {
  const _TxConfirmationPage({
    required this.from,
    required this.to,
    required this.amount,
    required this.memo,
    this.confirmTitle,
    this.confirmSubtitle,
  });

  final String from;
  final String to;
  final BigInt amount;
  final String memo;
  final String? confirmTitle;
  final String? confirmSubtitle;

  @override
  State<_TxConfirmationPage> createState() => _TxConfirmationPageState();
}

class _TxConfirmationPageState extends State<_TxConfirmationPage> {
  bool _detailsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final radii = theme.extension<AppRadii>()!;
    final muted = theme.colorScheme.onSurfaceVariant;

    String formattedMemo = widget.memo;
    if (widget.memo.isNotEmpty) {
      try {
        final parsed = jsonDecode(widget.memo);
        const encoder = JsonEncoder.withIndent('  ');
        formattedMemo = encoder.convert(parsed);
      } catch (_) {
        // Not valid JSON — show raw string.
      }
    }

    Widget detailRow(String label, String value, {bool mono = false}) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.space8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
            SizedBox(height: spacing.space4),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ],
        ),
      );
    }

    final detailsContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        detailRow('From', widget.from, mono: true),
        const Divider(height: 1),
        detailRow('To', widget.to, mono: true),
        const Divider(height: 1),
        detailRow('Fee', '0'),
        if (formattedMemo.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.only(top: spacing.space8),
            child: Text(
              'Memo',
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ),
          SizedBox(height: spacing.space4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    formattedMemo,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: kMonoFontFamily,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Symbols.arrow_back_sharp),
        ),
        title: Text(widget.confirmTitle ?? 'Confirm Transaction'),
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.confirmSubtitle ??
                    'A dapp is requesting to send a transaction.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              SizedBox(height: spacing.space24),
              Text(
                'Amount',
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
              SizedBox(height: spacing.space4),
              Text(
                widget.amount.toString(),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: kMonoFontFamily,
                ),
              ),
              SizedBox(height: spacing.space16),
              Expanded(
                child: SingleChildScrollView(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withAlpha(100),
                      borderRadius: radii.borderRadiusMedium,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withAlpha(80),
                      ),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          borderRadius: _detailsExpanded
                              ? BorderRadius.vertical(
                                  top: radii.borderRadiusMedium.topLeft,
                                )
                              : radii.borderRadiusMedium,
                          onTap: () => setState(
                            () => _detailsExpanded = !_detailsExpanded,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: spacing.space16,
                              vertical: spacing.space12,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Details',
                                  style: theme.textTheme.titleSmall,
                                ),
                                const Spacer(),
                                AnimatedRotation(
                                  turns: _detailsExpanded ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    Symbols.expand_more,
                                    size: 20,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: EdgeInsets.fromLTRB(
                              spacing.space16,
                              0,
                              spacing.space16,
                              spacing.space16,
                            ),
                            child: detailsContent,
                          ),
                          crossFadeState: _detailsExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 200),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: spacing.space24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: spacing.space12,
                        ),
                      ),
                      child: const Text('Deny'),
                    ),
                  ),
                  SizedBox(width: spacing.space12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: spacing.space12,
                        ),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Transaction debug panel (opaque route — no WebView overlap)
// ---------------------------------------------------------------------------

class _OnChainTx {
  final String txId;
  final String? source;
  final String? destination;
  final String? memo;
  final String? status;
  final int? amount;
  final int? blockHeight;
  final int? timestampMs;
  final int? inclusionLatencyMs;

  const _OnChainTx({
    required this.txId,
    this.source,
    this.destination,
    this.memo,
    this.status,
    this.amount,
    this.blockHeight,
    this.timestampMs,
    this.inclusionLatencyMs,
  });

  factory _OnChainTx.fromJson(Map<String, dynamic> j) {
    return _OnChainTx(
      txId: (j['tx_id'] ?? j['id'] ?? j['txid'] ?? j['hash'] ?? '') as String,
      source: j['source'] as String? ?? j['from_pubkey'] as String?,
      destination:
          j['destination'] as String? ?? j['destination_pubkey'] as String?,
      memo: j['memo'] as String?,
      status: j['status'] as String?,
      amount: (j['amount'] as num?)?.toInt(),
      blockHeight: (j['block_height'] as num?)?.toInt(),
      timestampMs: (j['timestamp_ms'] as num?)?.toInt(),
      inclusionLatencyMs: (j['inclusion_latency_ms'] as num?)?.toInt(),
    );
  }
}

class _MergedEntry {
  final _TxLogEntry local;
  final _OnChainTx? onChain;
  final bool isHistorical;

  const _MergedEntry({
    required this.local,
    this.onChain,
    this.isHistorical = false,
  });
}

class _TxDebugPanel extends StatefulWidget {
  final List<_TxLogEntry> txLog;
  final String? userAddress;
  final Uri explorerOrigin;
  final List<_OnChainTx> initialOnChainTxs;
  final ValueChanged<List<_OnChainTx>> onOnChainTxsUpdated;
  final Map<String, DateTime> confirmedAt;

  const _TxDebugPanel({
    required this.txLog,
    required this.userAddress,
    required this.explorerOrigin,
    required this.initialOnChainTxs,
    required this.onOnChainTxsUpdated,
    required this.confirmedAt,
  });

  @override
  State<_TxDebugPanel> createState() => _TxDebugPanelState();
}

class _TxDebugPanelState extends State<_TxDebugPanel> {
  late List<_OnChainTx> _onChainTxs;
  late bool _loading;
  String? _fetchError;
  int? _expandedIndex;
  late final Timer _ageTicker;

  @override
  void initState() {
    super.initState();
    _onChainTxs = List.of(widget.initialOnChainTxs);
    _loading = _onChainTxs.isEmpty;
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

  Future<void> _fetchExplorerData() async {
    final address = widget.userAddress;
    if (address == null || address.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // Build a set of on-chain tx IDs for quick lookup.
    final onChainIds = <String>{};
    for (final oc in _onChainTxs) {
      onChainIds.add(oc.txId);
    }

    // Entries with a txHash are resolved by exact ID match.  Entries without
    // a hash fall back to count-based (destination, memo) matching.
    final queuedCounts = <(String, String), int>{};
    final onChainCounts = <(String, String), int>{};
    for (final local in widget.txLog) {
      if (local.status != _TxStatus.queued) continue;
      if (local.txHash != null) continue; // resolved by exact match below
      final key = (local.to, local.memo);
      queuedCounts[key] = (queuedCounts[key] ?? 0) + 1;
    }
    for (final oc in _onChainTxs) {
      if (oc.destination == null || oc.memo == null) continue;
      final key = (oc.destination!, oc.memo!);
      if (queuedCounts.containsKey(key)) {
        onChainCounts[key] = (onChainCounts[key] ?? 0) + 1;
      }
    }

    int? fromTimestamp;
    int unresolvedCount = 0;
    for (final local in widget.txLog) {
      if (local.status != _TxStatus.queued) continue;
      // Exact-hash entries: resolved if the hash appears in on-chain set.
      if (local.txHash != null) {
        if (onChainIds.contains(local.txHash)) continue;
        unresolvedCount++;
        final ms = local.timestamp.millisecondsSinceEpoch - 60000;
        if (fromTimestamp == null || ms < fromTimestamp) fromTimestamp = ms;
        continue;
      }
      // Count-based entries: resolved if on-chain count covers queued count.
      final key = (local.to, local.memo);
      final needed = queuedCounts[key] ?? 0;
      final have = onChainCounts[key] ?? 0;
      if (have >= needed) continue;
      unresolvedCount++;
      final ms = local.timestamp.millisecondsSinceEpoch - 60000;
      if (fromTimestamp == null || ms < fromTimestamp) fromTimestamp = ms;
    }

    if (fromTimestamp == null && _onChainTxs.isNotEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final hadUnresolved = unresolvedCount > 0;

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

      final txUrl = base.resolve('/explorer-api/$chainId/transactions');
      final headers = {'Content-Type': 'application/json'};

      final merged = <String, _OnChainTx>{};
      for (final tx in _onChainTxs) {
        merged[tx.txId] = tx;
      }

      String? cursor;
      const maxPages = 20;

      for (var page = 0; page < maxPages; page++) {
        final query = <String, dynamic>{'sender': address, 'limit': 200};
        if (fromTimestamp != null && merged.isNotEmpty) {
          query['from_timestamp'] = fromTimestamp;
        }
        if (cursor != null) query['cursor'] = cursor;

        final txRes = await http.post(
          txUrl,
          headers: headers,
          body: jsonEncode(query),
        );
        if (txRes.statusCode != 200) {
          throw Exception('Transaction fetch failed (${txRes.statusCode})');
        }
        final txData = jsonDecode(txRes.body) as Map<String, dynamic>;
        final items = (txData['items'] as List<dynamic>?) ?? [];

        for (final item in items) {
          final tx = _OnChainTx.fromJson(item as Map<String, dynamic>);
          if (!merged.containsKey(tx.txId)) {
            onChainIds.add(tx.txId);
            if (tx.destination != null && tx.memo != null) {
              final key = (tx.destination!, tx.memo!);
              onChainCounts[key] = (onChainCounts[key] ?? 0) + 1;
            }
          }
          merged[tx.txId] = tx;
        }

        // Recount unresolved: check both exact-hash and count-based entries.
        if (hadUnresolved) {
          var stillUnresolved = false;
          for (final local in widget.txLog) {
            if (local.status != _TxStatus.queued) continue;
            if (local.txHash != null) {
              if (!onChainIds.contains(local.txHash)) {
                stillUnresolved = true;
                break;
              }
            } else {
              final key = (local.to, local.memo);
              final needed = queuedCounts[key] ?? 0;
              if (needed > 0 && (onChainCounts[key] ?? 0) < needed) {
                stillUnresolved = true;
                break;
              }
            }
          }
          if (!stillUnresolved) break;
        }

        final hasMore = txData['has_more'] as bool? ?? false;
        final nextCursor = txData['next_cursor'] as String?;
        if (!hasMore || nextCursor == null) break;
        cursor = nextCursor;
      }

      if (mounted) {
        final mergedList = merged.values.toList();
        setState(() {
          _onChainTxs = mergedList;
          _loading = false;
        });
        widget.onOnChainTxsUpdated(mergedList);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fetchError = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<_MergedEntry> _buildMergedList() {
    final matched = <String>{};
    final results = <_MergedEntry>[];

    final queuedIndices = <int>[];
    for (var i = 0; i < widget.txLog.length; i++) {
      if (widget.txLog[i].status == _TxStatus.queued) queuedIndices.add(i);
    }
    queuedIndices.sort((a, b) =>
        widget.txLog[a].timestamp.compareTo(widget.txLog[b].timestamp));

    // Build an index of on-chain txs by txId for O(1) exact matching.
    final onChainById = <String, _OnChainTx>{};
    for (final oc in _onChainTxs) {
      onChainById[oc.txId] = oc;
    }

    final matchByIndex = <int, _OnChainTx>{};
    for (final i in queuedIndices) {
      final local = widget.txLog[i];

      // Primary: exact match by tx hash (available for txs sent in this session).
      if (local.txHash != null) {
        final oc = onChainById[local.txHash];
        if (oc != null && !matched.contains(oc.txId)) {
          matched.add(oc.txId);
          matchByIndex[i] = oc;
          continue;
        }
      }

      // Fallback: closest-timestamp heuristic for entries without a hash
      // (e.g. historical entries synthesized from on-chain data).
      _OnChainTx? bestMatch;
      int bestDelta = 0x7FFFFFFFFFFFFFFF;
      final localMs = local.timestamp.millisecondsSinceEpoch;

      for (final oc in _onChainTxs) {
        if (matched.contains(oc.txId)) continue;
        if (oc.destination != local.to || oc.memo != local.memo) continue;
        final delta = (oc.timestampMs != null)
            ? (oc.timestampMs! - localMs).abs()
            : 0x7FFFFFFFFFFFFFFF;
        if (delta < bestDelta) {
          bestDelta = delta;
          bestMatch = oc;
        }
      }

      if (bestMatch != null) {
        matched.add(bestMatch.txId);
        matchByIndex[i] = bestMatch;
      }
    }

    for (var i = 0; i < widget.txLog.length; i++) {
      final local = widget.txLog[i];
      if (local.status != _TxStatus.queued) {
        results.add(_MergedEntry(local: local));
      } else {
        results.add(_MergedEntry(local: local, onChain: matchByIndex[i]));
      }
    }

    // Append historical on-chain txs not matched to any local entry.
    for (final oc in _onChainTxs) {
      if (matched.contains(oc.txId)) continue;
      if (oc.source == null) continue;
      final ts = oc.timestampMs != null
          ? DateTime.fromMillisecondsSinceEpoch(oc.timestampMs!)
          : DateTime.now();
      results.add(_MergedEntry(
        local: _TxLogEntry(
          timestamp: ts,
          from: oc.source!,
          to: oc.destination ?? '',
          amount: BigInt.from(oc.amount ?? 0),
          memo: oc.memo ?? '',
          status: _TxStatus.queued,
        ),
        onChain: oc,
        isHistorical: true,
      ));
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final radii = theme.extension<AppRadii>()!;
    final muted = theme.colorScheme.onSurfaceVariant;
    final merged = _buildMergedList();

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
              const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(minHeight: 2),
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
              child: merged.isEmpty
                  ? Center(
                      child: Text(
                        'No transactions yet',
                        style:
                            theme.textTheme.bodyMedium?.copyWith(color: muted),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(spacing.space16),
                      itemCount: merged.length,
                      itemBuilder: (ctx, index) {
                        final entry = merged[index];
                        final local = entry.local;
                        final oc = entry.onChain;
                        final isExpanded = _expandedIndex == index;

                        final (Color badgeColor, String badgeLabel) =
                            switch (local.status) {
                          _TxStatus.denied => (
                              theme.colorScheme.error,
                              'Denied'
                            ),
                          _TxStatus.error => (theme.colorScheme.error, 'Error'),
                          _TxStatus.queued when oc?.status == 'confirmed' => (
                              const Color(0xFF4CAF50),
                              'Confirmed'
                            ),
                          _TxStatus.queued when oc?.status == 'orphaned' => (
                              theme.colorScheme.error,
                              'Orphaned'
                            ),
                          _TxStatus.queued => (
                              const Color(0xFFFFA726),
                              'Pending'
                            ),
                        };

                        String memoType = '';
                        try {
                          final parsed =
                              jsonDecode(local.memo) as Map<String, dynamic>;
                          memoType = parsed['type'] as String? ?? '';
                        } catch (_) {}

                        final age = DateTime.now().difference(local.timestamp);
                        final String ageStr;
                        if (entry.isHistorical) {
                          ageStr = age.inMinutes < 1
                              ? '${age.inSeconds}s ago'
                              : age.inHours < 1
                                  ? '${age.inMinutes}m ago'
                                  : age.inDays < 1
                                      ? '${age.inHours}h ago'
                                      : '${age.inDays}d ago';
                        } else {
                          ageStr = age.inMinutes < 1
                              ? 'sent ${age.inSeconds}s ago'
                              : age.inHours < 1
                                  ? 'sent ${age.inMinutes}m ago'
                                  : age.inDays < 1
                                      ? 'sent ${age.inHours}h ago'
                                      : 'sent ${age.inDays}d ago';
                        }

                        final bool isConfirmed =
                            local.status == _TxStatus.queued &&
                                oc?.status == 'confirmed';
                        String? confirmTimeStr;
                        if (isConfirmed) {
                          // Total latency: phone-clock delta from send to
                          // first detection as confirmed. Available for txs
                          // sent in this session.
                          final ca = local.txHash != null
                              ? widget.confirmedAt[local.txHash]
                              : null;
                          if (ca != null && !entry.isHistorical) {
                            final totalMs =
                                ca.difference(local.timestamp).inMilliseconds;
                            if (totalMs >= 0) {
                              final secs = totalMs ~/ 1000;
                              confirmTimeStr = secs < 60
                                  ? '${secs}s'
                                  : '${secs ~/ 60}m ${secs % 60}s';
                            }
                          }
                          // Fall back to inclusion_latency_ms for historical
                          // entries or when confirmedAt is unavailable.
                          if (confirmTimeStr == null &&
                              oc?.inclusionLatencyMs != null) {
                            final secs = oc!.inclusionLatencyMs! ~/ 1000;
                            confirmTimeStr = secs < 60
                                ? '${secs}s'
                                : '${secs ~/ 60}m ${secs % 60}s';
                          }
                        }

                        final txHash = local.txHash ?? oc?.txId;

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
                                color: theme.colorScheme.surfaceContainerHighest
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
                                              BorderRadius.circular(4),
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
                                            '⏱ $confirmTimeStr',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: const Color(0xFF4CAF50),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      Text(
                                        ageStr,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: spacing.space8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'To: ${_truncate(local.to, 20)}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            fontFamily: kMonoFontFamily,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Amt: ${local.amount}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  if (memoType.isNotEmpty)
                                    Padding(
                                      padding:
                                          EdgeInsets.only(top: spacing.space4),
                                      child: Text(
                                        'type: $memoType',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: muted,
                                        ),
                                      ),
                                    ),
                                  if (txHash != null && txHash.isNotEmpty)
                                    Padding(
                                      padding:
                                          EdgeInsets.only(top: spacing.space4),
                                      child: Text(
                                        'tx: ${_truncate(txHash, 24)}',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          fontFamily: kMonoFontFamily,
                                          color: muted,
                                        ),
                                      ),
                                    ),
                                  if (local.status == _TxStatus.error &&
                                      local.errorMessage != null)
                                    Padding(
                                      padding:
                                          EdgeInsets.only(top: spacing.space4),
                                      child: Text(
                                        local.errorMessage!,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: theme.colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  if (isExpanded) ...[
                                    const Divider(height: 16),
                                    if (isConfirmed &&
                                        oc?.inclusionLatencyMs != null)
                                      _buildLatencyRow(
                                        theme: theme,
                                        muted: muted,
                                        local: local,
                                        entry: entry,
                                        oc: oc!,
                                      ),
                                    _detailRow(theme, muted, 'From', local.from,
                                        mono: true),
                                    _detailRow(theme, muted, 'To', local.to,
                                        mono: true),
                                    _detailRow(theme, muted, 'Amount',
                                        local.amount.toString()),
                                    if (txHash != null && txHash.isNotEmpty)
                                      _detailRow(
                                          theme, muted, 'Tx Hash', txHash,
                                          mono: true),
                                    if (oc?.blockHeight != null)
                                      _detailRow(theme, muted, 'Block',
                                          oc!.blockHeight.toString()),
                                    _detailRow(theme, muted, 'Memo',
                                        _formatMemo(local.memo)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
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
    required _TxLogEntry local,
    required _MergedEntry entry,
    required _OnChainTx oc,
  }) {
    final inclusionSecs = oc.inclusionLatencyMs! ~/ 1000;

    final ca = (!entry.isHistorical && local.txHash != null)
        ? widget.confirmedAt[local.txHash]
        : null;
    int? totalSecs;
    int? lastMileSecs;
    if (ca != null) {
      final totalMs = ca.difference(local.timestamp).inMilliseconds;
      if (totalMs >= 0) {
        totalSecs = totalMs ~/ 1000;
        final lm = totalMs - oc.inclusionLatencyMs!;
        if (lm >= 0) lastMileSecs = lm ~/ 1000;
      }
    }

    String fmt(int s) => s < 60 ? '${s}s' : '${s ~/ 60}m ${s % 60}s';

    Widget col(String label, String value, {bool accent = false}) {
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
                color: accent ? const Color(0xFF4CAF50) : null,
                fontWeight: accent ? FontWeight.w600 : null,
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
          if (totalSecs != null)
            col('Total', '\u{23F1} ${fmt(totalSecs)}', accent: true),
          col('Inclusion', fmt(inclusionSecs)),
          if (lastMileSecs != null) col('Last mile', fmt(lastMileSecs)),
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

  static String _truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    final half = (maxLen - 1) ~/ 2;
    return '${s.substring(0, half)}…${s.substring(s.length - half)}';
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
