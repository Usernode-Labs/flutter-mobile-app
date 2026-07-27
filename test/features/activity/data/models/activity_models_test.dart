import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/activity/data/models/activity_models.dart';
import 'package:crypto_mobile_app/features/activity/data/models/social_dev_run_transition.dart';

import '../../activity_test_fixtures.dart';

void main() {
  group('Activity wire models', () {
    test('parse the exact published Activity service fixtures', () {
      final page = ActivityFeedPage.fromJson(
        _fixture('activity-page.valid.json'),
      );
      final session = ActivitySession.fromJson(
        _fixture('auth-exchange.valid.json'),
      );
      final unread = ActivityUnreadCount.fromJson(
        _fixture('unread-count.valid.json'),
      );
      final item = page.items.last;

      expect(item.inboxSequence, '1');
      expect(item.syncSequence, '6');
      expect(item.isUnread, isFalse);
      expect(item.activityEvent.ledgerId, 'activity-test');
      expect(item.activityEvent.sourceEvent.resource.version, 2);

      final transition = SocialDevRunTransition.fromItem(item);
      expect(transition.status, SocialDevRunStatus.succeeded);
      expect(transition.runMode, SocialDevRunMode.build);
      expect(transition.result, SocialDevRunResult.code);
      expect(transition.route.appId, '7');
      expect(transition.route.sessionId, '314');
      expect(session.accessToken, validActivityToken);
      expect(unread.value, 3);
    });

    test('receipt with null readAt is not unread', () {
      final item = ActivityItem.fromJson(
        validActivityItemJson(status: 'cancelled', runMode: 'scout'),
      );

      expect(item.readAt, isNull);
      expect(item.defaultAttention, ActivityAttention.receipt);
      expect(item.isUnread, isFalse);
    });

    test('accepts integral JSON number forms for schema versions', () {
      final json = validActivityItemJson();
      final event = json['activityEvent'] as Map<String, dynamic>;
      event['envelopeVersion'] = 1.0;
      final sourceEvent = event['sourceEvent'] as Map<String, dynamic>;
      sourceEvent['schemaVersion'] = 1.0;

      final item = ActivityItem.fromJson(json);
      expect(item.activityEvent.envelopeVersion, 1);
      expect(item.activityEvent.sourceEvent.schemaVersion, 1);
    });

    test('rejects extra response fields', () {
      final json = validFeedPageJson()..['unexpected'] = true;
      expect(() => ActivityFeedPage.fromJson(json), throwsFormatException);
    });

    test('copies nested JSON maps before exposing them as immutable', () {
      final json = validActivityItemJson();
      final event = json['activityEvent'] as Map<String, dynamic>;
      final sourceEvent = event['sourceEvent'] as Map<String, dynamic>;
      final facts = sourceEvent['facts'] as Map<String, dynamic>;
      final parameters = (sourceEvent['route']
          as Map<String, dynamic>)['parameters'] as Map<String, dynamic>;

      final item = ActivityItem.fromJson(json);
      facts['result'] = 'spec';
      parameters['sessionId'] = '999';

      final transition = SocialDevRunTransition.fromItem(item);
      expect(transition.result, SocialDevRunResult.code);
      expect(transition.route.sessionId, '314');
    });

    test('rejects invalid calendar dates, enums, and unsafe counters', () {
      final invalidDate = validActivityItemJson();
      final invalidDateEvent =
          invalidDate['activityEvent'] as Map<String, dynamic>;
      invalidDateEvent['ingestedAt'] = '2026-02-30T12:00:00Z';
      expect(
        () => ActivityItem.fromJson(invalidDate),
        throwsFormatException,
      );

      final invalidTrust = validActivityItemJson();
      final invalidTrustEvent =
          invalidTrust['activityEvent'] as Map<String, dynamic>;
      final source = invalidTrustEvent['source'] as Map<String, dynamic>;
      source['trustClass'] = 'unknown';
      expect(
        () => ActivityItem.fromJson(invalidTrust),
        throwsFormatException,
      );

      final unsafeCounter = validActivityItemJson();
      final unsafeEvent =
          unsafeCounter['activityEvent'] as Map<String, dynamic>;
      final unsafeSourceEvent =
          unsafeEvent['sourceEvent'] as Map<String, dynamic>;
      final resource = unsafeSourceEvent['resource'] as Map<String, dynamic>;
      resource['version'] = 9007199254740992;
      expect(
        () => ActivityItem.fromJson(unsafeCounter),
        throwsFormatException,
      );
    });

    test('enforces the signed 64-bit sequence boundary', () {
      final max = validActivityItemJson(
        inboxSequence: '9223372036854775807',
      );
      expect(ActivityItem.fromJson(max).inboxSequence, endsWith('5807'));

      final above = validActivityItemJson(
        inboxSequence: '9223372036854775808',
      );
      expect(() => ActivityItem.fromJson(above), throwsFormatException);
    });

    test('rejects mismatched Social policy and attention', () {
      final item = ActivityItem.fromJson(
        validActivityItemJson(status: 'cancelled', attention: 'unread'),
      );
      expect(
        () => SocialDevRunTransition.fromItem(item),
        throwsFormatException,
      );
    });

    test('validates all four Social lifecycle variants', () {
      final cases = [
        validActivityItemJson(
          status: 'needs_input',
          facts: {'runMode': 'headless', 'inputKind': 'approval'},
        ),
        validActivityItemJson(
          status: 'succeeded',
          facts: {'runMode': 'scout', 'result': 'no_changes'},
        ),
        validActivityItemJson(
          status: 'failed',
          facts: {
            'runMode': 'build',
            'failureStage': 'preview',
            'artifactsAvailable': true,
            'result': 'spec_code',
          },
        ),
        validActivityItemJson(
          status: 'cancelled',
          runMode: 'headless',
          facts: {
            'runMode': 'headless',
            'cancellationReason': 'superseded',
          },
        ),
      ];

      final statuses = cases
          .map(ActivityItem.fromJson)
          .map(SocialDevRunTransition.fromItem)
          .map((value) => value.status)
          .toList();
      expect(statuses, SocialDevRunStatus.values);
    });

    test('rejects impossible failed and cancellation variants', () {
      final dispatchArtifact = ActivityItem.fromJson(
        validActivityItemJson(
          status: 'failed',
          facts: {
            'runMode': 'build',
            'failureStage': 'dispatch',
            'artifactsAvailable': true,
            'result': 'code',
          },
        ),
      );
      final supersededScout = ActivityItem.fromJson(
        validActivityItemJson(
          status: 'cancelled',
          runMode: 'scout',
          facts: {
            'runMode': 'scout',
            'cancellationReason': 'superseded',
          },
        ),
      );

      expect(
        () => SocialDevRunTransition.fromItem(dispatchArtifact),
        throwsFormatException,
      );
      expect(
        () => SocialDevRunTransition.fromItem(supersededScout),
        throwsFormatException,
      );
    });
  });
}

Map<String, dynamic> _fixture(String name) {
  final file = File('test/features/activity/fixtures/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}
