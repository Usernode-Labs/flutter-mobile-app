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
    final theme = Theme.of(context);
    
    // Format the recipient address to show first 8 and last 8 characters
    final displayAddress = recipientAddress.length > 16
        ? '${recipientAddress.substring(0, 8)}..${recipientAddress.substring(recipientAddress.length - 8)}'
        : recipientAddress;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              
              // Success title
              Text(
                'Sent successfully!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Transaction details
              Text(
                '$amount $tokenSymbol sent to',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                displayAddress,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              
              const Spacer(flex: 1),
              
              // Success checkmark circle
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.check,
                    size: 60,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
              
              const Spacer(flex: 2),
              
              // Done button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate back to wallet screen
                    context.go('/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}