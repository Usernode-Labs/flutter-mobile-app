import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as rust_types;
import 'send_success_screen.dart';

class ReviewSendScreen extends StatefulWidget {
  final String? recipientAddress;
  final String? amount;
  final String? memo;
  final String? networkFee;

  const ReviewSendScreen({
    super.key,
    this.recipientAddress,
    this.amount,
    this.memo,
    this.networkFee,
  });

  @override
  State<ReviewSendScreen> createState() => _ReviewSendScreenState();
}

class _ReviewSendScreenState extends State<ReviewSendScreen> {
  String _shortAddress(String? addr) {
    final a = (addr ?? '').trim();
    if (a.length <= 14) return a;
    return '${a.substring(0, 8)}…${a.substring(a.length - 6)}';
  }

  Widget _kvRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processAndNavigate() async {
    // Show modal processing overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    );

    try {
      // Get active account
      final accountsRepo = await AccountsRepository.create();
      final activeAccount = await accountsRepo.getActive();

      if (activeAccount == null) {
        if (!mounted) return;
        Navigator.of(context).pop(); // close loading dialog
        _showErrorDialog(
            'No active account found. Please create or select an account.');
        return;
      }

      // Parse addresses to TreeHash
      // Force sender to requested account string
      const forcedFrom =
          'ut1na9lq2yny9l2l6axf09g3mhhmhed3vj7tpejs4f28xe2cjd6n5qqg9ww4x';
      final fromPkHash = rust_types.publicKeyHashFromString(s: forcedFrom);
      final toPkHash =
          rust_types.publicKeyHashFromString(s: widget.recipientAddress ?? '');

      // Convert amount: send entered amount as-is (integer only)
      final amountStr = (widget.amount ?? '0').trim();
      BigInt? amount;
      try {
        amount = BigInt.parse(amountStr);
      } catch (_) {
        amount = null;
      }
      if (amount == null) {
        if (!mounted) return;
        Navigator.of(context).pop();
        _showErrorDialog('Invalid amount. Enter a whole-number amount.');
        return;
      }

      // Call transferFunds RPC
      final response = await RustBackendService.instance.transferFunds(
        fromPkHash: fromPkHash,
        amount: amount,
        toPkHash: toPkHash,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close loading dialog

      if (response == null) {
        _showErrorDialog(
            'Failed to connect to node. Please ensure the node is running.');
        return;
      }

      if (response.error != null) {
        _showErrorDialog('Transfer failed: ${response.error}');
        return;
      }

      if (!response.queued) {
        _showErrorDialog('Transfer was not queued. Please try again.');
        return;
      }

      // Success - navigate to success screen
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SendSuccessScreen()),
      );
    } catch (e, st) {
      LoggingService.instance
          .error('Transfer failed', tag: 'SEND', error: e, stackTrace: st);
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading dialog
      _showErrorDialog('Transfer failed: ${e.toString()}');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountVal = double.tryParse(widget.amount ?? '');
    final feeVal = double.tryParse(widget.networkFee ?? '');
    final totalVal = (amountVal ?? 0) + (feeVal ?? 0);

    return Scaffold(
        appBar: const AppAppBar(
          title: 'Review Send',
          showNotifications: false,
          showNodeStatus: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Amount big and centered
                        Text(
                          (amountVal != null)
                              ? amountVal.toStringAsFixed(2)
                              : (widget.amount ?? ''),
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Amount',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        _kvRow('To', _shortAddress(widget.recipientAddress)),
                        if ((widget.memo ?? '').isNotEmpty)
                          _kvRow('Memo', widget.memo!.trim()),
                        if ((widget.networkFee ?? '').isNotEmpty)
                          _kvRow(
                              'Network fee',
                              feeVal != null
                                  ? feeVal.toStringAsFixed(4)
                                  : widget.networkFee!.trim()),
                        const Divider(height: 24),
                        _kvRow(
                            'Total',
                            (amountVal != null && feeVal != null)
                                ? totalVal.toStringAsFixed(2)
                                : (widget.amount ?? '')),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _processAndNavigate,
                        child: const Text('Send'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ));
  }
}
