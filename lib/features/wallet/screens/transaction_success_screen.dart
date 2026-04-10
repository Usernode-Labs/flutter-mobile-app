import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/utils/utils.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/wallet_tx.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TransactionSuccessScreen extends StatelessWidget {
  final String amount;
  final String tokenSymbol;
  final String recipientAddress;
  final String? txId;
  final RpcWalletTxProofStats? proofStats;

  const TransactionSuccessScreen({
    super.key,
    required this.amount,
    required this.tokenSymbol,
    required this.recipientAddress,
    this.txId,
    this.proofStats,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayAddress = Utils.shortenID(recipientAddress, head: 8, tail: 8);
    final subtitle = StringBuffer(
      l10n.walletSentDetail(amount, tokenSymbol, displayAddress),
    );
    if (proofStats != null) {
      subtitle
        ..write('\n\n')
        ..write(
          '${l10n.walletProofTimeLabel}: ${proofStats!.durationMs} ms',
        )
        ..write('\n')
        ..write(
          '${l10n.walletTotalInputsLabel}: ${proofStats!.inputCount}',
        )
        ..write('\n')
        ..write(
          '${l10n.walletDefragInputsLabel}: ${proofStats!.extraInputCount}',
        );
    }
    if (txId case final txId?) {
      subtitle
        ..write('\n')
        ..write('${l10n.walletTransactionIdLabel}: ')
        ..write(Utils.shortenID(txId, head: 10, tail: 8));
    }

    return Scaffold(
      body: ResultPage(
        variant: ResultPageVariant.success,
        title: l10n.walletSentSuccessfully,
        subtitle: subtitle.toString(),
        primaryAction: Button(
          label: l10n.walletDone,
          variant: ButtonVariant.primary,
          onTap: () => context.go('/home'),
        ),
      ),
    );
  }
}
