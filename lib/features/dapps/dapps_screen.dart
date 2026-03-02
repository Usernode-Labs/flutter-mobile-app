import 'dart:async';
import 'dart:convert';

import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DappsScreen extends ConsumerStatefulWidget {
  const DappsScreen({super.key});

  @override
  ConsumerState<DappsScreen> createState() => _DappsScreenState();
}

class _DappsScreenState extends ConsumerState<DappsScreen> {
  late final WebViewController _controller;
  bool _canGoBack = false;
  int _progress = 0;

  static const _jsChannelName = 'Usernode';

  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  final List<DateTime> _secretTaps = <DateTime>[];
  Timer? _secretTapResetTimer;
  bool _showUrlEditor = false;

  static Uri _defaultDappUri() {
    // Note: "localhost" inside a mobile simulator/device refers to the device itself.
    // - Android emulator: use 10.0.2.2 to reach the host machine's localhost.
    // - iOS simulator / Flutter web: localhost usually works as expected.

    const raw = String.fromEnvironment(
      'DAPP_HOMEPAGE',
      defaultValue: 'http://localhost:8000',
    );

    // Allow specifying without scheme (e.g. "localhost:8000").
    final withScheme = raw.contains('://') ? raw : 'http://$raw';
    final uri = Uri.tryParse(withScheme) ?? Uri.parse('http://localhost:8000');

    // Android emulator: "localhost" refers to the emulator. Use 10.0.2.2 for host machine.
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
      return uri.replace(host: '10.0.2.2');
    }

    return uri;
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
        debugPrint('[WebView ${message.level.name}] ${message.message}');
      })
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
              final args = payload['args'];
              if (args is! Map<String, dynamic>) {
                await _resolveJsPromise(
                  id: id,
                  value: null,
                  error: 'Missing args',
                );
                return;
              }

              final destinationPubkey =
                  (args['destination_pubkey'] as String?)?.trim();
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
                await _resolveJsPromise(
                  id: id,
                  value: null,
                  error: 'Invalid amount',
                );
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

              final fromPkHash =
                  frb_types.publicKeyHashFromString(s: fromAddress);
              final toPkHash =
                  frb_types.publicKeyHashFromString(s: destinationPubkey);

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
          } catch (_) {
            // Ignore malformed messages.
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) async {
            if (!mounted) return;
            setState(() => _progress = 0);
            await _syncNavState();
          },
          onProgress: (progress) {
            if (!mounted) return;
            // progress is 0..100
            if (progress != _progress) {
              setState(() => _progress = progress);
            }
          },
          onPageFinished: (_) async {
            if (!mounted) return;
            setState(() => _progress = 100);
            await _syncNavState();
          },
          onNavigationRequest: (_) async {
            // Keep the back button state in sync even while navigating.
            await _syncNavState();
            return NavigationDecision.navigate;
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            // Ensure the progress bar doesn't get stuck forever on load failures.
            setState(() => _progress = 100);
          },
        ),
      )
      ..loadRequest(_defaultDappUri());
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
    // Keep only last 3 taps
    if (_secretTaps.length > 3) {
      _secretTaps.removeAt(0);
    }

    // Reset window after a short delay so taps must be "fast"
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
          // Prefill with current URL (best-effort).
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

  Uri? _normalizeUserUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // If user entered without scheme, assume http.
    final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
    final parsed = Uri.tryParse(withScheme);
    if (parsed == null || parsed.host.isEmpty) return null;

    // Android emulator: map localhost -> host machine.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (parsed.host == 'localhost') {
        return parsed.replace(host: '10.0.2.2');
      }
    }
    return parsed;
  }

  Future<void> _loadUrlFromInput() async {
    final uri = _normalizeUserUrl(_urlController.text);
    if (uri == null) return;
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
    // Uses JSON encoding so values are safely escaped for JS.
    final js = 'window.__usernodeResolve(${jsonEncode(id)},'
        ' ${jsonEncode(value)}, ${jsonEncode(error)});';
    try {
      await _controller.runJavaScript(js);
    } catch (_) {
      // Ignore callback failures.
    }
  }

  BigInt? _parseAmountToBigInt(Object? amountRaw) {
    if (amountRaw is num) {
      return BigInt.from(amountRaw.round());
    }
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

  Future<void> _syncNavState() async {
    final canGoBack = await _controller.canGoBack();
    if (!mounted) return;
    if (canGoBack != _canGoBack) {
      setState(() => _canGoBack = canGoBack);
    }
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
          padding: EdgeInsets.fromLTRB(
            spacing.space12,
            spacing.space12,
            spacing.space12,
            spacing.space12,
          ),
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
              FilledButton(
                onPressed: _loadUrlFromInput,
                child: const Text('Go'),
              ),
              SizedBox(width: spacing.space8),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => _controller.reload(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _canGoBack ? () => _controller.goBack() : null,
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 0,
        actions: [
          // Hidden "triple-tap" button. Tap 3x quickly to reveal URL editor.
          Opacity(
            opacity: 0,
            child: IconButton(
              tooltip: 'Hidden',
              onPressed: _onSecretTap,
              icon: const Icon(Icons.more_horiz),
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
