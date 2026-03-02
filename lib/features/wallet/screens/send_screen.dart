import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/recipient_history_provider.dart';
import 'package:crypto_mobile_app/features/wallet/transaction_limits_service.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';

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
  TransactionLimitsService? _limitsService;

  @override
  void initState() {
    super.initState();
    _initLimitsService();
  }

  Future<void> _initLimitsService() async {
    _limitsService = await TransactionLimitsService.getInstance();
  }

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

    // Check transaction limits
    if (_limitsService != null) {
      final canSend = await _limitsService!.canSendTransaction();
      if (!canSend) {
        final error = await _limitsService!.getTransactionCountError();
        if (mounted) {
          context.push(AppRoutes.walletSendFailed, extra: {
            'errorMessage': error,
          });
        }
        return;
      }
    }

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
      final fromPkHash =
          frb_types.publicKeyHashFromString(s: userAccount.address);

      // Convert recipient address to PublicKeyHash
      final recipientAddress = _addressController.text.trim();
      final toPkHash = frb_types.publicKeyHashFromString(s: recipientAddress);

      // Parse amount (keep as entered, no multiplication)
      final amountStr = _amountController.text.trim();
      final amount = BigInt.from(double.parse(amountStr).round());

      // Call the transfer funds RPC
      final response = await RustBackendService.instance.transferFunds(
        fromPkHash: fromPkHash,
        amount: amount,
        toPkHash: toPkHash,
      );

      if (mounted) {
        if (response != null && response.queued) {
          // Increment transaction count after successful transaction
          await _limitsService?.incrementTransactionCount();

          await ref
              .read(recipientHistoryProvider.notifier)
              .addRecipient(recipientAddress);
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
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);
    final recipientHistory = ref.watch(recipientHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_sharp),
          onPressed: () => context.pop(),
        ),
        title: const Text('Send'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(spacing.space16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildField(
                          theme: theme,
                          controller: _addressController,
                          hint: 'Recipient address',
                          suffixIcon: IconButton(
                            icon: const Icon(Symbols.history_sharp),
                            tooltip: 'Recent recipients',
                            onPressed: () => _showRecipientHistory(
                              context,
                              recipientHistory.value ?? const [],
                            ),
                          ),
                          validator: _validateRequired(
                            'recipient address',
                            minLength: 20,
                          ),
                        ),
                        SizedBox(height: spacing.space16),
                        _buildField(
                          theme: theme,
                          controller: _amountController,
                          hint: 'Amount',
                          isNumeric: true,
                          validator: _validatePositiveNumber('amount'),
                        ),
                        SizedBox(height: spacing.space16),
                        _buildField(
                          theme: theme,
                          controller: _feeController,
                          hint: 'Fee',
                          isNumeric: true,
                          validator:
                              _validatePositiveNumber('fee', allowZero: true),
                        ),
                        SizedBox(height: spacing.space16),
                        _buildField(
                          theme: theme,
                          controller: _memoController,
                          hint: 'Memo (optional)',
                          maxLines: 4,
                        ),
                        const Spacer(),
                        _buildSendButton(theme),
                        SizedBox(height: spacing.space24),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(radii.small),
        topRight: Radius.circular(radii.small),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outline,
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
            contentPadding: EdgeInsets.all(spacing.space16),
            hintText: hint,
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
            suffixIcon: suffixIcon,
          ),
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(ThemeData theme) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
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
        borderRadius: radii.borderRadiusFull,
      ),
      child: ElevatedButton(
        onPressed: _isSending ? null : _onSend,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: radii.borderRadiusFull,
          ),
        ),
        child: _isSending
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: spacing.space12),
                  const Text(
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

      // Check amount limit for amount field
      if (fieldName == 'amount' && _limitsService != null) {
        final amountError = _limitsService!.getAmountError(number);
        if (amountError != null) {
          return amountError;
        }
      }

      return null;
    };
  }

  void _showRecipientHistory(BuildContext context, List<String> recipients) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        if (recipients.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(spacing.space24),
            child: const Center(
              child: Text('No recent addresses'),
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.symmetric(vertical: spacing.space8),
          itemCount: recipients.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final address = recipients[index];
            return ListTile(
              leading: const Icon(Symbols.history_sharp),
              title: Text(
                address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                _addressController.text = address;
                Navigator.of(sheetContext).pop();
              },
            );
          },
        );
      },
    );
  }
}
