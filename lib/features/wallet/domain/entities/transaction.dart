// Domain entity for a wallet transaction (UI-agnostic)

enum TxType { receive, send, reward, fee }

enum TxStatus { completed, pending, failed }

class Transaction {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final String currency;
  final TxType type;
  final TxStatus status;
  final DateTime timestamp;

  const Transaction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.currency,
    required this.type,
    required this.status,
    required this.timestamp,
  });

  bool get isPositive => amount > 0;
}
