import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import '../../theme/app_theme.dart';

class WalletBalanceCard extends StatelessWidget {
  final WalletBalance balance;
  final VoidCallback onVisibilityToggle;

  const WalletBalanceCard({
    Key? key,
    required this.balance,
    required this.onVisibilityToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Balance',
                  style: AppTheme.nodeSubtitleStyle,
                ),
                GestureDetector(
                  onTap: onVisibilityToggle,
                  child: Icon(
                    balance.isVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppTheme.nodeIconColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              balance.isVisible ? balance.formattedTokenAmount : '••••••',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              balance.isVisible ? balance.formattedUsdValue : '••••••',
              style: AppTheme.nodeSubtitleStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const QuickActionButton({
    Key? key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTheme.nodeStatusStyle.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickActionsRow extends StatelessWidget {
  final VoidCallback onSendTap;
  final VoidCallback onReceiveTap;
  final bool showSend;
  final bool showReceive;

  const QuickActionsRow({
    Key? key,
    required this.onSendTap,
    required this.onReceiveTap,
    this.showSend = true,
    this.showReceive = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final children = <Widget>[];
    if (showSend) {
      children.add(
        Expanded(
          child: QuickActionButton(
            label: 'Send',
            icon: Icons.arrow_upward,
            color: theme.colorScheme.primary,
            onTap: onSendTap,
          ),
        ),
      );
    }
    if (showSend && showReceive) {
      children.add(const SizedBox(width: 12));
    }
    if (showReceive) {
      children.add(
        Expanded(
          child: QuickActionButton(
            label: 'Receive',
            icon: Icons.arrow_downward,
            color: AppTheme.successCheckColor,
            onTap: onReceiveTap,
          ),
        ),
      );
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Row(children: children);
  }
}

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionTile({
    Key? key,
    required this.transaction,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: transaction.color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            transaction.icon,
            color: transaction.color,
            size: 20,
          ),
        ),
        title: Text(
          transaction.title,
          style: AppTheme.activityTitleStyle,
        ),
        subtitle: Text(
          transaction.fullSubtitle,
          style: AppTheme.activitySubtitleStyle,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              transaction.formattedAmount,
              style: AppTheme.nodeStatusStyle.copyWith(
                color: transaction.isPositive
                    ? AppTheme.successCheckColor
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              transaction.currency,
              style: AppTheme.nodeSubtitleStyle.copyWith(
                fontSize: 10,
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class TransactionsList extends StatelessWidget {
  final List<TransactionModel> transactions;
  final Function(TransactionModel)? onTransactionTap;

  const TransactionsList({
    Key? key,
    required this.transactions,
    this.onTransactionTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: AppTheme.nodeIconColor,
              ),
              SizedBox(height: 16),
              Text(
                'No transactions yet',
                style: AppTheme.nodeStatusStyle,
              ),
              SizedBox(height: 8),
              Text(
                'Your transaction history will appear here',
                style: AppTheme.nodeSubtitleStyle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: transactions
          .map((transaction) => TransactionTile(
                transaction: transaction,
                onTap: onTransactionTap != null
                    ? () => onTransactionTap!(transaction)
                    : null,
              ))
          .toList(),
    );
  }
}
