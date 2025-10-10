@Tags(['frb', 'contract'])

// Contract tests for FRB-backed Flutter API surface.
// These tests DO NOT load the Rust dynamic library. They exist to ensure the
// function and type signatures used by our Flutter code remain stable. If the
// code generator or Rust API changes in a way that alters these Dart signatures,
// these tests will fail to compile or at assignment time.

import 'package:flutter_test/flutter_test.dart';

// Our façade over FRB
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';

// FRB-generated types used by the façade and UI
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_blockchain.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/src/rust/third_party/usernode_core/build.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_utxos_by_owner.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/transfer_funds.dart';
import 'package:crypto_mobile_app/src/rust/third_party/usernode_core/account.dart';

typedef ListBlockchainFn = Future<RpcListBlockchainResp?> Function({int? limit, bool? fromTip});
typedef ListMempoolFn = Future<RpcListMempoolResp?> Function();
typedef EpochRewardsFn = Future<RpcEpochRewardsResp?> Function({int? epoch});
typedef GetStatusFn = Future<RpcStatusResp?> Function();
typedef BuildEnvFn = BuildEnv Function();
typedef ListUtxosByOwnerFn = Future<RpcListUtxosByOwnerResp?> Function({required PublicKeyHash owner, int? limit});
typedef TransferFundsFn = Future<RpcTransferFundsResp?> Function({required PublicKeyHash fromPkHash, required BigInt amount, required PublicKeyHash toPkHash});

void main() {
  group('RustBackendService API signatures (no-load)', () {
    test('listBlockchain({int? limit, bool? fromTip})', () {
      final ListBlockchainFn f = RustBackendService.instance.listBlockchain;
      expect(f, isNotNull);
    });

    test('listMempool()', () {
      final ListMempoolFn f = RustBackendService.instance.listMempool;
      expect(f, isNotNull);
    });

    test('epochRewards({int? epoch})', () {
      final EpochRewardsFn f = RustBackendService.instance.epochRewards;
      expect(f, isNotNull);
    });

    test('getStatus()', () {
      final GetStatusFn f = RustBackendService.instance.getStatus;
      expect(f, isNotNull);
    });

    test('listUtxosByOwner({required PublicKeyHash owner, int? limit})', () {
      final ListUtxosByOwnerFn f = RustBackendService.instance.listUtxosByOwner;
      expect(f, isNotNull);
    });

    test('transferFunds({required PublicKeyHash fromPkHash, required BigInt amount, required PublicKeyHash toPkHash})', () {
      final TransferFundsFn f = RustBackendService.instance.transferFunds;
      expect(f, isNotNull);
    });
  });

  group('FRB value types used by UI (shape checks)', () {
    test('RpcStatusBlockInfo members', () {
      // Closure typed to expected members; never invoked.
      void check(RpcStatusBlockInfo b) {
        int _ = b.height;
        int e = b.epoch;
        int s = b.globalSlot;
        final h = b.hash; // BlockHash
        final pk = b.producerPubkey; // String
        final t = b.transactions; // BigInt
        final batches = b.batches; // List<RpcStatusBlockBatchInfo>
        // Use locals to silence analyzer warnings
        expect([_, e, s].isNotEmpty, isTrue);
        expect([h, pk, t, batches].isNotEmpty, isTrue);
      }
      expect(check, isNotNull);
    });

    test('RpcListBlockchainResp members', () {
      void check(RpcListBlockchainResp r) {
        final items = r.items; // List<RpcStatusBlockInfo>
        final root = r.rootHash; // BlockHash
        final tip = r.tipHash; // BlockHash
        final total = r.totalBlocks; // BigInt
        expect([items, root, tip, total].isNotEmpty, isTrue);
      }
      expect(check, isNotNull);
    });

    test('RpcListMempoolResp members', () {
      void check(RpcListMempoolResp r) {
        final count = r.count; // BigInt
        final orphans = r.orphans; // BigInt
        final total = r.totalSize; // BigInt
        final entries = r.entries; // List<MempoolTxSummary>
        expect([count, orphans, total, entries].isNotEmpty, isTrue);
      }
      expect(check, isNotNull);
    });

    test('RpcEpochRewardsResp members', () {
      void check(RpcEpochRewardsResp r) {
        final epoch = r.epoch; // int
        final reward = r.rewardPerBlock; // BigInt
        final produced = r.producedInEpoch; // int
        final wins = r.winsInEpoch; // int
        final earned = r.earnedSoFar; // BigInt
        final expected = r.expectedTotal; // BigInt
        final pubkey = r.producerPubkey; // String?
        final won = r.wonSlots; // List<RpcEpochWonSlot>?
        expect([epoch, reward, produced, wins].isNotEmpty, isTrue);
        expect([earned, expected, pubkey, won].length, greaterThanOrEqualTo(0));
      }
      expect(check, isNotNull);
    });

    test('RpcListUtxosByOwnerResp members', () {
      void check(RpcListUtxosByOwnerResp r) {
        final items = r.items; // List<OwnedUtxo>
        expect(items, isA<List<OwnedUtxo>>());
      }
      expect(check, isNotNull);
    });

    test('RpcTransferFundsResp members', () {
      void check(RpcTransferFundsResp r) {
        final queued = r.queued; // bool
        final error = r.error; // String?
        expect([queued, error].length, greaterThan(0));
      }
      expect(check, isNotNull);
    });
  });
}
