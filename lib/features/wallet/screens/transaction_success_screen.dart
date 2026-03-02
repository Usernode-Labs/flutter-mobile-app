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
    final displayAddress = recipientAddress.length > 16
        ? '${recipientAddress.substring(0, 8)}..${recipientAddress.substring(recipientAddress.length - 8)}'
        : recipientAddress;

    return Scaffold(
      body: ResultPage(
        variant: ResultPageVariant.success,
        title: 'Sent successfully!',
        subtitle: '$amount $tokenSymbol sent to\n$displayAddress',
        primaryAction: FilledButton(
          onPressed: () => context.go('/home'),
          child: const Text('Done'),
        ),
      ),
    );
  }
}
