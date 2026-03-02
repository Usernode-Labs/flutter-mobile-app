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
    return Scaffold(
      body: ResultPage(
        variant: ResultPageVariant.failure,
        title: 'Transaction Failed',
        subtitle: errorMessage.isNotEmpty
            ? errorMessage
            : 'An error occurred while processing your transaction',
        primaryAction: FilledButton(
          onPressed: () => context.pop(),
          child: const Text('Got it'),
        ),
      ),
    );
  }
}
