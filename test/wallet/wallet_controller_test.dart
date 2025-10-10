import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:crypto_mobile_app/features/wallet/domain/entities/wallet_balance.dart';
import 'package:crypto_mobile_app/features/wallet/domain/entities/transaction.dart'
    as domain;
import 'package:crypto_mobile_app/features/wallet/presentation/controllers/wallet_controller.dart';
import 'package:crypto_mobile_app/core/di/providers.dart';

class _FakeWalletRepo implements WalletRepository {
  @override
  Future<WalletBalanceEntity> getBalance() async =>
      const WalletBalanceEntity(tokenAmount: 42.0, tokenSymbol: 'TOK', usdValue: 84.0);

  @override
  Future<List<domain.Transaction>> getRecentTransactions({int limit = 10}) async => [
        domain.Transaction(
          id: 't1',
          title: 'test',
          subtitle: '',
          amount: 1.0,
          currency: 'TOK',
          type: domain.TxType.receive,
          status: domain.TxStatus.completed,
          timestamp: DateTime(2024, 1, 1),
        ),
      ];

  @override
  Future<void> refresh() async {}
}

void main() {
  test('walletProvider loads balance and txs', () async {
    final container = ProviderContainer(overrides: [
      walletRepositoryProvider.overrideWithValue(_FakeWalletRepo()),
    ]);
    addTearDown(container.dispose);

    final state = await container.read(walletProvider.future);
    expect(state.balance.tokenAmount, 42.0);
    expect(state.balance.tokenSymbol, 'TOK');
    expect(state.recent, isNotEmpty);
  });
}

