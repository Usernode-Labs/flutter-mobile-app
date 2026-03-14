import 'dart:async';
import 'dart:convert';

import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/design_system/src/button.dart';
import 'package:crypto_mobile_app/design_system/src/sheet_layout.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_typography.dart';
import 'package:crypto_mobile_app/features/dapps/providers/dapps_provider.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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

  const _TxLogEntry({
    required this.timestamp,
    required this.from,
    required this.to,
    required this.amount,
    required this.memo,
    required this.status,
    this.errorMessage,
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
            final payload =
                jsonDecode(message.message) as Map<String, dynamic>;
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.setBackgroundColor(Theme.of(context).colorScheme.surface);
  }

  @override
  void dispose() {
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
    _txLog.insert(
      0,
      _TxLogEntry(
        timestamp: DateTime.now(),
        from: fromAddress,
        to: destinationPubkey,
        amount: amount,
        memo: memoString,
        status: (rpcError != null && rpcError.isNotEmpty)
            ? _TxStatus.error
            : _TxStatus.queued,
        errorMessage: rpcError,
      ),
    );

    await _resolveJsPromise(
      id: id,
      value: <String, dynamic>{
        'queued': resp?.queued ?? false,
        'error': rpcError,
      },
      error: null,
    );
  }

  /// Pushes a full-screen opaque route for transaction confirmation.
  /// Returns `true` if confirmed, `false` if denied.
  Future<bool> _requestTransactionConfirmation({
    required String from,
    required String to,
    required BigInt amount,
    required String memo,
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

  Future<bool> _showTransactionConfirmation({
    required String from,
    required String to,
    required BigInt amount,
    required String memo,
  }) async {
    if (!mounted) return false;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final spacing = theme.extension<AppSpacing>()!;
        final radii = theme.extension<AppRadii>()!;
        final muted = theme.colorScheme.onSurfaceVariant;

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

        String formattedMemo = memo;
        if (memo.isNotEmpty) {
          try {
            final parsed = jsonDecode(memo);
            const encoder = JsonEncoder.withIndent('  ');
            formattedMemo = encoder.convert(parsed);
          } catch (_) {
            // Not valid JSON — show raw string.
          }
        }

        final memoBox = formattedMemo.isEmpty
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    constraints: const BoxConstraints(maxHeight: 150),
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
              );

        return SheetLayout(
          title: 'Confirm Transaction',
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.space16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'A dapp is requesting to send a transaction.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                SizedBox(height: spacing.space16),
                Flexible(
                  child: Container(
                    padding: EdgeInsets.all(spacing.space16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withAlpha(100),
                      borderRadius: radii.borderRadiusMedium,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withAlpha(80),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          detailRow('From', from, mono: true),
                          const Divider(height: 1),
                          detailRow('To', to, mono: true),
                          const Divider(height: 1),
                          detailRow('Amount', amount.toString()),
                          const Divider(height: 1),
                          detailRow('Fee', '0'),
                          memoBox,
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: spacing.space24),
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
                        label: 'Confirm',
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
    );

    return confirmed ?? false;
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
class _TxConfirmationPage extends StatelessWidget {
  const _TxConfirmationPage({
    required this.from,
    required this.to,
    required this.amount,
    required this.memo,
  });

  final String from;
  final String to;
  final BigInt amount;
  final String memo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final radii = theme.extension<AppRadii>()!;
    final muted = theme.colorScheme.onSurfaceVariant;

    String formattedMemo = memo;
    if (memo.isNotEmpty) {
      try {
        final parsed = jsonDecode(memo);
        const encoder = JsonEncoder.withIndent('  ');
        formattedMemo = encoder.convert(parsed);
      } catch (_) {
        // Not valid JSON — show raw string.
      }
    }

    final memoBox = formattedMemo.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
          );

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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Symbols.arrow_back_sharp),
        ),
        title: const Text('Confirm Transaction'),
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'A dapp is requesting to send a transaction.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              SizedBox(height: spacing.space16),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(spacing.space16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withAlpha(100),
                    borderRadius: radii.borderRadiusMedium,
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withAlpha(80),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        detailRow('From', from, mono: true),
                        const Divider(height: 1),
                        detailRow('To', to, mono: true),
                        const Divider(height: 1),
                        detailRow('Amount', amount.toString()),
                        const Divider(height: 1),
                        detailRow('Fee', '0'),
                        memoBox,
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

  const _OnChainTx({
    required this.txId,
    this.source,
    this.destination,
    this.memo,
    this.status,
    this.amount,
    this.blockHeight,
    this.timestampMs,
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
    );
  }
}

class _MergedEntry {
  final _TxLogEntry local;
  final _OnChainTx? onChain;

  const _MergedEntry({required this.local, this.onChain});
}

class _TxDebugPanel extends StatefulWidget {
  final List<_TxLogEntry> txLog;
  final String? userAddress;
  final Uri explorerOrigin;

  const _TxDebugPanel({
    required this.txLog,
    required this.userAddress,
    required this.explorerOrigin,
  });

  @override
  State<_TxDebugPanel> createState() => _TxDebugPanelState();
}

class _TxDebugPanelState extends State<_TxDebugPanel> {
  List<_OnChainTx> _onChainTxs = [];
  bool _loading = true;
  String? _fetchError;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _fetchExplorerData();
  }

  Future<void> _fetchExplorerData() async {
    final address = widget.userAddress;
    if (address == null || address.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

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

      final txRes = await http.post(
        base.resolve('/explorer-api/$chainId/transactions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sender': address, 'limit': 50}),
      );
      if (txRes.statusCode != 200) {
        throw Exception('Transaction fetch failed (${txRes.statusCode})');
      }
      final txData = jsonDecode(txRes.body) as Map<String, dynamic>;
      final items = (txData['items'] as List<dynamic>?) ?? [];
      final txs =
          items.map((e) => _OnChainTx.fromJson(e as Map<String, dynamic>));

      if (mounted) {
        setState(() {
          _onChainTxs = txs.toList();
          _loading = false;
        });
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

    return widget.txLog.map((local) {
      if (local.status != _TxStatus.queued) {
        return _MergedEntry(local: local);
      }

      for (final oc in _onChainTxs) {
        if (matched.contains(oc.txId)) continue;
        if (oc.destination == local.to && oc.memo == local.memo) {
          matched.add(oc.txId);
          return _MergedEntry(local: local, onChain: oc);
        }
      }

      return _MergedEntry(local: local);
    }).toList();
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
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: muted),
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
                          _TxStatus.error => (
                              theme.colorScheme.error,
                              'Error'
                            ),
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
                        final ageStr = age.inMinutes < 1
                            ? '${age.inSeconds}s ago'
                            : age.inHours < 1
                                ? '${age.inMinutes}m ago'
                                : age.inDays < 1
                                    ? '${age.inHours}h ago'
                                    : '${age.inDays}d ago';

                        final txHash = oc?.txId;

                        return Padding(
                          padding:
                              EdgeInsets.only(bottom: spacing.space8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _expandedIndex =
                                    isExpanded ? null : index;
                              });
                            },
                            child: Container(
                              padding:
                                  EdgeInsets.all(spacing.space12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha(100),
                                borderRadius:
                                    radii.borderRadiusMedium,
                                border: Border.all(
                                  color: theme
                                      .colorScheme.outlineVariant
                                      .withAlpha(80),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: badgeColor
                                              .withAlpha(30),
                                          borderRadius:
                                              BorderRadius
                                                  .circular(4),
                                        ),
                                        child: Text(
                                          badgeLabel,
                                          style: theme
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                            color: badgeColor,
                                            fontWeight:
                                                FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        ageStr,
                                        style: theme
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                      height: spacing.space8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'To: ${_truncate(local.to, 20)}',
                                          style: theme
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                            fontFamily:
                                                kMonoFontFamily,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Amt: ${local.amount}',
                                        style: theme
                                            .textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  if (memoType.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(
                                          top: spacing.space4),
                                      child: Text(
                                        'type: $memoType',
                                        style: theme
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                          color: muted,
                                        ),
                                      ),
                                    ),
                                  if (txHash != null &&
                                      txHash.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(
                                          top: spacing.space4),
                                      child: Text(
                                        'tx: ${_truncate(txHash, 24)}',
                                        style: theme
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                          fontFamily:
                                              kMonoFontFamily,
                                          color: muted,
                                        ),
                                      ),
                                    ),
                                  if (local.status ==
                                          _TxStatus.error &&
                                      local.errorMessage != null)
                                    Padding(
                                      padding: EdgeInsets.only(
                                          top: spacing.space4),
                                      child: Text(
                                        local.errorMessage!,
                                        style: theme
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  if (isExpanded) ...[
                                    const Divider(height: 16),
                                    _detailRow(
                                        theme, muted, 'From',
                                        local.from,
                                        mono: true),
                                    _detailRow(
                                        theme, muted, 'To',
                                        local.to,
                                        mono: true),
                                    _detailRow(
                                        theme,
                                        muted,
                                        'Amount',
                                        local.amount
                                            .toString()),
                                    if (txHash != null &&
                                        txHash.isNotEmpty)
                                      _detailRow(
                                          theme,
                                          muted,
                                          'Tx Hash',
                                          txHash,
                                          mono: true),
                                    if (oc?.blockHeight != null)
                                      _detailRow(
                                          theme,
                                          muted,
                                          'Block',
                                          oc!.blockHeight
                                              .toString()),
                                    _detailRow(
                                        theme,
                                        muted,
                                        'Memo',
                                        _formatMemo(
                                            local.memo)),
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
