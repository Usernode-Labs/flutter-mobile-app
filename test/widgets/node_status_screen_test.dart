import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/node/presentation/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';
import 'package:crypto_mobile_app/features/node/domain/entities/node_status.dart' as domain;
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_blockchain.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';

void main() {
  testWidgets('NodeStatusScreen renders with provider overrides', (tester) async {
    final container = ProviderContainer(overrides: [
      nodeStatusProvider.overrideWith((ref) => const AsyncData(domain.NodeStatus(
            connectedPeers: 0,
            totalPeers: 0,
            localBestHeight: null,
            networkBestHeight: null,
            epoch: null,
            globalSlot: null,
            bestTipHash: null,
          ))),
      nodeRawStatusProvider.overrideWith(() => _FakeRawStatusController()),
      nodeMempoolProvider.overrideWith(() => _FakeNullMempoolController()),
      nodeBlockchainProvider.overrideWith(() => _FakeNullBlockchainController()),
      nodeEpochRewardsProvider.overrideWith(() => _FakeNullEpochRewardsController()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NodeStatusScreen()),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Node Status'), findsOneWidget);
    // Best Tip section header should appear
    expect(find.text('Best Tip'), findsOneWidget);
  });
}

class _FakeRawStatusController extends NodeRawStatusController {
  @override
  Future<NodeRawStatusView?> build() async {
    return const NodeRawStatusView(
      peers: [],
      localBest: null,
      networkBest: null,
      fetchProgress: null,
      applyProgress: null,
    );
  }
}

class _FakeNullMempoolController extends NodeMempoolController {
  @override
  Future<RpcListMempoolResp?> build() => Future.value(null);
}

class _FakeNullBlockchainController extends NodeBlockchainController {
  @override
  Future<RpcListBlockchainResp?> build() => Future.value(null);
}

class _FakeNullEpochRewardsController extends NodeEpochRewardsController {
  @override
  Future<RpcEpochRewardsResp?> build() => Future.value(null);
}
