import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncStallDetector', () {
    test('flags unchanged sync progress after the 60 second floor', () {
      final detector = SyncStallDetector();

      expect(
        detector.update(
          syncing: true,
          blockIntervalMs: 10000,
          elapsedMs: 0,
          localBestHeight: 100,
          fetchedBlocks: BigInt.from(20),
          appliedBlocks: BigInt.from(10),
        ),
        isFalse,
      );
      expect(
        detector.update(
          syncing: true,
          blockIntervalMs: 10000,
          elapsedMs: 59999,
          localBestHeight: 100,
          fetchedBlocks: BigInt.from(20),
          appliedBlocks: BigInt.from(10),
        ),
        isFalse,
      );
      expect(
        detector.update(
          syncing: true,
          blockIntervalMs: 10000,
          elapsedMs: 60000,
          localBestHeight: 100,
          fetchedBlocks: BigInt.from(20),
          appliedBlocks: BigInt.from(10),
        ),
        isTrue,
      );
    });

    test('uses three block intervals when that is longer', () {
      final detector = SyncStallDetector();
      detector.update(
        syncing: true,
        blockIntervalMs: 30000,
        elapsedMs: 1000,
        localBestHeight: 100,
        fetchedBlocks: BigInt.from(20),
        appliedBlocks: BigInt.from(10),
      );

      expect(
        detector.update(
          syncing: true,
          blockIntervalMs: 30000,
          elapsedMs: 90999,
          localBestHeight: 100,
          fetchedBlocks: BigInt.from(20),
          appliedBlocks: BigInt.from(10),
        ),
        isFalse,
      );
      expect(
        detector.update(
          syncing: true,
          blockIntervalMs: 30000,
          elapsedMs: 91000,
          localBestHeight: 100,
          fetchedBlocks: BigInt.from(20),
          appliedBlocks: BigInt.from(10),
        ),
        isTrue,
      );
    });

    test('progress and leaving sync reset the timer', () {
      final detector = SyncStallDetector();
      detector.update(
        syncing: true,
        blockIntervalMs: 10000,
        elapsedMs: 0,
        localBestHeight: 100,
        fetchedBlocks: BigInt.from(20),
        appliedBlocks: BigInt.from(10),
      );

      expect(
        detector.update(
          syncing: true,
          blockIntervalMs: 10000,
          elapsedMs: 60000,
          localBestHeight: 101,
          fetchedBlocks: BigInt.from(20),
          appliedBlocks: BigInt.from(11),
        ),
        isFalse,
      );
      expect(
        detector.update(
          syncing: false,
          blockIntervalMs: 10000,
          elapsedMs: 120000,
          localBestHeight: 101,
          fetchedBlocks: BigInt.from(20),
          appliedBlocks: BigInt.from(11),
        ),
        isFalse,
      );
      expect(
        detector.update(
          syncing: true,
          blockIntervalMs: 10000,
          elapsedMs: 180000,
          localBestHeight: 101,
          fetchedBlocks: BigInt.from(20),
          appliedBlocks: BigInt.from(11),
        ),
        isFalse,
      );
    });
  });

  group('walletDataHydrationInProgress', () {
    test('includes UTXO seeding', () {
      expect(
        walletDataHydrationInProgress(
          walletUtxoSeed: RpcStatusWalletUtxoSeed(
            seeded: false,
            inProgress: true,
            seedAttempts: BigInt.one,
          ),
          partialLedgerSync: null,
        ),
        isTrue,
      );
    });

    test('includes partial-ledger wallet hydration work', () {
      expect(
        walletDataHydrationInProgress(
          walletUtxoSeed: null,
          partialLedgerSync: RpcStatusPartialLedgerSync(
            inProgress: true,
            epochCachedBaseTargets: BigInt.zero,
            epochCachedBasePendingChunkReads: BigInt.zero,
            epochCachedBasePendingIndexedProbes: BigInt.zero,
            walletSeedTopUpDoneForActiveRoot: true,
            walletSpendHydrationPendingRpcs: BigInt.one,
            walletSpendHydrationRetryDueRpcs: BigInt.zero,
          ),
        ),
        isTrue,
      );
    });

    test('includes partial-ledger hydration work', () {
      expect(
        walletDataHydrationInProgress(
          walletUtxoSeed: null,
          partialLedgerSync: RpcStatusPartialLedgerSync(
            inProgress: true,
            epochCachedBaseTargets: BigInt.one,
            epochCachedBasePendingChunkReads: BigInt.one,
            epochCachedBasePendingIndexedProbes: BigInt.one,
            walletSeedTopUpDoneForActiveRoot: true,
            walletSpendHydrationPendingRpcs: BigInt.zero,
            walletSpendHydrationRetryDueRpcs: BigInt.zero,
          ),
        ),
        isTrue,
      );
    });
  });
}
