import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/utils/utils.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TransactionSuccessScreen extends StatelessWidget {
  final String amount;
  final String tokenSymbol;
  final String recipientAddress;

  const TransactionSuccessScreen({
    super.key,
    required this.amount,
    required this.tokenSymbol,
    required this.recipientAddress,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayAddress = Utils.shortenID(recipientAddress, head: 8, tail: 8);

    return Scaffold(
      body: ResultPage(
        variant: ResultPageVariant.success,
        title: l10n.walletSentSuccessfully,
        subtitle: l10n.walletSentDetail(amount, tokenSymbol, displayAddress),
        primaryAction: Button(
          label: l10n.walletDone,
          variant: ButtonVariant.primary,
          onTap: () => context.go('/home'),
        ),
      ),
    );
  }
}
