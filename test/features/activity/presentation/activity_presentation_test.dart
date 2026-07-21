import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/activity/data/models/activity_models.dart';
import 'package:crypto_mobile_app/features/activity/presentation/activity_presentation.dart';

import '../activity_test_fixtures.dart';

void main() {
  group('ActivityFeedEntry', () {
    test('uses neutral copy for an unknown service-valid contract', () {
      final entry = ActivityFeedEntry.fromItem(
        ActivityItem.fromJson(validGenericActivityItemJson()),
      );

      expect(entry.isGeneric, isTrue);
      expect(entry.transition, isNull);
      expect(entry.titleCopy, ActivityTitleCopy.generic);
      expect(entry.bodyCopy, ActivityBodyCopy.generic);
      expect(entry.isUnread, isTrue);
    });

    test('still strictly validates the known dev-run contract', () {
      final item = validActivityItemJson();
      final event = item['activityEvent']! as Map<String, dynamic>;
      final sourceEvent = event['sourceEvent']! as Map<String, dynamic>;
      sourceEvent['facts'] = {'privatePreview': 'not a dev-run fact'};

      expect(
        () => ActivityFeedEntry.fromItem(ActivityItem.fromJson(item)),
        throwsFormatException,
      );
    });

    test('maps every run mode and status to a closed title case', () {
      final cases = <({String status, String mode, ActivityTitleCopy copy})>[
        (
          status: 'needs_input',
          mode: 'scout',
          copy: ActivityTitleCopy.scoutNeedsInput,
        ),
        (
          status: 'needs_input',
          mode: 'build',
          copy: ActivityTitleCopy.buildNeedsInput,
        ),
        (
          status: 'needs_input',
          mode: 'headless',
          copy: ActivityTitleCopy.headlessNeedsInput,
        ),
        (
          status: 'succeeded',
          mode: 'scout',
          copy: ActivityTitleCopy.scoutSucceeded,
        ),
        (
          status: 'succeeded',
          mode: 'build',
          copy: ActivityTitleCopy.buildSucceeded,
        ),
        (
          status: 'succeeded',
          mode: 'headless',
          copy: ActivityTitleCopy.headlessSucceeded,
        ),
        (
          status: 'failed',
          mode: 'scout',
          copy: ActivityTitleCopy.scoutFailed,
        ),
        (
          status: 'failed',
          mode: 'build',
          copy: ActivityTitleCopy.buildFailed,
        ),
        (
          status: 'failed',
          mode: 'headless',
          copy: ActivityTitleCopy.headlessFailed,
        ),
        (
          status: 'cancelled',
          mode: 'scout',
          copy: ActivityTitleCopy.scoutCancelled,
        ),
        (
          status: 'cancelled',
          mode: 'build',
          copy: ActivityTitleCopy.buildCancelled,
        ),
        (
          status: 'cancelled',
          mode: 'headless',
          copy: ActivityTitleCopy.headlessCancelled,
        ),
      ];

      for (final testCase in cases) {
        final entry = _entry(
          status: testCase.status,
          mode: testCase.mode,
        );
        expect(
          entry.titleCopy,
          testCase.copy,
          reason: '${testCase.mode} ${testCase.status}',
        );
      }
    });

    test('maps every valid status fact combination to a closed body case', () {
      final cases = <({
        String status,
        String mode,
        Map<String, dynamic> facts,
        ActivityBodyCopy copy,
      })>[
        for (final input in const [
          ('clarification', ActivityBodyCopy.needsClarification),
          ('decision', ActivityBodyCopy.needsDecision),
          ('approval', ActivityBodyCopy.needsApproval),
        ])
          (
            status: 'needs_input',
            mode: 'build',
            facts: {'runMode': 'build', 'inputKind': input.$1},
            copy: input.$2,
          ),
        for (final result in const [
          ('spec', ActivityBodyCopy.succeededSpec),
          ('code', ActivityBodyCopy.succeededCode),
          ('spec_code', ActivityBodyCopy.succeededSpecCode),
          ('no_changes', ActivityBodyCopy.succeededNoChanges),
        ])
          (
            status: 'succeeded',
            mode: 'build',
            facts: {'runMode': 'build', 'result': result.$1},
            copy: result.$2,
          ),
        (
          status: 'failed',
          mode: 'build',
          facts: {
            'runMode': 'build',
            'failureStage': 'dispatch',
            'artifactsAvailable': false,
          },
          copy: ActivityBodyCopy.failedDispatchNoArtifacts,
        ),
        (
          status: 'failed',
          mode: 'build',
          facts: {
            'runMode': 'build',
            'failureStage': 'execution',
            'artifactsAvailable': false,
          },
          copy: ActivityBodyCopy.failedExecutionNoArtifacts,
        ),
        for (final failure in const [
          ('execution', 'spec', ActivityBodyCopy.failedExecutionSpec),
          ('execution', 'code', ActivityBodyCopy.failedExecutionCode),
          (
            'execution',
            'spec_code',
            ActivityBodyCopy.failedExecutionSpecCode,
          ),
          ('staging', 'spec', ActivityBodyCopy.failedStagingSpec),
          ('staging', 'code', ActivityBodyCopy.failedStagingCode),
          ('staging', 'spec_code', ActivityBodyCopy.failedStagingSpecCode),
          ('preview', 'spec', ActivityBodyCopy.failedPreviewSpec),
          ('preview', 'code', ActivityBodyCopy.failedPreviewCode),
          ('preview', 'spec_code', ActivityBodyCopy.failedPreviewSpecCode),
        ])
          (
            status: 'failed',
            mode: 'build',
            facts: {
              'runMode': 'build',
              'failureStage': failure.$1,
              'artifactsAvailable': true,
              'result': failure.$2,
            },
            copy: failure.$3,
          ),
        (
          status: 'cancelled',
          mode: 'build',
          facts: {
            'runMode': 'build',
            'cancellationReason': 'explicit_stop',
          },
          copy: ActivityBodyCopy.cancelledExplicitStop,
        ),
        (
          status: 'cancelled',
          mode: 'headless',
          facts: {
            'runMode': 'headless',
            'cancellationReason': 'superseded',
          },
          copy: ActivityBodyCopy.cancelledSuperseded,
        ),
      ];

      for (final testCase in cases) {
        final entry = _entry(
          status: testCase.status,
          mode: testCase.mode,
          facts: testCase.facts,
        );
        expect(entry.bodyCopy, testCase.copy, reason: '${testCase.facts}');
      }
    });
  });

  test('relative time uses stable minute, hour, and day boundaries', () {
    final now = DateTime.utc(2026, 7, 20, 12);
    final cases = <({Duration age, ActivityRelativeTimeUnit unit, int value})>[
      (
        age: const Duration(seconds: -5),
        unit: ActivityRelativeTimeUnit.now,
        value: 0,
      ),
      (
        age: const Duration(seconds: 59),
        unit: ActivityRelativeTimeUnit.now,
        value: 0,
      ),
      (
        age: const Duration(minutes: 1),
        unit: ActivityRelativeTimeUnit.minutes,
        value: 1,
      ),
      (
        age: const Duration(minutes: 59),
        unit: ActivityRelativeTimeUnit.minutes,
        value: 59,
      ),
      (
        age: const Duration(hours: 1),
        unit: ActivityRelativeTimeUnit.hours,
        value: 1,
      ),
      (
        age: const Duration(hours: 23),
        unit: ActivityRelativeTimeUnit.hours,
        value: 23,
      ),
      (
        age: const Duration(days: 1),
        unit: ActivityRelativeTimeUnit.days,
        value: 1,
      ),
      (
        age: const Duration(days: 9),
        unit: ActivityRelativeTimeUnit.days,
        value: 9,
      ),
    ];

    for (final testCase in cases) {
      final relative = activityRelativeTime(now.subtract(testCase.age), now);
      expect(relative.unit, testCase.unit, reason: '${testCase.age}');
      expect(relative.value, testCase.value, reason: '${testCase.age}');
    }
  });
}

ActivityFeedEntry _entry({
  required String status,
  required String mode,
  Map<String, dynamic>? facts,
}) {
  return ActivityFeedEntry.fromItem(
    ActivityItem.fromJson(
      validActivityItemJson(status: status, runMode: mode, facts: facts),
    ),
  );
}
