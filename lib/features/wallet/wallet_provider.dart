import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/features/wallet/models/transaction_model.dart';

class WalletState {
  final WalletBalance balance;
  final List<TransactionModel> recent;

  const WalletState({required this.balance, required this.recent});
}

class WalletController extends AsyncNotifier<WalletState> {
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
      tokenSymbol: AppConfig.defaultTokenSymbol,
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
      tokenSymbol: AppConfig.defaultTokenSymbol,
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
      tokenSymbol: AppConfig.defaultTokenSymbol,
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
      tokenSymbol: AppConfig.defaultTokenSymbol,
      type: TransactionType.fee,
      status: TransactionStatus.pending,
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      icon: Icons.schedule,
      color: Colors.orange,
    ),
  ];

  @override
  Future<WalletState> build() async {
    return WalletState(
      balance: _balance,
      recent: _transactions.take(10).toList(),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Simulate small balance update
    _balance = _balance.copyWith(
      tokenAmount: _balance.tokenAmount + 0.01,
    );

    state = AsyncValue.data(WalletState(
      balance: _balance,
      recent: _transactions.take(10).toList(),
    ));
  }
}

final walletProvider = AsyncNotifierProvider<WalletController, WalletState>(
  WalletController.new,
);
