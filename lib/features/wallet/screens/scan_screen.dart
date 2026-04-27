import 'dart:convert';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/widgets/tx_confirmation_page.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// QR payload parsed from a scanned code.
class _QrTxPayload {
  _QrTxPayload({
    required this.to,
    required this.amount,
    required this.memo,
    this.confirmTitle,
    this.confirmSubtitle,
  });

  final String to;
  final BigInt amount;
  final String memo;
  final String? confirmTitle;
  final String? confirmSubtitle;
}

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _processing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  _QrTxPayload? _parseTxPayload(String raw, AppLocalizations l10n) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      _showError(l10n.walletScanInvalidQr);
      return null;
    }

    final type = json['type'];
    if (type != 'tx') {
      _showError(l10n.walletScanUnsupportedType);
      return null;
    }

    final to = json['to'] as String?;
    final amountRaw = json['amount'];
    if (to == null || to.isEmpty || amountRaw == null) {
      _showError(l10n.walletScanInvalidQr);
      return null;
    }

    BigInt? amount;
    if (amountRaw is num) {
      amount = BigInt.from(amountRaw.round());
    } else if (amountRaw is String) {
      final parsed = double.tryParse(amountRaw.trim());
      if (parsed != null) amount = BigInt.from(parsed.round());
    }
    if (amount == null || amount <= BigInt.zero) {
      _showError(l10n.walletScanInvalidQr);
      return null;
    }

    final memo = json['memo'] as String? ?? '';

    return _QrTxPayload(
      to: to,
      amount: amount,
      memo: memo,
      confirmTitle: json['confirmTitle'] as String?,
      confirmSubtitle: json['confirmSubtitle'] as String?,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final l10n = AppLocalizations.of(context);
    setState(() => _processing = true);
    await _scannerController.stop();

    final payload = _parseTxPayload(barcode.rawValue!, l10n);

    if (payload == null) {
      setState(() => _processing = false);
      await _scannerController.start();
      return;
    }

    await _processPayload(payload);
  }

  Future<void> _processPayload(_QrTxPayload payload) async {
    final accountsRepo = await AccountsRepository.create();
    final userAccount = await accountsRepo.getActive();
    final address = userAccount?.address;

    if (!mounted) return;

    if (address == null || address.isEmpty) {
      _showError(AppLocalizations.of(context).walletNoActiveAccount);
      Navigator.pop(context);
      return;
    }

    final confirmed = await requestTransactionConfirmation(
      context,
      from: address,
      to: payload.to,
      amount: payload.amount,
      memo: payload.memo,
      confirmTitle: payload.confirmTitle,
      confirmSubtitle: payload.confirmSubtitle,
    );

    if (!confirmed) {
      if (mounted) {
        setState(() => _processing = false);
        await _scannerController.start();
      }
      return;
    }

    await _submitTransaction(address, payload);
  }

  Future<void> _submitTransaction(String from, _QrTxPayload payload) async {
    if (!mounted) return;

    try {
      final rpc = RustBackendService.instance.rpc;
      if (rpc == null) {
        throw Exception('Node RPC unavailable');
      }

      final fromPkHash = frb_types.publicKeyHashFromString(s: from);
      final toPkHash = frb_types.publicKeyHashFromString(s: payload.to);
      final memo = frb_types.Memo.fromUtf8Str(s: payload.memo);

      final resp = await rpc.wallet().txSend(
            fromPkHash: fromPkHash,
            amount: payload.amount,
            toPkHash: toPkHash,
            memo: memo,
          );

      if (!mounted) return;

      final rpcError = resp?.error;
      final isQueued = rpcError == null || rpcError.isEmpty;

      if (isQueued) {
        context.go(AppRoutes.walletSendSuccess, extra: {
          'amount': payload.amount.toString(),
          'tokenSymbol': '\$TOKEN',
          'recipientAddress': payload.to,
        });
      } else {
        context.go(AppRoutes.walletSendFailed, extra: {
          'errorMessage': rpcError,
        });
      }
    } catch (e) {
      if (!mounted) return;
      context.go(AppRoutes.walletSendFailed, extra: {
        'errorMessage': e.toString(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Symbols.arrow_back_sharp),
        ),
        title: Text(l10n.walletScanTitle),
        titleSpacing: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcode,
            errorBuilder: (context, error) {
              final message =
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? l10n.walletScanCameraPermissionDenied
                      : error.errorCode == MobileScannerErrorCode.unsupported
                          ? 'Camera not available on this device'
                          : error.errorCode.message;
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(spacing.space24),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
          // Viewfinder overlay
          CustomPaint(
            painter: _ViewfinderPainter(
              borderColor: theme.colorScheme.primary,
              overlayColor: Colors.black54,
            ),
            child: const SizedBox.expand(),
          ),
          if (_processing) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter({
    required this.borderColor,
    required this.overlayColor,
  });

  final Color borderColor;
  final Color overlayColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cutoutSize = size.shortestSide * 0.7;
    final left = (size.width - cutoutSize) / 2;
    final top = (size.height - cutoutSize) / 2;
    final cutout = Rect.fromLTWH(left, top, cutoutSize, cutoutSize);
    final cutoutRRect =
        RRect.fromRectAndRadius(cutout, const Radius.circular(16));

    // Semi-transparent overlay with cutout
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cutoutRRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlayPath, Paint()..color = overlayColor);

    // Corner brackets
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 32.0;
    final r = cutoutRRect.outerRect;

    // Top-left
    canvas.drawLine(Offset(r.left, r.top + cornerLen), r.topLeft, paint);
    canvas.drawLine(r.topLeft, Offset(r.left + cornerLen, r.top), paint);
    // Top-right
    canvas.drawLine(Offset(r.right - cornerLen, r.top), r.topRight, paint);
    canvas.drawLine(r.topRight, Offset(r.right, r.top + cornerLen), paint);
    // Bottom-left
    canvas.drawLine(Offset(r.left, r.bottom - cornerLen), r.bottomLeft, paint);
    canvas.drawLine(r.bottomLeft, Offset(r.left + cornerLen, r.bottom), paint);
    // Bottom-right
    canvas.drawLine(
        Offset(r.right - cornerLen, r.bottom), r.bottomRight, paint);
    canvas.drawLine(
        r.bottomRight, Offset(r.right, r.bottom - cornerLen), paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter oldDelegate) =>
      borderColor != oldDelegate.borderColor ||
      overlayColor != oldDelegate.overlayColor;
}
