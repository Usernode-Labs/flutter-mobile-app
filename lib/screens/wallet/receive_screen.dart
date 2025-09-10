import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/receive_models.dart';
import '../../services/receive_service.dart';
import '../../widgets/wallet/receive_widgets.dart';
import '../../theme/app_theme.dart';
import '../../gen_l10n/app_localizations.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  late ReceiveService _receiveService;

  ReceiveAddress? _currentAddress;
  PaymentRequest? _currentPaymentRequest;
  // No long-running UI state here after simplification

  @override
  void initState() {
    super.initState();
    _receiveService = ReceiveService.instance;
    _loadCurrentAddress();

  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadCurrentAddress() async {
    try {
      final address = await _receiveService.getCurrentAddress();
      setState(() {
        _currentAddress = address;
        _currentPaymentRequest = _receiveService.createPaymentRequest(
          address: address.address,
        );
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load receiving address');
    } finally {}
  }


  Future<void> _copyAddressToClipboard() async {
    if (_currentAddress != null) {
      await Clipboard.setData(ClipboardData(text: _currentAddress!.address));
      _showSuccessSnackBar('Address copied to clipboard');
    }
  }

  // Amount/memo request removed per design update

  void _showQRCodeDialog() {
    if (_currentPaymentRequest != null) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Payment QR Code',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code,
                          size: 100,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'QR Code',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Amount and memo removed per design update
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _currentPaymentRequest!.qrData),
                          );
                          _showSuccessSnackBar('Payment data copied');
                        },
                        child: const Text('Copy Data'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successCheckColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).receive),
      ),
      body: SafeArea(
        child: _buildReceiveTab(),
      ),
    );
  }

  Widget _buildReceiveTab() {
    if (_currentAddress == null || _currentPaymentRequest == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // QR Code Card
          QRCodeCard(
            qrData: _currentPaymentRequest!.qrData,
            onTap: _showQRCodeDialog,
          ),

          const SizedBox(height: 16),

          // Address Display Card
          AddressDisplayCard(
            address: _currentAddress!,
            onCopy: _copyAddressToClipboard,
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

}
