import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/node/presentation/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';
import 'package:crypto_mobile_app/core/di/providers.dart';
import 'package:crypto_mobile_app/core/result.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/core/errors/app_error.dart';
import 'package:crypto_mobile_app/features/node/domain/entities/node_status.dart' as domain;

void main() {
  testWidgets('Result toggle: mempool Err shows error', (tester) async {
    final container = ProviderContainer(overrides: [
      useResultProvidersProvider.overrideWithValue(true),
      nodeMempoolResultProvider.overrideWith((ref) async => Err(BackendError('mempool'))),
      nodeStatusProvider.overrideWith(() => _OkNodeStatus()),
      nodeRawStatusProvider.overrideWith(() => _OkRawStatus()),
      // Let blockchain/rewards default to null to avoid extra rendering
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NodeStatusScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Failed to load mempool'), findsOneWidget);
  });

  testWidgets('Result toggle: epoch data unavailable on Ok(null)', (tester) async {
    final container = ProviderContainer(overrides: [
      useResultProvidersProvider.overrideWithValue(true),
      nodeEpochRewardsResultProvider.overrideWith((ref) async => const Ok(null)),
      nodeBlockchainResultProvider.overrideWith((ref) async => const Ok(null)),
      nodeStatusProvider.overrideWith(() => _OkNodeStatus()),
      nodeRawStatusProvider.overrideWith(() => _OkRawStatus()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NodeStatusScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Epoch data unavailable'), findsOneWidget);
  });

  testWidgets('Result toggle: mempool Ok renders summary', (tester) async {
    final mempool = RpcListMempoolResp(
      entries: const [],
      count: BigInt.from(5),
      orphans: BigInt.from(2),
      totalSize: BigInt.from(2048),
      ids: null,
      nextCursor: null,
    );

    final container = ProviderContainer(overrides: [
      useResultProvidersProvider.overrideWithValue(true),
      nodeMempoolResultProvider.overrideWith((ref) async => Ok(mempool)),
      nodeStatusProvider.overrideWith(() => _OkNodeStatus()),
      nodeRawStatusProvider.overrideWith(() => _OkRawStatus()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NodeStatusScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mempool Transactions'), findsOneWidget);
    expect(find.textContaining('Count'), findsOneWidget);
    expect(find.textContaining('Orphans'), findsOneWidget);
    expect(find.textContaining('Total Size'), findsOneWidget);
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
