import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
 
import '../../gen_l10n/app_localizations.dart';

class WalletBalanceCard extends StatefulWidget {
  final WalletBalance balance;
  final String? address;
  final String? publicKey; // Ignored in UI (hidden)
  final VoidCallback? onManageAccounts;
  final String? accountName;
  final List<TokenHolding> holdings;

  const WalletBalanceCard({
    super.key,
    required this.balance,
    required this.holdings,
    this.address,
    this.publicKey,
    this.onManageAccounts,
    this.accountName,
  });

  @override
  State<WalletBalanceCard> createState() => _WalletBalanceCardState();
}

class _WalletBalanceCardState extends State<WalletBalanceCard> {

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      color: theme.scaffoldBackgroundColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      child: Stack(
        children: [
          // Background reference image with soft overlay
          if (widget.address != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account header removed; shown separately in Wallet screen
                  const SizedBox(height: 4),
                  // Token holdings list (limit 2) with transparent tiles
                  ListTileTheme(
                    data: const ListTileThemeData(
                      tileColor: Colors.transparent,
                      selectedTileColor: Colors.transparent,
                    ),
                    child: Column(
                      children: [
                        for (final h in widget.holdings.take(2))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  theme.colorScheme.primary.withValues(alpha: 0.08),
                              foregroundColor: theme.colorScheme.primary,
                              child: Icon(h.icon, size: 18),
                            ),
                            title: Text(
                              h.name,
                              style: theme.textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  h.formattedAmount,
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  h.formattedUsd,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Details section removed per request
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class TokenHolding {
  final String name;
  final String symbol;
  final double amount;
  final double usdValue;
  final IconData icon;

  TokenHolding({
    required this.name,
    required this.symbol,
    required this.amount,
    required this.usdValue,
    this.icon = Icons.token_outlined,
  });

  String get formattedAmount => '${amount.toStringAsFixed(2)} $symbol';
  String get formattedUsd => '≈ \$${usdValue.toStringAsFixed(2)}';
}

class QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const QuickActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

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
          color: color.withValues(alpha: 0.1),
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
  final VoidCallback? onBridgeTap;
  final bool showSend;
  final bool showReceive;
  final bool showBridge;

  const QuickActionsRow({
    super.key,
    required this.onSendTap,
    required this.onReceiveTap,
    this.onBridgeTap,
    this.showSend = true,
    this.showReceive = true,
    this.showBridge = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final children = <Widget>[];
    void addButton(Widget w) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 12));
      children.add(Expanded(child: w));
    }

    if (showSend) {
      addButton(Container(
        height: 56,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(28),
        ),
        child: InkWell(
          onTap: onSendTap,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: Text(
              AppLocalizations.of(context).send,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ));
    }
    if (showReceive) {
      addButton(Container(
        height: 56,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(28),
        ),
        child: InkWell(
          onTap: onReceiveTap,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: Text(
              AppLocalizations.of(context).receive,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ));
    }
    if (showBridge && onBridgeTap != null) {
      addButton(Container(
        height: 56,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(28),
        ),
        child: InkWell(
          onTap: onBridgeTap,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: Text(
              AppLocalizations.of(context).bridge,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Row(children: children);
  }
}

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

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
            color: transaction.color.withValues(alpha: 0.1),
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
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          transaction.fullSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              transaction.formattedAmount,
              style: theme.textTheme.titleMedium?.copyWith(
                color: transaction.isPositive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              transaction.currency,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
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
    super.key,
    required this.transactions,
    this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No transactions yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Your transaction history will appear here',
                style: Theme.of(context).textTheme.bodySmall,
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
