import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/node/presentation/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';
import 'package:crypto_mobile_app/features/node/domain/entities/node_status.dart' as domain;
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_blockchain.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/gen_l10n/app_localizations.dart';

void main() {
  testWidgets('Mempool summary renders with values', (tester) async {
    final mempool = RpcListMempoolResp(
      entries: const [],
      count: BigInt.from(3),
      orphans: BigInt.from(1),
      totalSize: BigInt.from(1024),
      ids: null,
      nextCursor: null,
    );

    final container = ProviderContainer(overrides: [
      nodeMempoolProvider.overrideWith(() => _StaticMempoolController(mempool)),
      nodeStatusProvider.overrideWith(() => _OkNodeStatus()),
      nodeRawStatusProvider.overrideWith(() => _NullRawStatus()),
      // Prevent unrelated providers from hitting the backend
      nodeBlockchainProvider.overrideWith(() => _NullBlockchainController()),
      nodeEpochRewardsProvider.overrideWith(() => _NullEpochRewardsController()),
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

    expect(find.text('Mempool Transactions'), findsOneWidget);
    expect(find.textContaining('Count'), findsOneWidget);
    expect(find.textContaining('Orphans'), findsOneWidget);
    expect(find.textContaining('Total Size'), findsOneWidget);
  });
}

class _StaticMempoolController extends NodeMempoolController {
  final RpcListMempoolResp value;
  _StaticMempoolController(this.value);
  @override
  Future<RpcListMempoolResp?> build() async => value;
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
