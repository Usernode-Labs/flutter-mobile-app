import 'package:flutter/material.dart';

enum TransactionType {
  receive,
  send,
  reward,
  fee,
}

enum TransactionStatus {
  completed,
  pending,
  failed,
}

class TransactionModel {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final String tokenSymbol;
  final TransactionType type;
  final TransactionStatus status;
  final DateTime timestamp;
  final IconData icon;
  final Color color;

  TransactionModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.tokenSymbol,
    required this.type,
    required this.status,
    required this.timestamp,
    required this.icon,
    required this.color,
  });

  bool get isPositive => amount > 0;

  String get formattedAmount {
    final prefix = isPositive ? '+' : '';
    return '$prefix${amount.toStringAsFixed(2)}';
  }

  String get statusText {
    switch (status) {
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.failed:
        return 'Failed';
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  String get fullSubtitle => '$statusText • $timeAgo';
}

class WalletBalance {
  final double tokenAmount;
  final String tokenSymbol;
  final double usdValue;

  WalletBalance({
    required this.tokenAmount,
    required this.tokenSymbol,
    required this.usdValue,
  });

  String get formattedTokenAmount =>
      '${tokenAmount.toStringAsFixed(2)} $tokenSymbol';
  String get formattedUsdValue => '≈ \$${usdValue.toStringAsFixed(2)} USD';

  WalletBalance copyWith({
    double? tokenAmount,
    String? tokenSymbol,
    double? usdValue,
  }) {
    return WalletBalance(
      tokenAmount: tokenAmount ?? this.tokenAmount,
      tokenSymbol: tokenSymbol ?? this.tokenSymbol,
      usdValue: usdValue ?? this.usdValue,
    );
  }
}
