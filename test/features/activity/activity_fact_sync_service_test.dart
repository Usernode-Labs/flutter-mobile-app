import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/features/activity/application/activity_attention_policy.dart';
import 'package:crypto_mobile_app/features/activity/application/activity_fact_sync_service.dart';
import 'package:crypto_mobile_app/features/activity/application/activity_ingest_service.dart';
import 'package:crypto_mobile_app/features/activity/data/activity_record_store.dart';
import 'package:crypto_mobile_app/features/activity/models/activity_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'sync creates one pinned setup record for missing platform facts',
    () async {
      final harness = await _Harness.create(
        facts: const ProductionSetupFacts(
          notificationsEnabled: false,
          exactAlarmsEnabled: true,
          batteryOptimizationDisabled: false,
        ),
      );

      final first = await harness.service.syncProductionSetupFacts();
      final second = await harness.service.syncProductionSetupFacts();

      expect(
        first.where((record) => record.dedupeKey == productionSetupDedupeKey),
        hasLength(1),
      );
      expect(
        second.where((record) => record.dedupeKey == productionSetupDedupeKey),
        hasLength(1),
      );

      final record = second.firstWhere(
        (record) => record.dedupeKey == productionSetupDedupeKey,
      );
      expect(record.pinned, isTrue);
      expect(record.priority, ActivityPriority.persistent);
      expect(record.category, ActivityCategory.productionSetup);
      expect(record.targetRoute, '/profile/settings');
      expect(record.payloadJson['missingFacts'], [
        'notifications',
        'battery_optimization',
      ]);
    },
  );

  test(
    'sync archives setup record when all required facts are healthy',
    () async {
      final reader = _FakeProductionSetupReader(
        const ProductionSetupFacts(
          notificationsEnabled: false,
          exactAlarmsEnabled: false,
          batteryOptimizationDisabled: true,
        ),
      );
      final harness = await _Harness.create(reader: reader);

      await harness.service.syncProductionSetupFacts();
      reader.facts = const ProductionSetupFacts(
        notificationsEnabled: true,
        exactAlarmsEnabled: true,
        batteryOptimizationDisabled: true,
      );
      final records = await harness.service.syncProductionSetupFacts();

      final record = records.firstWhere(
        (record) => record.dedupeKey == productionSetupDedupeKey,
      );
      expect(record.archived, isTrue);
      expect(harness.presenter.cancelled, hasLength(1));
    },
  );

  test(
    'challenge sync emits only facts backed by existing challenge data',
    () async {
      final now = DateTime(2026, 6, 22, 12);
      final harness = await _Harness.create(now: () => now);

      final records = await harness.service.syncChallengeRewardFacts(
        challenges: [
          ChallengeDto(
            id: 7,
            category: 'community',
            goal: 'Give Kudos',
            task: 'Give Kudos to another participant.',
            reward: '10 pts',
            scheduleStart: now
                .subtract(const Duration(hours: 2))
                .toIso8601String(),
            scheduleEnd: now.add(const Duration(hours: 6)).toIso8601String(),
            enabled: true,
            completed: false,
          ),
        ],
        breakdown: const BreakdownResult(
          scope: 'event',
          displayName: 'Event',
          totalPoints: 0,
          offchainPoints: 0,
          challengeProgress: [
            ChallengeProgress(
              challengeId: 7,
              state: ChallengeProgressState.pending,
              pendingPoints: 10,
            ),
          ],
        ),
      );

      expect(
        records.map((record) => record.dedupeKey),
        containsAll([
          'challenge:7:visible',
          'challenge:7:deadline:2026-06-22',
          'reward:7:pending',
        ]),
      );
      expect(
        records.map((record) => record.body),
        isNot(contains(contains('kudos left'))),
      );
    },
  );

  test(
    'challenge sync does not invent reward records without progress facts',
    () async {
      final now = DateTime(2026, 6, 22, 12);
      final harness = await _Harness.create(now: () => now);

      final records = await harness.service.syncChallengeRewardFacts(
        challenges: [
          ChallengeDto(
            id: 11,
            category: 'community',
            goal: 'Review dApps',
            task: 'Review a dApp.',
            reward: '5 pts',
            scheduleStart: now
                .subtract(const Duration(days: 2))
                .toIso8601String(),
            scheduleEnd: now.add(const Duration(days: 2)).toIso8601String(),
            enabled: true,
            completed: false,
          ),
        ],
      );

      expect(
        records.where((record) => record.source == ActivitySource.reward),
        isEmpty,
      );
    },
  );
}

class _Harness {
  _Harness({required this.service, required this.presenter});

  final ActivityFactSyncService service;
  final _FakePresenter presenter;

  static Future<_Harness> create({
    ProductionSetupFacts? facts,
    _FakeProductionSetupReader? reader,
    DateTime Function()? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final store = ActivityRecordStore(prefs: prefs);
    final presenter = _FakePresenter();
    final ingestService = ActivityIngestService(
      store: store,
      policy: const ActivityAttentionPolicy(),
      presenter: presenter,
      now: now,
    );
    final factReader =
        reader ??
        _FakeProductionSetupReader(
          facts ??
              const ProductionSetupFacts(
                notificationsEnabled: true,
                exactAlarmsEnabled: true,
                batteryOptimizationDisabled: true,
              ),
        );

    return _Harness(
      service: ActivityFactSyncService(
        store: store,
        ingestService: ingestService,
        presenter: presenter,
        productionSetupReader: factReader,
        now: now,
      ),
      presenter: presenter,
    );
  }
}

class _FakeProductionSetupReader implements ProductionSetupFactReader {
  _FakeProductionSetupReader(this.facts);

  ProductionSetupFacts facts;

  @override
  Future<ProductionSetupFacts> read() async => facts;
}

class _FakePresenter implements ActivityNotificationPresenter {
  final cancelled = <ActivityRecord>[];

  @override
  Future<void> show(ActivityRecord record) async {}

  @override
  Future<void> cancel(ActivityRecord record) async {
    cancelled.add(record);
  }
}
