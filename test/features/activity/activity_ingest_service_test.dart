import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/features/activity/application/activity_attention_policy.dart';
import 'package:crypto_mobile_app/features/activity/application/activity_ingest_service.dart';
import 'package:crypto_mobile_app/features/activity/data/activity_record_store.dart';
import 'package:crypto_mobile_app/features/activity/models/activity_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('dApp OS presentation requires deterministic dedupe', () async {
    final harness = await _Harness.create();

    final records = await harness.service.ingest(
      const ActivityEvent(
        source: ActivitySource.dapp,
        category: ActivityCategory.dappFeedback,
        eventType: 'approval_needed',
        title: 'Approval requested',
        body: 'A dApp proposal needs review.',
        priority: ActivityPriority.attention,
        targetRoute: '/dapps',
      ),
      presentSystemNotification: true,
    );

    expect(records, hasLength(1));
    expect(harness.presenter.presented, isEmpty);
  });

  test(
    'dApp OS presentation is rate-limited without dropping records',
    () async {
      final harness = await _Harness.create();

      for (var i = 0; i < 4; i++) {
        await harness.service.ingest(
          ActivityEvent(
            source: ActivitySource.dapp,
            category: ActivityCategory.dappFeedback,
            eventType: 'approval_needed',
            title: 'Approval requested $i',
            body: 'A dApp proposal needs review.',
            priority: ActivityPriority.attention,
            dedupeKey: 'dapp:builder-board:approval:$i',
            targetRoute: '/dapps/builder-board',
            payload: const {'dappName': 'Builder Board'},
          ),
          presentSystemNotification: true,
        );
      }

      final records = await harness.store.loadRecords();
      expect(records, hasLength(4));
      expect(
        harness.presenter.presented,
        hasLength(ActivityIngestService.dappPresentationRateLimitCount),
      );
    },
  );
}

class _Harness {
  _Harness({
    required this.service,
    required this.store,
    required this.presenter,
  });

  final ActivityIngestService service;
  final ActivityRecordStore store;
  final _FakePresenter presenter;

  static Future<_Harness> create() async {
    final prefs = await SharedPreferences.getInstance();
    final store = ActivityRecordStore(prefs: prefs);
    final presenter = _FakePresenter();
    return _Harness(
      store: store,
      presenter: presenter,
      service: ActivityIngestService(
        store: store,
        policy: const ActivityAttentionPolicy(),
        presenter: presenter,
      ),
    );
  }
}

class _FakePresenter implements ActivityNotificationPresenter {
  final presented = <ActivityRecord>[];

  @override
  Future<void> show(ActivityRecord record) async {
    presented.add(record);
  }

  @override
  Future<void> cancel(ActivityRecord record) async {}
}
