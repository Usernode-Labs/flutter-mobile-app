import 'package:flutter/material.dart';
import '../../models/send_models.dart';
import '../../models/transaction_model.dart';
import '../../services/send_service.dart';
import '../../services/wallet_service.dart';
import '../../widgets/wallet/send_widget.dart';
import '../../theme/app_theme.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({Key? key}) : super(key: key);

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final TextEditingController _customFeeController = TextEditingController();

  late SendService _sendService;
  late WalletService _walletService;

  SendStep _currentStep = SendStep.enterDetails;
  FeeType _selectedFeeType = FeeType.standard;
  NetworkFee? _networkFees;
  String? _contactName;
  String? _addressError;
  String? _amountError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sendService = SendService.instance;
    _walletService = WalletService.instance;
    _loadNetworkFees();

    // Listen to address changes
    _addressController.addListener(_onAddressChanged);
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _addressController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    _customFeeController.dispose();
    super.dispose();
  }

  Future<void> _loadNetworkFees() async {
    try {
      final fees = await _sendService.getNetworkFees();
      setState(() {
        _networkFees = fees;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load network fees');
    }
  }

  void _onAddressChanged([String? value]) {
    setState(() {
      _addressError = null;
    });

    final address = _addressController.text.trim();
    if (address.isNotEmpty) {
      _loadContactName(address);
    } else {
      setState(() {
        _contactName = null;
      });
    }
  }

  void _onAmountChanged() {
    setState(() {
      _amountError = null;
    });
  }

  Future<void> _loadContactName(String address) async {
    try {
      final name = await _sendService.getContactName(address);
      setState(() {
        _contactName = name;
      });
    } catch (e) {
      // Ignore contact loading errors
    }
  }

  Future<void> _scanQRCode() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final address = await _sendService.scanQRCode();
      if (address != null) {
        _addressController.text = address;
        _onAddressChanged();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to scan QR code');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setMaxAmount() {
    final balance = _walletService.getBalance();
    final fee = _networkFees?.getFeeForType(_selectedFeeType) ?? 0;
    final maxAmount =
        (balance.tokenAmount - fee).clamp(0.0, balance.tokenAmount);
    _amountController.text = maxAmount.toStringAsFixed(2);
  }

  bool _validateInputs() {
    bool isValid = true;

    // Validate address
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(() {
        _addressError = 'Please enter a recipient address';
      });
      isValid = false;
    } else if (!SendRequest.isValidAddress(address)) {
      setState(() {
        _addressError = 'Invalid address format';
      });
      isValid = false;
    }

    // Validate amount
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      setState(() {
        _amountError = 'Please enter an amount';
      });
      isValid = false;
    } else {
      final amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        setState(() {
          _amountError = 'Please enter a valid amount';
        });
        isValid = false;
      } else {
        final balance = _walletService.getBalance();
        final fee = _networkFees?.getFeeForType(_selectedFeeType) ?? 0;
        final total = amount + fee;

        if (total > balance.tokenAmount) {
          setState(() {
            _amountError = 'Insufficient balance (including fees)';
          });
          isValid = false;
        }
      }
    }

    return isValid;
  }

  void _proceedToReview() {
    if (_validateInputs()) {
      setState(() {
        _currentStep = SendStep.review;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goBackToEdit() {
    setState(() {
      _currentStep = SendStep.enterDetails;
    });
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _confirmSend() async {
    setState(() {
      _currentStep = SendStep.processing;
      _isLoading = true;
    });

    try {
      final request = SendRequest(
        toAddress: _addressController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        memo: _memoController.text.trim().isEmpty
            ? null
            : _memoController.text.trim(),
      );

      final customFee = _selectedFeeType == FeeType.custom
          ? double.tryParse(_customFeeController.text)
          : null;

      final result = await _sendService.sendTokens(
        request,
        _selectedFeeType,
        customFee: customFee,
      );

      if (result.success) {
        setState(() {
          _currentStep = SendStep.success;
        });
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        setState(() {
          _currentStep = SendStep.error;
        });
        _showErrorSnackBar(result.errorMessage ?? 'Transaction failed');
      }
    } catch (e) {
      setState(() {
        _currentStep = SendStep.error;
      });
      _showErrorSnackBar('An unexpected error occurred');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  double _getCurrentFee() {
    if (_networkFees == null) return 0.0;

    if (_selectedFeeType == FeeType.custom) {
      return double.tryParse(_customFeeController.text) ??
          _networkFees!.getFeeForType(FeeType.standard);
    }

    return _networkFees!.getFeeForType(_selectedFeeType);
  }

  double _getTotalAmount() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final fee = _getCurrentFee();
    return amount + fee;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balance = _walletService.getBalance();

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: _currentStep == SendStep.review ||
                _currentStep == SendStep.processing
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed:
                    _currentStep == SendStep.processing ? null : _goBackToEdit,
              )
            : null,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildEnterDetailsPage(context, theme, balance),
          _buildReviewPage(context, theme),
          _buildProcessingPage(context, theme),
          _buildSuccessPage(context, theme),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentStep) {
      case SendStep.enterDetails:
        return 'Send Tokens';
      case SendStep.review:
        return 'Review Transaction';
      case SendStep.processing:
        return 'Processing...';
      case SendStep.success:
        return 'Transaction Sent';
      case SendStep.error:
        return 'Send Tokens';
    }
  }

  Widget _buildEnterDetailsPage(
      BuildContext context, ThemeData theme, WalletBalance balance) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Recipient Input
          RecipientInputCard(
            controller: _addressController,
            contactName: _contactName,
            onScanQR: _scanQRCode,
            onAddressChanged: _onAddressChanged,
            errorText: _addressError,
          ),

          const SizedBox(height: 16),

          // Amount Input
          AmountInputCard(
            controller: _amountController,
            availableBalance: balance.tokenAmount,
            onMaxTap: _setMaxAmount,
            errorText: _amountError,
          ),

          const SizedBox(height: 16),

          // Memo Input (Optional)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Memo (Optional)',
                    style: AppTheme.nodeStatusStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _memoController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Add a note for this transaction',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: theme.colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: theme.colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: theme.colorScheme.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    style: AppTheme.nodeStatusStyle,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Fee Selection
          if (_networkFees != null)
            FeeSelectionCard(
              selectedFee: _selectedFeeType,
              networkFees: _networkFees!,
              onFeeSelected: (feeType) {
                setState(() {
                  _selectedFeeType = feeType;
                });
              },
              customFeeController: _customFeeController,
            ),

          const SizedBox(height: 24),

          // Continue Button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : _proceedToReview,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Review Transaction'),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildReviewPage(BuildContext context, ThemeData theme) {
    final request = SendRequest(
      toAddress: _addressController.text.trim(),
      amount: double.tryParse(_amountController.text.trim()) ?? 0.0,
      memo: _memoController.text.trim().isEmpty
          ? null
          : _memoController.text.trim(),
    );

    final fee = _getCurrentFee();
    final total = _getTotalAmount();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TransactionSummaryCard(
            request: request,
            fee: fee,
            total: total,
            contactName: _contactName,
          ),

          const SizedBox(height: 24),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _confirmSend,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.successCheckColor,
              ),
              child: const Text('Confirm & Send'),
            ),
          ),

          const SizedBox(height: 12),

          // Edit Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _goBackToEdit,
              child: const Text('Edit Transaction'),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProcessingPage(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Processing Transaction',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Please wait while your transaction\nis being processed...',
            style: AppTheme.nodeSubtitleStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessPage(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.successCheckColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 60,
                color: AppTheme.successCheckColor,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Transaction Sent!',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.successCheckColor,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your transaction has been successfully\nsubmitted to the network.',
              style: AppTheme.nodeSubtitleStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Done'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // TODO: Navigate to transaction details
                  _showErrorSnackBar('Transaction details coming soon!');
                },
                child: const Text('View Transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
