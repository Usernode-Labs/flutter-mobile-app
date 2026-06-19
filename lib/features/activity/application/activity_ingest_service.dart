import 'package:crypto_mobile_app/features/activity/application/activity_attention_policy.dart';
import 'package:crypto_mobile_app/features/activity/data/activity_record_store.dart';
import 'package:crypto_mobile_app/features/activity/models/activity_models.dart';

abstract class ActivityNotificationPresenter {
  Future<void> show(ActivityRecord record);

  Future<void> cancel(ActivityRecord record);
}

class NoopActivityNotificationPresenter
    implements ActivityNotificationPresenter {
  const NoopActivityNotificationPresenter();

  @override
  Future<void> show(ActivityRecord record) async {}

  @override
  Future<void> cancel(ActivityRecord record) async {}
}

class ActivityIngestService {
  ActivityIngestService({
    required ActivityRecordStore store,
    required ActivityAttentionPolicy policy,
    required ActivityNotificationPresenter presenter,
  }) : _store = store,
       _policy = policy,
       _presenter = presenter;

  final ActivityRecordStore _store;
  final ActivityAttentionPolicy _policy;
  final ActivityNotificationPresenter _presenter;

  Future<List<ActivityRecord>> ingest(
    ActivityEvent event, {
    bool presentSystemNotification = false,
  }) async {
    final record = _policy.recordFor(event);
    final records = await _store.upsert(record);

    if (presentSystemNotification &&
        _policy.shouldPresentSystemNotification(record)) {
      await _presenter.show(record);
    }

    return records;
  }

  Future<List<ActivityRecord>> ingestAll(
    Iterable<ActivityEvent> events, {
    bool presentSystemNotifications = false,
  }) async {
    var records = await _store.loadRecords();
    for (final event in events) {
      records = await ingest(
        event,
        presentSystemNotification: presentSystemNotifications,
      );
    }
    return records;
  }
}
