import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/transaction_model.dart';
import '../../theme/app_theme.dart';
import '../../gen_l10n/app_localizations.dart';

class WalletBalanceCard extends StatefulWidget {
  final WalletBalance balance;
  final String? address;
  final String? publicKey; // Ignored in UI (hidden)
  final VoidCallback? onManageAccounts;
  final String? accountName;
  final List<TokenHolding> holdings;

  const WalletBalanceCard({
    Key? key,
    required this.balance,
    required this.holdings,
    this.address,
    this.publicKey,
    this.onManageAccounts,
    this.accountName,
  }) : super(key: key);

  @override
  State<WalletBalanceCard> createState() => _WalletBalanceCardState();
}

class _WalletBalanceCardState extends State<WalletBalanceCard> {
  String _shortAddress(String addr) {
    if (addr.length <= 12) return addr;
    final start = addr.substring(0, 6);
    final end = addr.substring(addr.length - 4);
    return '$start…$end';
  }

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label copied')));
  }

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
                                  theme.colorScheme.primary.withOpacity(0.08),
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
  final VoidCallback? onBridgeTap;
  final bool showSend;
  final bool showReceive;
  final bool showBridge;

  const QuickActionsRow({
    Key? key,
    required this.onSendTap,
    required this.onReceiveTap,
    this.onBridgeTap,
    this.showSend = true,
    this.showReceive = true,
    this.showBridge = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final children = <Widget>[];
    void addButton(Widget w) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 12));
      children.add(Expanded(child: w));
    }

    if (showSend) {
      addButton(FilledButton.icon(
        onPressed: onSendTap,
        icon: const Icon(Icons.arrow_upward),
        label: Text(AppLocalizations.of(context).send),
      ));
    }
    if (showReceive) {
      addButton(OutlinedButton.icon(
        onPressed: onReceiveTap,
        icon: const Icon(Icons.arrow_downward),
        label: Text(AppLocalizations.of(context).receive),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
        ),
      ));
    }
    if (showBridge && onBridgeTap != null) {
      addButton(OutlinedButton.icon(
        onPressed: onBridgeTap,
        icon: const Icon(Icons.swap_horiz),
        label: Text(AppLocalizations.of(context).bridge),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
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
