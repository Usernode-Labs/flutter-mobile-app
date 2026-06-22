import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/activity/application/activity_notification_routing.dart';
import 'package:crypto_mobile_app/features/activity/models/activity_models.dart';

void main() {
  group('resolveActivityNotificationRoute', () {
    test('falls back to Activity for empty or invalid targets', () {
      expect(resolveActivityNotificationRoute(null), '/activity');
      expect(resolveActivityNotificationRoute(''), '/activity');
      expect(resolveActivityNotificationRoute('   '), '/activity');
      expect(
        resolveActivityNotificationRoute('https://example.com/dapps'),
        '/activity',
      );
      expect(resolveActivityNotificationRoute('not-a-route'), '/activity');
    });

    test('allows stable source root routes', () {
      expect(resolveActivityNotificationRoute('/activity'), '/activity');
      expect(
        resolveActivityNotificationRoute('/activity?openRecord=record-1'),
        '/activity?openRecord=record-1',
      );
      expect(resolveActivityNotificationRoute('/challenges'), '/challenges');
      expect(resolveActivityNotificationRoute('/dapps'), '/dapps');
      expect(resolveActivityNotificationRoute('/main/node'), '/main/node');
      expect(
        resolveActivityNotificationRoute('/profile/settings'),
        '/profile/settings',
      );
    });

    test('allows existing source detail routes', () {
      expect(
        resolveActivityNotificationRoute('/dapps/opinion-market'),
        '/dapps/opinion-market',
      );
      expect(
        resolveActivityNotificationRoute('usernode://app/dapps/opinion-market'),
        '/dapps/opinion-market',
      );
      expect(
        resolveActivityNotificationRoute('/challenges/zk-identity'),
        '/challenges/zk-identity',
      );
      expect(
        resolveActivityNotificationRoute('/challenges/zk-identity/flow'),
        '/challenges/zk-identity/flow',
      );
      expect(
        resolveActivityNotificationRoute('/challenges/leaderboard'),
        '/challenges/leaderboard',
      );
      expect(
        resolveActivityNotificationRoute('/challenges/104'),
        '/challenges/104',
      );
      expect(
        resolveActivityNotificationRoute('usernode://app/challenges/104'),
        '/challenges/104',
      );
    });

    test('blocks unsafe or unsupported routes', () {
      expect(resolveActivityNotificationRoute('/wallet/send'), '/activity');
      expect(
        resolveActivityNotificationRoute('usernode://other/dapps'),
        '/activity',
      );
      expect(
        resolveActivityNotificationRoute('/settings/device-benchmark'),
        '/activity',
      );
      expect(
        resolveActivityNotificationRoute('/challenges/detail'),
        '/activity',
      );
      expect(
        resolveActivityNotificationRoute('/challenges/give-kudos'),
        '/activity',
      );
      expect(
        resolveActivityNotificationRoute('/dapps/opinion-market/settings'),
        '/activity',
      );
      expect(
        resolveActivityNotificationRoute('/activity?openRecord='),
        '/activity',
      );
    });
  });

  group('activityNotificationRecordRoute', () {
    test('builds Activity route that can re-open a stored record', () {
      expect(
        activityNotificationRecordRoute('dapp:record 1'),
        '/activity?openRecord=dapp%3Arecord+1',
      );
    });
  });

  group('hasActivityNotificationDestination', () {
    test('treats fallback route as informational', () {
      expect(hasActivityNotificationDestination(null), false);
      expect(hasActivityNotificationDestination('/activity'), false);
      expect(hasActivityNotificationDestination('/wallet/send'), false);
      expect(hasActivityNotificationDestination('/dapps'), true);
    });
  });

  group('resolveActivityRecordRoute', () {
    test('falls back to source roots for unsafe or stale targets', () {
      expect(
        resolveActivityRecordRoute(
          _record(
            source: ActivitySource.challenge,
            category: ActivityCategory.challengeDeadline,
            targetRoute: '/wallet/send',
          ),
        ),
        '/challenges',
      );
      expect(
        resolveActivityRecordRoute(
          _record(
            source: ActivitySource.dapp,
            category: ActivityCategory.dappFeedback,
            targetRoute: '/wallet/send',
          ),
        ),
        '/dapps',
      );
      expect(
        resolveActivityRecordRoute(
          _record(
            source: ActivitySource.node,
            category: ActivityCategory.productionResult,
            targetRoute: null,
          ),
        ),
        '/main/node',
      );
      expect(
        resolveActivityRecordRoute(
          _record(
            source: ActivitySource.system,
            category: ActivityCategory.productionSetup,
            targetRoute: '/settings',
          ),
        ),
        '/profile/settings',
      );
    });
  });
}

ActivityRecord _record({
  required ActivitySource source,
  required ActivityCategory category,
  String? targetRoute,
}) {
  return ActivityRecord(
    id: 'record',
    source: source,
    category: category,
    eventType: 'test',
    title: 'Test',
    body: 'Body',
    createdAt: DateTime(2026, 1, 1),
    priority: ActivityPriority.standard,
    pinned: false,
    targetRoute: targetRoute,
  );
}
