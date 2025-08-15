import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../../theme/app_theme.dart';

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
      color: AppTheme.successCheckColor,
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
      color: AppTheme.successCheckColor,
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
      color: AppTheme.multiplierColor,
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
      color: AppTheme.pendingIconColor,
    ),
  ];

  // Get wallet balance
  WalletBalance getBalance() {
    return _balance;
  }

  // Toggle balance visibility
  WalletBalance toggleBalanceVisibility() {
    _balance = _balance.copyWith(isVisible: !_balance.isVisible);
    return _balance;
  }

  // Get recent transactions
  List<TransactionModel> getRecentTransactions({int limit = 10}) {
    return _transactions.take(limit).toList();
  }

  // Get transaction by ID
  TransactionModel? getTransactionById(String id) {
    try {
      return _transactions.firstWhere((tx) => tx.id == id);
    } catch (e) {
      return null;
    }
  }

  // Send tokens (mock implementation)
  Future<bool> sendTokens({
    required String toAddress,
    required double amount,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Mock validation
    if (amount <= 0 || amount > _balance.tokenAmount) {
      return false;
    }

    // Create new transaction
    final transaction = TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Send to $toAddress',
      subtitle: '',
      amount: -amount,
      currency: 'TOKENS',
      type: TransactionType.send,
      status: TransactionStatus.pending,
      timestamp: DateTime.now(),
      icon: Icons.arrow_upward,
      color: AppTheme.multiplierColor,
    );

    // Add to transactions list
    _transactions.insert(0, transaction);

    // Update balance
    _balance = _balance.copyWith(
      tokenAmount: _balance.tokenAmount - amount,
    );

    return true;
  }

  // Generate receive address (mock implementation)
  Future<String> generateReceiveAddress() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Return mock address
    return '0x1234567890abcdef1234567890abcdef12345678';
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
