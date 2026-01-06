import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/features/wallet/accounts_provider.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;
import 'package:crypto_mobile_app/core/config/app_router.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _feeController = TextEditingController(text: '1');
  final _memoController = TextEditingController();
  
  bool _isSending = false;

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _feeController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _onSend() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSending) return; // Prevent double submission

    setState(() {
      _isSending = true;
    });

    try {
      // Get the current user's account
      final accountsRepo = await AccountsRepository.create();
      final userAccount = await accountsRepo.getActive();
      
      if (userAccount == null) {
        throw Exception('No active account found');
      }

      // Convert user's address to PublicKeyHash
      final fromPkHash = frb_types.publicKeyHashFromString(s: userAccount.address);
      
      // Convert recipient address to PublicKeyHash
      final recipientAddress = _addressController.text.trim();
      final toPkHash = frb_types.publicKeyHashFromString(s: recipientAddress);
      
      // Parse amount (convert to smallest unit - assuming integer tokens for now)
      final amountStr = _amountController.text.trim();
      final amount = BigInt.from((double.parse(amountStr) * 1000000).round()); // Convert to micro-tokens
      
      // Call the transfer funds RPC
      final response = await RustBackendService.instance.transferFunds(
        fromPkHash: fromPkHash,
        amount: amount,
        toPkHash: toPkHash,
      );

      if (mounted) {
        if (response != null && response.queued) {
          // Transaction successful
          context.push(AppRoutes.walletSendSuccess, extra: {
            'amount': amountStr,
            'tokenSymbol': '\$TOKEN', // TODO: Get actual token symbol
            'recipientAddress': recipientAddress,
          });
        } else {
          // Transaction failed
          final errorMessage = response?.error ?? 'Unknown error occurred';
          context.push(AppRoutes.walletSendFailed, extra: {
            'errorMessage': errorMessage,
          });
        }
      }
    } catch (e) {
      if (mounted) {
        // Handle any errors (invalid address, parsing errors, etc.)
        context.push(AppRoutes.walletSendFailed, extra: {
          'errorMessage': e.toString(),
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Send'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildField(
                  theme: theme,
                  controller: _addressController,
                  hint: 'Recipient address',
                  validator:
                      _validateRequired('recipient address', minLength: 20),
                ),
                const SizedBox(height: 18),
                _buildField(
                  theme: theme,
                  controller: _amountController,
                  hint: 'Amount',
                  isNumeric: true,
                  validator: _validatePositiveNumber('amount'),
                ),
                const SizedBox(height: 18),
                _buildField(
                  theme: theme,
                  controller: _feeController,
                  hint: 'Fee',
                  isNumeric: true,
                  validator: _validatePositiveNumber('fee', allowZero: true),
                ),
                const SizedBox(height: 18),
                _buildField(
                  theme: theme,
                  controller: _memoController,
                  hint: 'Memo (optional)',
                  maxLines: 4,
                ),
                const Spacer(),
                _buildSendButton(theme),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required ThemeData theme,
    required TextEditingController controller,
    required String hint,
    bool isNumeric = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(6),
        topRight: Radius.circular(6),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade600,
              width: 1,
            ),
          ),
        ),
        child: TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          decoration: InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
            contentPadding: const EdgeInsets.all(16),
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black87, fontSize: 16),
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildSendButton(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _isSending 
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : theme.colorScheme.primary,
            _isSending
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: ElevatedButton(
        onPressed: _isSending ? null : _onSend,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: _isSending
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Sending...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : const Text(
                'Send',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  String? Function(String?) _validateRequired(String fieldName,
      {int minLength = 1}) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return 'Please enter a $fieldName';
      }
      if (value.trim().length < minLength) {
        return '${fieldName[0].toUpperCase()}${fieldName.substring(1)} appears to be too short';
      }
      return null;
    };
  }

  String? Function(String?) _validatePositiveNumber(String fieldName,
      {bool allowZero = false}) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return 'Please enter a $fieldName';
      }
      final number = double.tryParse(value.trim());
      if (number == null || (allowZero ? number < 0 : number <= 0)) {
        return 'Please enter a valid $fieldName';
      }
      return null;
    };
  }
}
