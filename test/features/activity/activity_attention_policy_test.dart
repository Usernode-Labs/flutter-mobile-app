import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/activity/application/activity_attention_policy.dart';
import 'package:crypto_mobile_app/features/activity/models/activity_models.dart';

void main() {
  test('turns production setup into a persistent pinned record', () {
    const policy = ActivityAttentionPolicy();

    final record = policy.recordFor(
      const ActivityEvent(
        source: ActivitySource.system,
        category: ActivityCategory.productionSetup,
        eventType: 'battery',
        title: 'Battery optimization is not set up',
        body: 'Open Usernode settings to finish setup.',
        targetRoute: '/profile/settings',
      ),
    );

    expect(record.priority, ActivityPriority.persistent);
    expect(record.pinned, isTrue);
    expect(record.targetRoute, '/profile/settings');
    expect(policy.shouldPresentSystemNotification(record), isTrue);
  });

  test(
    'keeps passive production status in the ledger without interruption',
    () {
      const policy = ActivityAttentionPolicy();

      final record = policy.recordFor(
        const ActivityEvent(
          source: ActivitySource.node,
          category: ActivityCategory.productionStatus,
          eventType: 'node_ready',
          title: 'Node ready',
          body: 'No slots this epoch.',
          targetRoute: '/main/node',
        ),
      );

      expect(record.priority, ActivityPriority.passive);
      expect(policy.shouldPresentSystemNotification(record), isFalse);
    },
  );
}
