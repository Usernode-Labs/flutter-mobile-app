import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/node/presentation/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';
import 'package:crypto_mobile_app/features/node/domain/entities/node_status.dart' as domain;
import 'package:crypto_mobile_app/core/errors/app_error.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_blockchain.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';

void main() {
  testWidgets('NodeStatusScreen shows mempool error text', (tester) async {
    final container = ProviderContainer(overrides: [
      nodeStatusProvider.overrideWith(() => _OkNodeStatus()),
      nodeRawStatusProvider.overrideWith(() => _OkRawStatus()),
      nodeMempoolProvider.overrideWith(() => _ErrorMempoolController()),
      nodeBlockchainProvider.overrideWith(() => _OkNullBlockchainController()),
      nodeEpochRewardsProvider.overrideWith(() => _OkNullEpochRewardsController()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NodeStatusScreen()),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Failed to load mempool'), findsOneWidget);
  });

  testWidgets('NodeStatusScreen shows epoch data unavailable on errors', (tester) async {
    final container = ProviderContainer(overrides: [
      nodeStatusProvider.overrideWith(() => _OkNodeStatus()),
      nodeRawStatusProvider.overrideWith(() => _OkRawStatus()),
      nodeMempoolProvider.overrideWith(() => _OkNullMempoolController()),
      nodeBlockchainProvider.overrideWith(() => _ErrorBlockchainController()),
      nodeEpochRewardsProvider.overrideWith(() => _ErrorEpochRewardsController()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NodeStatusScreen()),
    ));

    await tester.pumpAndSettle();
    // Scheduled slots tab shows "Epoch data unavailable" when providers error
    expect(find.textContaining('Epoch data unavailable'), findsOneWidget);
  });
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

class _OkRawStatus extends NodeRawStatusController {
  @override
  Future<NodeRawStatusView?> build() async => const NodeRawStatusView(
        peers: [],
        localBest: null,
        networkBest: null,
        fetchProgress: null,
        applyProgress: null,
      );
}

class _ErrorMempoolController extends NodeMempoolController {
  @override
  Future<RpcListMempoolResp?> build() async =>
      throw const BackendError('Failed to load mempool');
}

class _OkNullMempoolController extends NodeMempoolController {
  @override
  Future<RpcListMempoolResp?> build() => Future.value(null);
}

class _ErrorBlockchainController extends NodeBlockchainController {
  @override
  Future<RpcListBlockchainResp?> build() async =>
      throw const BackendError('Failed to load blockchain');
}

class _OkNullBlockchainController extends NodeBlockchainController {
  @override
  Future<RpcListBlockchainResp?> build() => Future.value(null);
}

class _ErrorEpochRewardsController extends NodeEpochRewardsController {
  @override
  Future<RpcEpochRewardsResp?> build() async =>
      throw const BackendError('Failed to load epoch rewards');
}

class _OkNullEpochRewardsController extends NodeEpochRewardsController {
  @override
  Future<RpcEpochRewardsResp?> build() => Future.value(null);
}
