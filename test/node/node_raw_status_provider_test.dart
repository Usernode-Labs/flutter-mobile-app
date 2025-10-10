import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';

void main() {
  test('nodeRawStatusProvider derived fields', () async {
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

    final view = container.read(nodeRawStatusProvider).value!;
    expect(view.localBestHeight, isNull);
    expect(view.networkBestHeight, isNull);
    expect(view.epoch, isNull);
    expect(view.globalSlot, isNull);
    expect(view.bestTipHash, isNull);
    expect(view.bestTipBatchTransactions, isEmpty);
  });
}
