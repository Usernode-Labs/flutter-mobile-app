import 'dart:convert';

/// Model for locally stored pending transactions
/// Used to associate sent amounts with pending transaction hashes
class PendingTransaction {
  final String fromAddress;
  final String toAddress;
  final double amount;
  final DateTime timestamp;
  final String? memo;

  const PendingTransaction({
    required this.fromAddress,
    required this.toAddress,
    required this.amount,
    required this.timestamp,
    this.memo,
  });

  /// Create from JSON map
  factory PendingTransaction.fromJson(Map<String, dynamic> json) {
    return PendingTransaction(
      fromAddress: json['fromAddress'] as String,
      toAddress: json['toAddress'] as String,
      amount: json['amount'] as double,
      timestamp: DateTime.parse(json['timestamp'] as String),
      memo: json['memo'] as String?,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      if (memo != null) 'memo': memo,
    };
  }

  /// Convert to JSON string for storage
  String toJsonString() => jsonEncode(toJson());

  /// Create from JSON string
  factory PendingTransaction.fromJsonString(String jsonString) {
    return PendingTransaction.fromJson(jsonDecode(jsonString));
  }

  /// Check if this pending transaction matches a mempool transaction
  /// Uses timestamp proximity and amount matching
  bool matches({
    required String? txFromAddress,
    required String? txToAddress,
    required DateTime txTimestamp,
    Duration timestampTolerance = const Duration(minutes: 10),
  }) {
    // Check timestamp proximity (within 10 minutes)
    final timeDiff = txTimestamp.difference(timestamp).abs();
    if (timeDiff > timestampTolerance) return false;

    // Check address matching if available
    if (txFromAddress != null && txFromAddress != fromAddress) return false;
    if (txToAddress != null && txToAddress != toAddress) return false;

    return true;
  }

  /// Check if this pending transaction is too old to be relevant
  bool isExpired({Duration maxAge = const Duration(hours: 24)}) {
    return DateTime.now().difference(timestamp) > maxAge;
  }

  /// Get a unique key for storage
  String get storageKey {
    // Use timestamp + amount + first 8 chars of toAddress for uniqueness
    final timestampKey = timestamp.millisecondsSinceEpoch.toString();
    final amountKey = amount.toStringAsFixed(2);
    final addressKey = toAddress.length >= 8 ? toAddress.substring(0, 8) : toAddress;
    return '${timestampKey}_${amountKey}_$addressKey';
  }

  @override
  String toString() {
    return 'PendingTransaction(from: ${_shortenAddress(fromAddress)}, '
        'to: ${_shortenAddress(toAddress)}, amount: $amount, timestamp: $timestamp)';
  }

  String _shortenAddress(String address) {
    if (address.length <= 16) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingTransaction &&
          runtimeType == other.runtimeType &&
          fromAddress == other.fromAddress &&
          toAddress == other.toAddress &&
          amount == other.amount &&
          timestamp == other.timestamp &&
          memo == other.memo;

  @override
  int get hashCode =>
      fromAddress.hashCode ^
      toAddress.hashCode ^
      amount.hashCode ^
      timestamp.hashCode ^
      memo.hashCode;
}