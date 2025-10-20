import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/wallet/domain/entities/wallet_balance.dart';
import 'package:crypto_mobile_app/features/wallet/domain/entities/transaction.dart'
    as domain;
import 'package:crypto_mobile_app/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';

class WalletState {
  final WalletBalanceEntity balance;
  final List<domain.Transaction> recent;

  const WalletState({required this.balance, required this.recent});
}

class WalletController extends AsyncNotifier<WalletState> {
  late final WalletRepository _repo;

  @override
  Future<WalletState> build() async {
    _repo = ref.read(walletRepositoryProvider);
    final balance = await _repo.getBalance();
    final txs = await _repo.getRecentTransactions(limit: 10);
    return WalletState(balance: balance, recent: txs);
  }

  Future<void> refresh() async {
    await _repo.refresh();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final balance = await _repo.getBalance();
      final txs = await _repo.getRecentTransactions(limit: 10);
      return WalletState(balance: balance, recent: txs);
    });
  }
}

final walletProvider = AsyncNotifierProvider<WalletController, WalletState>(
  WalletController.new,
);

