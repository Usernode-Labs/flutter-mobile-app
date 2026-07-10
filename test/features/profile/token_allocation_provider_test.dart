import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/profile/providers/token_allocation_provider.dart';

void main() {
  group('tokenAllocationProvider', () {
    test('provides the mocked allocation, hidden by default', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = await container.read(tokenAllocationProvider.future);

      expect(data.amount, 1250);
      expect(data.unit, 'UNODE');
      expect(data.acknowledged, isFalse);
    });

    test('acknowledge() marks the allocation revealed', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(tokenAllocationProvider.future);
      await container.read(tokenAllocationProvider.notifier).acknowledge();

      expect(
        container.read(tokenAllocationProvider).value?.acknowledged,
        isTrue,
      );
    });

    test('acknowledge() is idempotent', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(tokenAllocationProvider.future);
      final notifier = container.read(tokenAllocationProvider.notifier);
      await notifier.acknowledge();
      await notifier.acknowledge();

      expect(
        container.read(tokenAllocationProvider).value?.acknowledged,
        isTrue,
      );
    });
  });
}
