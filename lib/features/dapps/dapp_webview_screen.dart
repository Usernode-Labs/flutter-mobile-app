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
import 'package:material_symbols_icons/symbols.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

    final userConfirmed = await _showTransactionConfirmation(
      from: fromAddress,
      to: destinationPubkey,
      amount: amount,
      memo: memoString,
    );

    if (!userConfirmed) {
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

    await _resolveJsPromise(
      id: id,
      value: <String, dynamic>{
        'queued': resp?.queued ?? false,
        'error': resp?.error,
      },
      error: null,
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
        title: Text(widget.name),
        titleSpacing: 0,
        actions: [
          Opacity(
            opacity: 0,
            child: IconButton(
              tooltip: 'Hidden',
              onPressed: _onSecretTap,
              icon: const Icon(Symbols.more_horiz_sharp),
            ),
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
