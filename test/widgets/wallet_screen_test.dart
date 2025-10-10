import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/controllers/wallet_controller.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/controllers/utxo_provider.dart';
import 'package:crypto_mobile_app/features/wallet/domain/entities/wallet_balance.dart';
import 'package:crypto_mobile_app/features/wallet/domain/entities/transaction.dart' as domain;
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_utxos_by_owner.dart';

void main() {
  testWidgets('WalletScreen renders with provider overrides', (tester) async {
    final container = ProviderContainer(overrides: [
      walletProvider.overrideWith(() => _FakeWalletController()),
      walletUtxosProvider.overrideWith(() => _FakeUtxosController()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WalletScreen()),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
  });
}

class _FakeWalletController extends WalletController {
  @override
  Future<WalletState> build() async {
    return WalletState(
      balance: const WalletBalanceEntity(tokenAmount: 10, tokenSymbol: 'TOK', usdValue: 20),
      recent: [
        domain.Transaction(
          id: '1',
          title: 'Mock',
          subtitle: '',
          amount: 1,
          currency: 'TOK',
          type: domain.TxType.receive,
          status: domain.TxStatus.completed,
          timestamp: DateTime(2024, 1, 1),
        ),
      ],
    );
  }
}

class _FakeUtxosController extends WalletUtxosController {
  @override
  Future<List<OwnedUtxo>> build() => Future.value(const <OwnedUtxo>[]);
}
