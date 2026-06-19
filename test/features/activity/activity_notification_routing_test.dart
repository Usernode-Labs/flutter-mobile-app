import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/activity/application/activity_notification_routing.dart';

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
}
