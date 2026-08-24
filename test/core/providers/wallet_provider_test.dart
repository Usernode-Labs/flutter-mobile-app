import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/providers/wallet_provider.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/wallet.dart';

RpcWalletBalanceResp balanceResponse({
  required bool tracked,
  BigInt? total,
}) {
  final baseTotal = total ?? BigInt.zero;
  return RpcWalletBalanceResp(
    tracked: tracked,
    baseTotal: baseTotal,
    baseUtxos: BigInt.zero,
    baseLargestUtxo: BigInt.zero,
    baseAvailable: baseTotal,
    baseAvailableUtxos: BigInt.zero,
    baseLargestAvailableUtxo: baseTotal,
    basePendingSpent: BigInt.zero,
    basePendingSpentUtxos: BigInt.zero,
  );
}

void main() {
  test('untracked local wallet response is unavailable, not zero', () {
    expect(
      () => walletBalanceFromLocalResponse(
        balanceResponse(tracked: false),
      ),
      throwsA(isA<WalletBalanceUnavailable>()),
    );
  });

  test('missing local wallet response is unavailable, not zero', () {
    expect(
      () => walletBalanceFromLocalResponse(null),
      throwsA(isA<WalletBalanceUnavailable>()),
    );
  });

  test('tracked local wallet response preserves its base-unit balance', () {
    final balance = walletBalanceFromLocalResponse(
      balanceResponse(tracked: true, total: BigInt.from(1000000000)),
    );

    expect(balance.totalBalance, BigInt.from(1000000000));
    expect(balance.tokenAmount, 1000000000);
    expect(balance.tokenSymbol, 'TKN');
  });

  test('tracked zero remains a legitimate zero balance', () {
    final balance = walletBalanceFromLocalResponse(
      balanceResponse(tracked: true),
    );

    expect(balance.totalBalance, BigInt.zero);
  });
}
