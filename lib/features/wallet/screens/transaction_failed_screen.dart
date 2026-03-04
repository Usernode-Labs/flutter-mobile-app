import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TransactionFailedScreen extends StatelessWidget {
  final String errorMessage;

  const TransactionFailedScreen({
    super.key,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: ResultPage(
        variant: ResultPageVariant.failure,
        title: l10n.walletTransactionFailed,
        subtitle: errorMessage.isNotEmpty
            ? errorMessage
            : l10n.walletTransactionFailedGeneric,
        primaryAction: FilledButton(
          onPressed: () => context.pop(),
          child: Text(l10n.commonGotIt),
        ),
      ),
    );
  }
}
