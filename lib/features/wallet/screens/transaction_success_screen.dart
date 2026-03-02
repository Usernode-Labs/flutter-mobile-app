import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

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
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);

    // Format the recipient address to show first 8 and last 8 characters
    final displayAddress = recipientAddress.length > 16
        ? '${recipientAddress.substring(0, 8)}..${recipientAddress.substring(recipientAddress.length - 8)}'
        : recipientAddress;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.space24),
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

              SizedBox(height: spacing.space24),

              // Transaction details
              Text(
                '$amount $tokenSymbol sent to',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: spacing.space8),

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
                    Symbols.check_sharp,
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

              SizedBox(height: spacing.space24),
            ],
          ),
        ),
      ),
    );
  }
}
