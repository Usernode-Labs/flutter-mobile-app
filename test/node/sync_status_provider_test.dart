import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/node/presentation/controllers/sync_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';

void main() {
  test('syncStatusProvider reports synced when no pending progress', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(nodeRawStatusProvider.notifier).state = AsyncData(
      NodeRawStatusView(
        peers: const [],
        localBest: null,
        networkBest: null,
        fetchProgress: null,
        applyProgress: null,
      ),
    );

    final sync = container.read(syncStatusProvider);
    expect(sync.isSynced, isTrue);
    expect(sync.label, contains('Synced'));
    expect(sync.progress, 1.0);
  });
}
