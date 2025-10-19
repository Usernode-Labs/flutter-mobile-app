import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/features/node/presentation/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/core/di/providers.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';
import 'package:crypto_mobile_app/features/node/domain/entities/node_status.dart' as domain;

void main() {
  testWidgets('NodeStatusScreen quick theme toggle cycles theme', (tester) async {
    SharedPreferences.setMockInitialValues({});

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
      nodeRawStatusProvider.overrideWith(() => _NullRawStatus()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NodeStatusScreen()),
    ));
    await tester.pumpAndSettle();

    // Default should be system; tap quick toggle to cycle -> light
    expect(container.read(themeModeProvider), ThemeMode.system);
    await tester.tap(find.byIcon(Icons.brightness_6_outlined));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.light);
  });
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

