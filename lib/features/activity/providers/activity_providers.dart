import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/features/activity/application/activity_attention_policy.dart';
import 'package:crypto_mobile_app/features/activity/application/activity_fact_sync_service.dart';
import 'package:crypto_mobile_app/features/activity/application/activity_ingest_service.dart';
import 'package:crypto_mobile_app/features/activity/application/local_notification_presenter.dart';
import 'package:crypto_mobile_app/features/activity/application/mock_activity_event_source.dart';
import 'package:crypto_mobile_app/features/activity/data/activity_record_store.dart';
import 'package:crypto_mobile_app/features/activity/models/activity_models.dart';
import 'package:crypto_mobile_app/features/dapps/providers/dapps_provider.dart';

final activityAttentionPolicyProvider = Provider<ActivityAttentionPolicy>(
  (ref) => const ActivityAttentionPolicy(),
);

final mockActivityEventSourceProvider = Provider<MockActivityEventSource>(
  (ref) => const MockActivityEventSource(),
);

final activityNotificationPresenterProvider =
    Provider<ActivityNotificationPresenter>(
      (ref) => LocalNotificationPresenter(),
    );

final activityRecordStoreProvider = FutureProvider<ActivityRecordStore>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  return ActivityRecordStore(prefs: prefs);
});

final activityIngestServiceProvider = FutureProvider<ActivityIngestService>((
  ref,
) async {
  final store = await ref.watch(activityRecordStoreProvider.future);
  return ActivityIngestService(
    store: store,
    policy: ref.watch(activityAttentionPolicyProvider),
    presenter: ref.watch(activityNotificationPresenterProvider),
  );
});

final productionSetupFactReaderProvider = Provider<ProductionSetupFactReader>(
  (ref) => const PlatformProductionSetupFactReader(),
);

final activityFactSyncServiceProvider = FutureProvider<ActivityFactSyncService>(
  (ref) async {
    final store = await ref.watch(activityRecordStoreProvider.future);
    final ingestService = await ref.watch(activityIngestServiceProvider.future);
    return ActivityFactSyncService(
      store: store,
      ingestService: ingestService,
      presenter: ref.watch(activityNotificationPresenterProvider),
      productionSetupReader: ref.watch(productionSetupFactReaderProvider),
    );
  },
);

final activityControllerProvider =
    AsyncNotifierProvider<ActivityController, List<ActivityRecord>>(
      ActivityController.new,
    );

final activityUnreadCountProvider = Provider<int>((ref) {
  final records = ref.watch(activityControllerProvider).valueOrNull ?? const [];
  return records
      .where(
        (record) =>
            record.unread &&
            !record.archived &&
            record.priority != ActivityPriority.passive,
      )
      .length;
});

class ActivityController extends AsyncNotifier<List<ActivityRecord>> {
  @override
  Future<List<ActivityRecord>> build() async {
    final store = await ref.watch(activityRecordStoreProvider.future);
    var records = await store.loadRecords();
    if (records.isEmpty) {
      final service = await ref.watch(activityIngestServiceProvider.future);
      final source = ref.watch(mockActivityEventSourceProvider);
      records = await service.ingestAll(source.seedEvents());
    }
    return _syncFacts();
  }

  Future<void> refresh() async {
    state = AsyncData(await _syncFacts());
  }

  Future<void> syncFacts() async {
    state = AsyncData(await _syncFacts());
  }

  Future<void> markRead(String id) async {
    final store = await ref.read(activityRecordStoreProvider.future);
    state = AsyncData(await store.markRead(id));
  }

  Future<void> markAllRead() async {
    final store = await ref.read(activityRecordStoreProvider.future);
    state = AsyncData(await store.markAllRead());
  }

  Future<void> archive(String id) async {
    final store = await ref.read(activityRecordStoreProvider.future);
    state = AsyncData(await store.archive(id));
  }

  Future<void> inject(ActivityEvent event) async {
    final service = await ref.read(activityIngestServiceProvider.future);
    state = AsyncData(
      await service.ingest(event, presentSystemNotification: true),
    );
  }

  Future<bool> injectMockNotificationScenario(String key) async {
    final source = ref.read(mockActivityEventSourceProvider);
    final service = await ref.read(activityIngestServiceProvider.future);

    if (key == MockActivityEventSource.clearNotificationScenarioKey) {
      final store = await ref.read(activityRecordStoreProvider.future);
      final presenter = ref.read(activityNotificationPresenterProvider);
      for (final record in await store.loadRecords()) {
        await presenter.cancel(record);
      }
      return true;
    }

    if (key == MockActivityEventSource.resetNotificationScenarioKey) {
      final store = await ref.read(activityRecordStoreProvider.future);
      final presenter = ref.read(activityNotificationPresenterProvider);
      for (final record in await store.loadRecords()) {
        await presenter.cancel(record);
      }
      state = AsyncData(await store.replaceAll(const []));
      return true;
    }

    if (key == MockActivityEventSource.allNotificationScenarioKey) {
      state = AsyncData(
        await service.ingestAll(
          source
              .notificationScenarios(dappSlug: _mockDappSlug())
              .map((scenario) => scenario.event),
        ),
      );
      return true;
    }

    if (key == MockActivityEventSource.priorityStackScenarioKey) {
      final store = await ref.read(activityRecordStoreProvider.future);
      final presenter = ref.read(activityNotificationPresenterProvider);
      for (final record in await store.loadRecords()) {
        await presenter.cancel(record);
      }
      await store.replaceAll(const []);
      final records = await service.ingestAll(source.priorityStackEvents());
      final now = DateTime.now();
      state = AsyncData(
        await store.replaceAll([
          for (final record in records)
            source.isPriorityStackReadReceipt(record)
                ? record.copyWith(readAt: now)
                : record,
        ]),
      );
      return true;
    }

    final scenario = source.notificationScenarioByKey(
      key,
      dappSlug: _mockDappSlug(),
    );
    if (scenario == null) return false;
    state = AsyncData(
      await service.ingest(scenario.event, presentSystemNotification: true),
    );
    return true;
  }

  String _mockDappSlug() {
    final dapps = ref.read(dappsProvider).valueOrNull;
    if (dapps == null || dapps.isEmpty) {
      return MockActivityEventSource.fallbackDappSlug;
    }
    return dapps.first.slug;
  }

  Future<List<ActivityRecord>> _syncFacts() async {
    final service = await ref.read(activityFactSyncServiceProvider.future);
    return service.syncAvailableFacts(
      challenges: ref.read(challengesProvider).valueOrNull,
      breakdown: ref.read(breakdownProvider).valueOrNull,
    );
  }
}

final activityRecordByIdProvider = Provider.family<ActivityRecord?, String>((
  ref,
  id,
) {
  final records = ref.watch(activityControllerProvider).valueOrNull;
  if (records == null) return null;
  for (final record in records) {
    if (record.id == id) return record;
  }
  return null;
});
