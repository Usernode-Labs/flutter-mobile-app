import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/node/presentation/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_blockchain.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/features/node/domain/entities/node_status.dart' as domain;

void main() {
  testWidgets('Scheduled Slots tab shows unavailable when providers are null', (tester) async {
    final container = ProviderContainer(overrides: [
      nodeStatusProvider.overrideWith(() => _OkNodeStatus()),
      nodeRawStatusProvider.overrideWith(() => _NullRawStatus()),
      nodeBlockchainProvider.overrideWith(() => _NullBlockchainController()),
      nodeEpochRewardsProvider.overrideWith(() => _NullEpochRewardsController()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NodeStatusScreen()),
    ));
    await tester.pumpAndSettle();

    // Switch to Scheduled Slots tab
    await tester.tap(find.text('Scheduled Slots'));
    await tester.pumpAndSettle();

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

class _NullRawStatus extends NodeRawStatusController {
  @override
  Future<NodeRawStatusView?> build() async => const NodeRawStatusView(
        peers: [],
        localBest: null,
        networkBest: null,
        fetchProgress: null,
        applyProgress: null,
      );
}

class _NullBlockchainController extends NodeBlockchainController {
  @override
  Future<RpcListBlockchainResp?> build() async => Future.value(null);
}

class _NullEpochRewardsController extends NodeEpochRewardsController {
  @override
  Future<RpcEpochRewardsResp?> build() async => Future.value(null);
}
