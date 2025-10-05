import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/features/wallet/data/models/transaction_model.dart';
 

class WalletService {
  static WalletService? _instance;
  static WalletService get instance {
    _instance ??= WalletService._();
    return _instance!;
  }

  WalletService._();

  // Mock wallet balance
  WalletBalance _balance = WalletBalance(
    tokenAmount: 1234.56,
    tokenSymbol: 'TOKENS',
    usdValue: 2469.12,
  );

  // Mock transaction data
  final List<TransactionModel> _transactions = [
    TransactionModel(
      id: '1',
      title: 'Received from Network',
      subtitle: '',
      amount: 150.00,
      currency: 'TOKENS',
      type: TransactionType.receive,
      status: TransactionStatus.completed,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      icon: Icons.arrow_downward,
      color: Colors.green,
    ),
    TransactionModel(
      id: '2',
      title: 'Node Rewards',
      subtitle: '',
      amount: 25.50,
      currency: 'TOKENS',
      type: TransactionType.reward,
      status: TransactionStatus.completed,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      icon: Icons.hub,
      color: Colors.green,
    ),
    TransactionModel(
      id: '3',
      title: 'Send to Wallet',
      subtitle: '',
      amount: -100.00,
      currency: 'TOKENS',
      type: TransactionType.send,
      status: TransactionStatus.completed,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      icon: Icons.arrow_upward,
      color: Colors.blue,
    ),
    TransactionModel(
      id: '4',
      title: 'Network Fee',
      subtitle: '',
      amount: -2.50,
      currency: 'TOKENS',
      type: TransactionType.fee,
      status: TransactionStatus.pending,
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      icon: Icons.schedule,
      color: Colors.orange,
    ),
  ];

  // Get wallet balance
  WalletBalance getBalance() {
    return _balance;
  }

  // Balance is always visible; toggle removed.

  // Get recent transactions
  List<TransactionModel> getRecentTransactions({int limit = 10}) {
    return _transactions.take(limit).toList();
  }

  // Refresh wallet data (mock implementation)
  Future<void> refreshWalletData() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // In a real app, this would fetch fresh data from the blockchain/API
    // For now, we'll just simulate a small balance update
    _balance = _balance.copyWith(
      tokenAmount: _balance.tokenAmount + 0.01, // Small reward simulation
    );
  }
}
