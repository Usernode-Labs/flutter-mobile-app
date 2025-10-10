import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/node/presentation/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';
import 'package:crypto_mobile_app/features/node/domain/entities/node_status.dart' as domain;

import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_blockchain.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/src/rust/third_party/usernode_core/block.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/gen_l10n/app_localizations.dart';

void main() {
  testWidgets('Produced Blocks positive path renders block rows and BEST TIP', (tester) async {
    final blocks = <RpcStatusBlockInfo>[
      _FakeStatusBlockInfo(
        height: 100,
        epoch: 2,
        globalSlot: 20,
        hash: _FakeBlockHash('0xabc123'),
        producerPubkey: 'pubkey-1',
        transactions: BigInt.zero,
        batches: [RpcStatusBlockBatchInfo(transactions: BigInt.one)],
      ),
      _FakeStatusBlockInfo(
        height: 101,
        epoch: 2,
        globalSlot: 21,
        hash: _FakeBlockHash('0xdef456'),
        producerPubkey: 'pubkey-2',
        transactions: BigInt.zero,
        batches: [RpcStatusBlockBatchInfo(transactions: BigInt.from(2))],
      ),
    ];

    final blockchain = _FakeListBlockchainResp(items: blocks);
    final rewards = RpcEpochRewardsResp(
      epoch: 2,
      rewardPerBlock: BigInt.from(10),
      producedInEpoch: 2,
      winsInEpoch: 2,
      earnedSoFar: BigInt.from(20),
      expectedTotal: BigInt.from(20),
      producerPubkey: 'pubkey-2',
      wonSlots: const [],
    );

    final container = ProviderContainer(overrides: [
      nodeStatusProvider.overrideWith(() => _OkNodeStatus()),
      nodeRawStatusProvider.overrideWith(() => _RawBestTipSlot(globalSlot: 21)),
      nodeBlockchainProvider.overrideWith(() => _StaticBlockchainController(blockchain)),
      nodeEpochRewardsProvider.overrideWith(() => _StaticRewardsController(rewards)),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: const NodeStatusScreen(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Produced Blocks'), findsOneWidget);
    expect(find.textContaining('Block #100'), findsOneWidget);
    expect(find.textContaining('Block #101'), findsOneWidget);
    // Best tip badge should appear for the block with globalSlot 21
    expect(find.text('BEST TIP'), findsOneWidget);
  });
}

// Fakes implementing FRB abstract interfaces for test-only usage

class _FakeBlockHash implements BlockHash {
  final String _s;
  _FakeBlockHash(this._s);
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
  }
  @override
  bool get isDisposed => _disposed;
  @override
  String toString() => _s;
}

class _FakeStatusBlockInfo implements RpcStatusBlockInfo {
  @override
  List<RpcStatusBlockBatchInfo> batches;
  @override
  int epoch;
  @override
  int globalSlot;
  @override
  BlockHash hash;
  @override
  int height;
  @override
  String producerPubkey;
  @override
  BigInt transactions;

  _FakeStatusBlockInfo({
    required this.batches,
    required this.epoch,
    required this.globalSlot,
    required this.hash,
    required this.height,
    required this.producerPubkey,
    required this.transactions,
  });

  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
  }
  @override
  bool get isDisposed => _disposed;
}

class _FakeListBlockchainResp implements RpcListBlockchainResp {
  @override
  List<RpcStatusBlockInfo> items;
  BlockHash _rootHash = _FakeBlockHash('0xroot');
  BlockHash _tipHash = _FakeBlockHash('0xtip');
  BigInt _totalBlocks;

  _FakeListBlockchainResp({required this.items}) : _totalBlocks = BigInt.from(items.length);

  @override
  BlockHash get rootHash => _rootHash;
  @override
  set rootHash(BlockHash v) => _rootHash = v;

  @override
  BlockHash get tipHash => _tipHash;
  @override
  set tipHash(BlockHash v) => _tipHash = v;

  @override
  BigInt get totalBlocks => _totalBlocks;
  @override
  set totalBlocks(BigInt v) => _totalBlocks = v;

  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
  }
  @override
  bool get isDisposed => _disposed;
}

// Controllers for overrides

class _StaticBlockchainController extends NodeBlockchainController {
  final RpcListBlockchainResp value;
  _StaticBlockchainController(this.value);
  @override
  Future<RpcListBlockchainResp?> build() async => value;
}

class _StaticRewardsController extends NodeEpochRewardsController {
  final RpcEpochRewardsResp value;
  _StaticRewardsController(this.value);
  @override
  Future<RpcEpochRewardsResp?> build() async => value;
}

class _OkNodeStatus extends NodeStatusController {
  @override
  Future<domain.NodeStatus?> build() async => const domain.NodeStatus(
        connectedPeers: 0,
        totalPeers: 0,
        localBestHeight: null,
        networkBestHeight: null,
        epoch: null,
        globalSlot: null,
        bestTipHash: null,
      );
}

class _RawBestTipSlot extends NodeRawStatusController {
  final int globalSlot;
  _RawBestTipSlot({required this.globalSlot});
  @override
  Future<NodeRawStatusView?> build() async => NodeRawStatusView(
        peers: const [],
        localBest: null,
        networkBest: null,
        fetchProgress: null,
        applyProgress: null,
      );
}
