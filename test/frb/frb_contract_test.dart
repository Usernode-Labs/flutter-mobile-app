// ignore_for_file: library_annotations, no_wildcard_variable_uses

@Tags(['frb', 'contract'])

// Contract tests for FRB-backed Flutter API surface.
// These tests DO NOT load the Rust dynamic library. They exist to ensure the
// function and type signatures used by our Flutter code remain stable. If the
// code generator or Rust API changes in a way that alters these Dart signatures,
// these tests will fail to compile or at assignment time.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

// Our façade over FRB
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/core/identity/wallet_identity_lease.dart';

// FRB-generated types used by the façade and UI
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/wallet_tx.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_blockchain.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_utxos_by_owner.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/wallet.dart';
import 'package:crypto_mobile_app/src/rust/rpc.dart';
import 'package:crypto_mobile_app/src/rust/rpc/wallet.dart';

typedef ListBlockchainFn = Future<RpcListBlockchainResp?> Function(
    {int? limit, bool? fromTip});
typedef ListMempoolFn = Future<RpcListMempoolResp?> Function();
typedef EpochRewardsFn = Future<RpcEpochRewardsResp?> Function({int? epoch});
typedef GetStatusFn = Future<RpcStatusResp?> Function({bool includeVrfDetails});
typedef BuildEnvFn = BuildInfo Function();
typedef ListUtxosByOwnerFn = Future<RpcListUtxosByOwnerResp?> Function(
    {required PublicKeyHash owner, int? limit});
typedef WalletBalanceFn = Future<RpcWalletBalanceResp?> Function(
    {required PublicKeyHash owner});
typedef TransferFundsFn = Future<RpcWalletTxSendResp?> Function(
    {required WalletIdentityLease authority,
    required BigInt amount,
    required PublicKeyHash toPkHash});
typedef TransferFundsEventsFn = Stream<WalletTxSendEvent> Function(
    {required WalletIdentityLease authority,
    required BigInt amount,
    required PublicKeyHash toPkHash});
typedef SendTransactionFn = Future<RpcWalletTxSendResp?> Function(
    {required WalletIdentityLease authority,
    required BigInt amount,
    required PublicKeyHash toPkHash,
    required Memo memo});
typedef WalletTxSendFn = Stream<WalletTxSendEvent> Function(
    {required PublicKeyHash fromPkHash,
    required BigInt amount,
    required PublicKeyHash toPkHash,
    required Memo memo});
typedef WalletTxSendResultFn = Future<RpcWalletTxSendResp?> Function(
    {required PublicKeyHash fromPkHash,
    required BigInt amount,
    required PublicKeyHash toPkHash,
    required Memo memo});

void main() {
  group('RustBackendService API signatures (no-load)', () {
    test('stopNode is a no-op before FRB initialization', () async {
      await expectLater(RustBackendService.instance.stopNode(), completes);
    });

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

    test('getStatus({bool? includeVrfDetails})', () {
      final GetStatusFn f = RustBackendService.instance.getStatus;
      expect(f, isNotNull);
    });

    test('listUtxosByOwner({required PublicKeyHash owner, int? limit})', () {
      final ListUtxosByOwnerFn f = RustBackendService.instance.listUtxosByOwner;
      expect(f, isNotNull);
    });

    test('walletBalance({required PublicKeyHash owner})', () {
      final WalletBalanceFn f = RustBackendService.instance.walletBalance;
      expect(f, isNotNull);
    });

    test('transferFunds requires wallet authority', () {
      final TransferFundsFn f = RustBackendService.instance.transferFunds;
      expect(f, isNotNull);
    });

    test('transferFundsEvents requires wallet authority', () {
      final TransferFundsEventsFn f =
          RustBackendService.instance.transferFundsEvents;
      expect(f, isNotNull);
    });

    test('sendTransaction requires wallet authority', () {
      final SendTransactionFn f = RustBackendService.instance.sendTransaction;
      expect(f, isNotNull);
    });

    test('wallet.txSend(...) returns stream events', () {
      void check(NodeRpcClientWallet wallet) {
        final WalletTxSendFn f = wallet.txSend;
        expect(f, isNotNull);
      }

      expect(check, isNotNull);
    });

    test('wallet.txSendResult(...) returns final response', () {
      void check(NodeRpcClientWallet wallet) {
        final WalletTxSendResultFn f = wallet.txSendResult;
        expect(f, isNotNull);
      }

      expect(check, isNotNull);
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

    test('RpcStatusNode members', () {
      void check(RpcStatusNode node) {
        final chainId = node.chainId;
        final chainName = node.chainName;
        final peerId = node.peerId;
        final timeMs = node.timeMs; // BigInt
        final slotsInEpoch = node.slotsInEpoch;
        final blockInterval = node.blockInterval;
        final curGlobalSlot = node.curGlobalSlot;
        final curEpoch = node.curEpoch;
        final flags = node.flags;
        expect(
          [
            chainId,
            chainName,
            peerId,
            timeMs,
            slotsInEpoch,
            blockInterval,
            curGlobalSlot,
            curEpoch,
            flags,
          ].isNotEmpty,
          isTrue,
        );
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

    test('RpcEpochWonSlot members', () {
      void check(RpcEpochWonSlot slot) {
        final globalSlot = slot.globalSlot; // int
        final expectedTimeMs = slot.expectedTimeMs; // BigInt
        expect([globalSlot, expectedTimeMs].isNotEmpty, isTrue);
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

    test('RpcWalletBalanceResp members', () {
      void check(RpcWalletBalanceResp r) {
        final tracked = r.tracked; // bool
        final total = r.baseTotal; // BigInt
        final available = r.baseAvailable; // BigInt
        final largest = r.baseLargestUtxo; // BigInt
        final count = r.baseUtxos; // BigInt
        expect([tracked, total, available, largest, count].isNotEmpty, isTrue);
      }

      expect(check, isNotNull);
    });

    test('RpcWalletTxSendResp members', () {
      void check(RpcWalletTxSendResp r) {
        final state = r.state; // RpcWalletTxSendState
        final queued = r.queued; // bool
        final error = r.error; // String?
        final txId = r.txId; // String?
        expect([state, queued, error, txId].length, greaterThan(0));
      }

      expect(check, isNotNull);
    });

    test('WalletTxSendEvent variants', () {
      void check(WalletTxSendEvent e) {
        final label = e.when(
          syncing: () => 'syncing',
          queued: (txId) => txId,
          rejected: (error, state) => '$error:$state',
        );
        expect(label, isNotEmpty);
      }

      expect(check, isNotNull);
    });
  });
}
