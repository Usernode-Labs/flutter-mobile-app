import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/receive_models.dart';
import '../../services/receive_service.dart';
import '../../widgets/wallet/receive_widgets.dart';
import '../../theme/app_theme.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({Key? key}) : super(key: key);

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen>
    with TickerProviderStateMixin {
  late ReceiveService _receiveService;
  late TabController _tabController;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  ReceiveAddress? _currentAddress;
  PaymentRequest? _currentPaymentRequest;
  String? _amountError;
  final bool _isLoading = false;
  bool _isGeneratingAddress = false;

  @override
  void initState() {
    super.initState();
    _receiveService = ReceiveService.instance;
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentAddress();

    // Listen to amount changes for validation
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentAddress() async {
    setState(() {
      _isGeneratingAddress = true;
    });

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
    } finally {
      setState(() {
        _isGeneratingAddress = false;
      });
    }
  }

  void _onAmountChanged() {
    setState(() {
      _amountError = null;
    });
  }

  Future<void> _generateNewAddress() async {
    setState(() {
      _isGeneratingAddress = true;
    });

    try {
      final newAddress = await _receiveService.generateNewAddress();
      setState(() {
        _currentAddress = newAddress;
        _currentPaymentRequest = _receiveService.createPaymentRequest(
          address: newAddress.address,
        );
      });
      _showSuccessSnackBar('New address generated successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to generate new address');
    } finally {
      setState(() {
        _isGeneratingAddress = false;
      });
    }
  }

  Future<void> _copyAddressToClipboard() async {
    if (_currentAddress != null) {
      await Clipboard.setData(ClipboardData(text: _currentAddress!.address));
      _showSuccessSnackBar('Address copied to clipboard');
    }
  }

  Future<void> _shareAddress() async {
    if (_currentAddress != null) {
      try {
        final success = await _receiveService.shareAddress(
          _currentAddress!.address,
          ShareMethod.share,
        );
        if (success) {
          _showSuccessSnackBar('Address shared successfully');
        }
      } catch (e) {
        _showErrorSnackBar('Failed to share address');
      }
    }
  }

  void _createPaymentRequest() {
    // Validate amount
    final validation = _receiveService.validateAmount(_amountController.text);
    if (!validation.isValid) {
      setState(() {
        _amountError = validation.errorMessage;
      });
      return;
    }

    if (_currentAddress != null) {
      final amount = _amountController.text.trim().isEmpty
          ? null
          : double.tryParse(_amountController.text.trim());

      final memo = _memoController.text.trim().isEmpty
          ? null
          : _memoController.text.trim();

      setState(() {
        _currentPaymentRequest = _receiveService.createPaymentRequest(
          address: _currentAddress!.address,
          amount: amount,
          memo: memo,
        );
      });

      _showSuccessSnackBar('Payment request created');
    }
  }

  void _selectAddressFromHistory(ReceiveAddress address) {
    setState(() {
      _currentAddress = address;
      _currentPaymentRequest = _receiveService.createPaymentRequest(
        address: address.address,
      );
    });
    _showSuccessSnackBar('Address selected');
  }

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
                if (_currentPaymentRequest!.hasAmount) ...[
                  Text(
                    'Amount: ${_currentPaymentRequest!.formattedAmount}',
                    style: AppTheme.nodeStatusStyle,
                  ),
                  const SizedBox(height: 8),
                ],
                if (_currentPaymentRequest!.hasMemo) ...[
                  Text(
                    'Note: ${_currentPaymentRequest!.memo}',
                    style: AppTheme.nodeSubtitleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Tokens'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Receive'),
            Tab(text: 'History'),
          ],
        ),
        actions: [
          if (_isGeneratingAddress)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _generateNewAddress,
              tooltip: 'Generate new address',
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReceiveTab(),
          _buildHistoryTab(),
        ],
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
            onShare: _shareAddress,
            onGenerateNew: _generateNewAddress,
          ),

          const SizedBox(height: 16),

          // Payment Request Form
          PaymentRequestForm(
            amountController: _amountController,
            memoController: _memoController,
            amountError: _amountError,
            onCreateRequest: _createPaymentRequest,
            isLoading: _isLoading,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final addresses = _receiveService.getAllAddresses();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          AddressHistoryCard(
            addresses: addresses,
            onAddressSelected: _selectAddressFromHistory,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
