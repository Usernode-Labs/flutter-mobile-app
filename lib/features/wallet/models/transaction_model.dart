import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/core/services/explorer_service.dart';

enum TransactionType {
  receive,
  send,
  reward,
  genesis,
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
  final DataSource dataSource;

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
    this.dataSource = DataSource.local,
  });

  bool get isPositive => amount > 0;

  String get formattedAmount {
    final prefix = isPositive ? '+' : '';
    final formatter = NumberFormat('#,##0', 'en_US');
    return '$prefix${formatter.format(amount)}';
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

  /// Format timestamp in ISO format: YYYY-MM-DD HH:MM:SS
  String get formattedTimestamp {
    final year = timestamp.year.toString();
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute:$second';
  }

  String get fullSubtitle => shortHash;

  /// Get shortened transaction hash for display
  String get shortHash {
    if (id.length <= 16) return id;
    return '${id.substring(0, 8)}...${id.substring(id.length - 8)}';
  }

  /// Create TransactionModel from ExplorerTransaction
  factory TransactionModel.fromExplorerTransaction(
    ExplorerTransaction explorerTx,
    DataSource dataSource,
    String userAddress,
  ) {
    // Determine transaction type using new structured API fields
    TransactionType txType;
    bool isOutgoing = false;

    switch (explorerTx.txType.toLowerCase()) {
      case 'reward':
        txType = TransactionType.reward;
        break;
      case 'genesis':
        txType = TransactionType.genesis;
        break;
      case 'transfer':
      default:
        // Use direction field to determine if outgoing or incoming
        if (explorerTx.direction.toLowerCase() == 'out') {
          txType = TransactionType.send;
          isOutgoing = true;
        } else {
          txType = TransactionType.receive;
        }
        break;
    }

    // Determine title and icon
    String title;
    IconData icon;
    Color color;

    switch (txType) {
      case TransactionType.reward:
        title = 'Block Reward';
        icon = Symbols.layers_sharp;
        color = Colors.orange;
        break;
      case TransactionType.genesis:
        title = 'Genesis Allocation';
        icon = Symbols.diamond_sharp;
        color = Colors.orange;
        break;
      case TransactionType.send:
        title = 'Sent';
        icon = Symbols.north_east_sharp;
        color = Colors.grey;
        break;
      case TransactionType.receive:
        title = 'Received';
        icon = Symbols.south_west_sharp;
        color = Colors.grey;
        break;
      case TransactionType.fee:
        title = 'Fee';
        icon = Symbols.payment_sharp;
        color = Colors.grey;
        break;
    }

    // Create subtitle based on transaction type and available data
    String subtitle;
    switch (explorerTx.txType.toLowerCase()) {
      case 'reward':
        subtitle = 'Block ${explorerTx.blockHeight ?? '?'}';
        break;
      case 'genesis':
        subtitle = 'Initial distribution';
        break;
      case 'transfer':
      default:
        if (isOutgoing && explorerTx.toAddress != null) {
          subtitle = 'To: ${_shortenAddress(explorerTx.toAddress!)}';
        } else if (!isOutgoing && explorerTx.fromAddress != null) {
          subtitle = 'From: ${_shortenAddress(explorerTx.fromAddress!)}';
        } else {
          subtitle =
              explorerTx.txType.isNotEmpty ? explorerTx.txType : 'Transaction';
        }
        break;
    }

    return TransactionModel(
      id: explorerTx.id,
      title: title,
      subtitle: subtitle,
      amount: isOutgoing ? -explorerTx.amount.abs() : explorerTx.amount.abs(),
      tokenSymbol: explorerTx.tokenSymbol,
      type: txType,
      status: _parseTransactionStatus(explorerTx.status),
      timestamp: explorerTx.timestamp,
      icon: icon,
      color: color,
      dataSource: dataSource,
    );
  }

  static String _shortenAddress(String address) {
    if (address.length <= 16) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
  }

  static TransactionStatus _parseTransactionStatus(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'success':
      case 'completed':
        return TransactionStatus.completed;
      case 'pending':
      case 'unconfirmed':
        return TransactionStatus.pending;
      case 'failed':
      case 'error':
        return TransactionStatus.failed;
      default:
        return TransactionStatus.completed;
    }
  }
}

class WalletBalance {
  final double tokenAmount;
  final String tokenSymbol;
  final double usdValue;
  final BigInt totalBalance; // Total balance from all UTXOs
  final DataSource dataSource;
  final DateTime? lastUpdated;

  WalletBalance({
    required this.tokenAmount,
    required this.tokenSymbol,
    required this.usdValue,
    required this.totalBalance,
    this.dataSource = DataSource.local,
    this.lastUpdated,
  });

  String get formattedTokenAmount =>
      '${tokenAmount.toStringAsFixed(2)} $tokenSymbol';
  String get formattedUsdValue => '≈ \$${usdValue.toStringAsFixed(2)} USD';

  /// Get formatted balance with support for compact and full formatting
  ///
  /// [compact] - Use compact format (1.2M, 5.6K) vs full format (1,234,567)
  /// [decimals] - Number of decimal places to show
  String getFormattedBalance({bool compact = false, int decimals = 1}) {
    if (compact) {
      return _formatCompact(tokenAmount, decimals);
    } else {
      // For full format with comma separators
      String pattern;
      if (decimals == 0) {
        pattern = '#,##0';
      } else {
        pattern = '#,##0.${'#' * decimals}';
      }
      final formatter = NumberFormat(pattern, 'en_US');
      return formatter.format(tokenAmount);
    }
  }

  /// Format number in compact notation (K, M, B)
  String _formatCompact(double value, int decimals) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(decimals)}B';
    } else if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(decimals)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(decimals)}K';
    } else {
      return value.toStringAsFixed(decimals);
    }
  }

  WalletBalance copyWith({
    double? tokenAmount,
    String? tokenSymbol,
    double? usdValue,
    BigInt? totalBalance,
    DataSource? dataSource,
    DateTime? lastUpdated,
  }) {
    return WalletBalance(
      tokenAmount: tokenAmount ?? this.tokenAmount,
      tokenSymbol: tokenSymbol ?? this.tokenSymbol,
      usdValue: usdValue ?? this.usdValue,
      totalBalance: totalBalance ?? this.totalBalance,
      dataSource: dataSource ?? this.dataSource,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Create WalletBalance from ExplorerBalanceResponse
  factory WalletBalance.fromExplorerBalance(ExplorerBalanceResponse response) {
    return WalletBalance(
      tokenAmount: response.balance,
      tokenSymbol: response.tokenSymbol,
      usdValue: 0.0, // TODO: Add USD conversion
      totalBalance: BigInt.from(response.balance.toInt()),
      dataSource: response.dataSource,
      lastUpdated: response.fetchedAt,
    );
  }

  /// Get data source display text
  String get dataSourceText {
    switch (dataSource) {
      case DataSource.explorerPrimary:
        return 'Live (Primary)';
      case DataSource.explorerSecondary:
        return 'Live (Secondary)';
      case DataSource.cached:
        return 'Cached';
      case DataSource.local:
        return 'Local';
    }
  }

  /// Check if data is from a live explorer API
  bool get isLiveData =>
      dataSource == DataSource.explorerPrimary ||
      dataSource == DataSource.explorerSecondary;

  /// Get time ago text for last update
  String get lastUpdatedText {
    if (lastUpdated == null) return '';

    final now = DateTime.now();
    final isToday = now.day == lastUpdated!.day &&
        now.month == lastUpdated!.month &&
        now.year == lastUpdated!.year;

    if (isToday) {
      // Format as time with seconds: 14:32:45
      final hour = lastUpdated!.hour;
      final minute = lastUpdated!.minute.toString().padLeft(2, '0');
      final second = lastUpdated!.second.toString().padLeft(2, '0');

      // Use 24-hour format with seconds
      return '$hour:$minute:$second';
    } else {
      // For dates not today, show the date
      final month = lastUpdated!.month.toString().padLeft(2, '0');
      final day = lastUpdated!.day.toString().padLeft(2, '0');
      return '$month/$day';
    }
  }
}
