import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/activity/models/activity_models.dart';
import 'package:crypto_mobile_app/features/dapps/application/dapp_notification_bridge.dart';

void main() {
  group('DappNotificationBridgePayload', () {
    test('parses current Social Vibecoding top-level notify shape', () {
      final event = DappNotificationBridgePayload.parse(
        payload: const {
          'method': 'notify',
          'title': 'Dev session finished',
          'body': 'Your session is ready.',
          'route': '#app/builder/dev/sessions/123',
        },
        dappName: 'Social Vibecoding',
        nativeTargetRoute: '/dapps',
      );

      expect(event.source, ActivitySource.dapp);
      expect(event.category, ActivityCategory.dappFeedback);
      expect(event.eventType, 'dapp_notify');
      expect(event.title, 'Dev session finished');
      expect(event.body, 'Your session is ready.');
      expect(event.targetRoute, '/dapps');
      expect(
        event.dedupeKey,
        'dapp:Social Vibecoding:#app/builder/dev/sessions/123',
      );
      expect(event.payload['webRoute'], '#app/builder/dev/sessions/123');
    });

    test('parses structured args shape', () {
      final event = DappNotificationBridgePayload.parse(
        payload: const {
          'method': 'notify',
          'id': 'request-1',
          'args': {
            'title': 'Move confirmed',
            'body': 'Your Last One Wins move is on chain.',
            'category': 'game',
            'priority': 'attention',
            'eventType': 'move_confirmed',
            'dedupeKey': 'lastwin:move:42',
            'route': '/rounds/current',
          },
        },
        dappName: 'Last One Wins',
        nativeTargetRoute: '/dapps/last-one-wins',
      );

      expect(event.category, ActivityCategory.dappGame);
      expect(event.priority, ActivityPriority.attention);
      expect(event.eventType, 'move_confirmed');
      expect(event.dedupeKey, 'lastwin:move:42');
      expect(event.targetRoute, '/dapps/last-one-wins');
      expect(event.expiresAt, isNotNull);
      expect(event.payload['webRoute'], '/rounds/current');
    });

    test('rejects missing or blank title', () {
      expect(
        () => DappNotificationBridgePayload.parse(
          payload: const {'method': 'notify', 'body': 'No title'},
          dappName: 'Echo',
          nativeTargetRoute: '/dapps',
        ),
        throwsA(isA<DappNotificationBridgeParseException>()),
      );

      expect(
        () => DappNotificationBridgePayload.parse(
          payload: const {'method': 'notify', 'title': '   '},
          dappName: 'Echo',
          nativeTargetRoute: '/dapps',
        ),
        throwsA(isA<DappNotificationBridgeParseException>()),
      );
    });

    test('maps category and priority requests conservatively', () {
      final identity = DappNotificationBridgePayload.parse(
        payload: const {
          'method': 'notify',
          'title': 'Signature requested',
          'category': 'identity',
          'priority': 'persistent',
        },
        dappName: 'Identity dApp',
        nativeTargetRoute: '/dapps/identity-dapp',
      );

      final tx = DappNotificationBridgePayload.parse(
        payload: const {
          'method': 'notify',
          'title': 'Transaction settled',
          'category': 'tx',
          'priority': 'low',
        },
        dappName: 'Echo',
        nativeTargetRoute: '/dapps/echo',
      );

      expect(identity.category, ActivityCategory.dappIdentity);
      expect(identity.priority, ActivityPriority.attention);
      expect(tx.category, ActivityCategory.dappTransaction);
      expect(tx.priority, ActivityPriority.passive);
    });

    test('caps long title and body text', () {
      final event = DappNotificationBridgePayload.parse(
        payload: {
          'method': 'notify',
          'title': 'T' * (dappNotificationTitleMaxLength + 20),
          'body': 'B' * (dappNotificationBodyMaxLength + 20),
        },
        dappName: 'Echo',
        nativeTargetRoute: '/dapps/echo',
      );

      expect(event.title.length, dappNotificationTitleMaxLength);
      expect(event.title.endsWith('...'), isTrue);
      expect(event.body.length, dappNotificationBodyMaxLength);
      expect(event.body.endsWith('...'), isTrue);
    });

    test('synthesizes dedupe when dApp omits route and tag', () {
      final event = DappNotificationBridgePayload.parse(
        payload: const {
          'method': 'notify',
          'title': 'Approval requested',
          'priority': 'attention',
        },
        dappName: 'Builder Board',
        nativeTargetRoute: '/dapps/builder-board',
      );

      expect(event.dedupeKey, 'dapp:builderboard:dappnotify:approvalrequested');
      expect(event.expiresAt, isNotNull);
    });

    test('falls back to dApps when native target route is unsafe', () {
      final event = DappNotificationBridgePayload.parse(
        payload: const {
          'method': 'notify',
          'title': 'Unsafe route attempt',
          'route': '/wallet/send',
        },
        dappName: 'Echo',
        nativeTargetRoute: '/wallet/send',
      );

      expect(event.targetRoute, '/dapps');
      expect(event.payload['webRoute'], '/wallet/send');
    });
  });
}
