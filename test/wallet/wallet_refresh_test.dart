import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:crypto_mobile_app/features/wallet/domain/entities/wallet_balance.dart';
import 'package:crypto_mobile_app/features/wallet/domain/entities/transaction.dart' as domain;
import 'package:crypto_mobile_app/core/di/providers.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/controllers/wallet_controller.dart';

class _MutableWalletRepo implements WalletRepository {
  double tokens = 1.0;

  @override
  Future<WalletBalanceEntity> getBalance() async =>
      WalletBalanceEntity(tokenAmount: tokens, tokenSymbol: 'TOK', usdValue: tokens * 2);

  @override
  Future<List<domain.Transaction>> getRecentTransactions({int limit = 10}) async => const [];

  @override
  Future<void> refresh() async {
    tokens += 1.0;
  }
}

void main() {
  test('walletProvider refresh updates balance', () async {
    final repo = _MutableWalletRepo();
    final container = ProviderContainer(overrides: [
      walletRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    var state = await container.read(walletProvider.future);
    expect(state.balance.tokenAmount, 1.0);

    await container.read(walletProvider.notifier).refresh();
    state = await container.read(walletProvider.future);
    expect(state.balance.tokenAmount, 2.0);
  });
}

