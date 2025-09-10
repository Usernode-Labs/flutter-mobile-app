import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
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

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pop(); // close dialog
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SendSuccessScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountVal = double.tryParse(widget.amount ?? '');
    final feeVal = double.tryParse(widget.networkFee ?? '');
    final totalVal = (amountVal ?? 0) + (feeVal ?? 0);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Review',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Amount big and centered
                    Text(
                      (amountVal != null) ? amountVal.toStringAsFixed(2) : (widget.amount ?? ''),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Amount',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    _kvRow('To', _shortAddress(widget.recipientAddress)),
                    if ((widget.memo ?? '').isNotEmpty) _kvRow('Memo', widget.memo!.trim()),
                    if ((widget.networkFee ?? '').isNotEmpty)
                      _kvRow('Network fee', feeVal != null ? feeVal.toStringAsFixed(4) : widget.networkFee!.trim()),
                    const Divider(height: 24),
                    _kvRow('Total', (amountVal != null && feeVal != null) ? totalVal.toStringAsFixed(2) : (widget.amount ?? '')),
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
    );
  }
}
