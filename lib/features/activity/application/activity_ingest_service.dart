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
    DateTime Function()? now,
  }) : _store = store,
       _policy = policy,
       _presenter = presenter,
       _now = now ?? DateTime.now;

  final ActivityRecordStore _store;
  final ActivityAttentionPolicy _policy;
  final ActivityNotificationPresenter _presenter;
  final DateTime Function() _now;
  final _dappPresentationHistory = <String, List<DateTime>>{};

  static const dappPresentationRateLimitWindow = Duration(minutes: 5);
  static const dappPresentationRateLimitCount = 3;

  Future<List<ActivityRecord>> ingest(
    ActivityEvent event, {
    bool presentSystemNotification = false,
  }) async {
    final record = _policy.recordFor(event);
    final records = await _store.upsert(record);

    if (presentSystemNotification &&
        _policy.shouldPresentSystemNotification(record) &&
        _canPresentSystemNotification(record)) {
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

  bool _canPresentSystemNotification(ActivityRecord record) {
    if (record.source != ActivitySource.dapp) return true;
    if (record.dedupeKey == null || record.dedupeKey!.trim().isEmpty) {
      return false;
    }

    final key = _dappRateLimitKey(record);
    final now = _now();
    final cutoff = now.subtract(dappPresentationRateLimitWindow);
    final history = _dappPresentationHistory.putIfAbsent(key, () => []);
    history.removeWhere((shownAt) => shownAt.isBefore(cutoff));
    if (history.length >= dappPresentationRateLimitCount) return false;
    history.add(now);
    return true;
  }

  String _dappRateLimitKey(ActivityRecord record) {
    final dappName = record.payloadJson['dappName']?.toString().trim();
    if (dappName != null && dappName.isNotEmpty) return dappName;
    final route = record.targetRoute?.trim();
    if (route != null && route.isNotEmpty) return route;
    return 'dapp';
  }
}
