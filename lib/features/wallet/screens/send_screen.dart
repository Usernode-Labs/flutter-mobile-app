import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/recipient_history_provider.dart';

import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/design_system/src/button.dart';
import 'package:crypto_mobile_app/design_system/src/sheet_layout.dart';
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
          await ref
              .read(recipientHistoryProvider.notifier)
              .addRecipient(recipientAddress);
          // Transaction successful
          if (!mounted) return;
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
    final spacing = theme.extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);
    final recipientHistory = ref.watch(recipientHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.walletSend),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.all(spacing.space16),
              sliver: SliverToBoxAdapter(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildField(
                        theme: theme,
                        controller: _addressController,
                        hint: l10n.walletRecipientAddress,
                        suffixIcon: IconButton(
                          icon: const Icon(Symbols.history_sharp),
                          tooltip: l10n.walletRecentRecipients,
                          onPressed: () => _showRecipientHistory(
                            context,
                            recipientHistory.value ?? const [],
                          ),
                        ),
                        validator: _validateRequired(
                          l10n,
                          'recipient address',
                          minLength: 20,
                        ),
                      ),
                      SizedBox(height: spacing.space16),
                      _buildField(
                        theme: theme,
                        controller: _amountController,
                        hint: l10n.walletAmount,
                        isNumeric: true,
                        validator: _validatePositiveNumber(l10n, 'amount'),
                      ),
                      SizedBox(height: spacing.space16),
                      _buildField(
                        theme: theme,
                        controller: _feeController,
                        hint: l10n.walletFee,
                        isNumeric: true,
                        validator: _validatePositiveNumber(l10n, 'fee',
                            allowZero: true),
                      ),
                      SizedBox(height: spacing.space16),
                      _buildField(
                        theme: theme,
                        controller: _memoController,
                        hint: l10n.walletMemoOptional,
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.space16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildSendButton(theme),
                    SizedBox(height: spacing.space32),
                  ],
                ),
              ),
            ),
          ],
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
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      keyboardType: isNumeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: suffixIcon,
      ),
      style: theme.textTheme.bodyLarge,
    );
  }

  Widget _buildSendButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: Button(
        label: _isSending
            ? AppLocalizations.of(context).walletSending
            : AppLocalizations.of(context).walletSend,
        variant: ButtonVariant.primary,
        size: ButtonSize.large,
        isLoading: _isSending,
        onTap: _onSend,
      ),
    );
  }

  String? Function(String?) _validateRequired(
      AppLocalizations l10n, String fieldName,
      {int minLength = 1}) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return l10n.walletFieldRequired(fieldName);
      }
      if (value.trim().length < minLength) {
        return l10n.walletFieldTooShort(
          '${fieldName[0].toUpperCase()}${fieldName.substring(1)}',
        );
      }
      return null;
    };
  }

  String? Function(String?) _validatePositiveNumber(
      AppLocalizations l10n, String fieldName,
      {bool allowZero = false}) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return l10n.walletFieldRequired(fieldName);
      }
      final number = double.tryParse(value.trim());
      if (number == null || (allowZero ? number < 0 : number <= 0)) {
        return l10n.walletFieldInvalid(fieldName);
      }

      return null;
    };
  }

  void _showRecipientHistory(BuildContext context, List<String> recipients) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        if (recipients.isEmpty) {
          return SheetLayout(
            title: l10n.walletRecentRecipients,
            child: Center(
              child: Text(
                l10n.walletNoRecentAddresses,
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
            ),
          );
        }
        return SheetLayout(
          title: l10n.walletRecentRecipients,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: recipients.length,
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
          ),
        );
      },
    );
  }
}
