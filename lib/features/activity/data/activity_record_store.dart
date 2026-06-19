import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/activity/models/activity_models.dart';

class ActivityRecordStore {
  ActivityRecordStore({required SharedPreferences prefs, int maxRecords = 200})
    : _prefs = prefs,
      _maxRecords = maxRecords;

  static const _recordsKeyBase = 'activity:records';

  final SharedPreferences _prefs;
  final int _maxRecords;

  String get _recordsKey => NetworkPrefs.prefixKey(_recordsKeyBase);

  Future<List<ActivityRecord>> loadRecords() async {
    final encoded = _prefs.getStringList(_recordsKey) ?? const [];
    final records = <ActivityRecord>[];

    for (final value in encoded) {
      try {
        records.add(ActivityRecord.decode(value));
      } catch (_) {
        // Ignore malformed historical rows. The ledger must stay readable.
      }
    }

    final visible = records.where((record) => !record.expired).toList();
    final sorted = _sort(visible);
    if (sorted.length != encoded.length) {
      await _saveAll(sorted);
    }
    return sorted;
  }

  Future<List<ActivityRecord>> upsert(ActivityRecord record) async {
    final records = await loadRecords();
    final index = records.indexWhere((existing) {
      if (record.dedupeKey != null && existing.dedupeKey == record.dedupeKey) {
        return true;
      }
      return existing.id == record.id;
    });

    final next = [...records];
    if (index >= 0) {
      next[index] = record;
    } else {
      next.add(record);
    }

    final sorted = _sort(next).take(_maxRecords).toList();
    await _saveAll(sorted);
    return sorted;
  }

  Future<List<ActivityRecord>> markRead(String id) async {
    final now = DateTime.now();
    final records = await loadRecords();
    final next = [
      for (final record in records)
        record.id == id && record.readAt == null
            ? record.copyWith(readAt: now)
            : record,
    ];
    await _saveAll(next);
    return next;
  }

  Future<List<ActivityRecord>> markAllRead() async {
    final now = DateTime.now();
    final records = await loadRecords();
    final next = [
      for (final record in records)
        record.readAt == null ? record.copyWith(readAt: now) : record,
    ];
    await _saveAll(next);
    return next;
  }

  Future<List<ActivityRecord>> archive(String id) async {
    final now = DateTime.now();
    final records = await loadRecords();
    final next = [
      for (final record in records)
        record.id == id ? record.copyWith(archivedAt: now) : record,
    ];
    await _saveAll(next);
    return next;
  }

  Future<List<ActivityRecord>> replaceAll(List<ActivityRecord> records) async {
    final sorted = _sort(records).take(_maxRecords).toList();
    await _saveAll(sorted);
    return sorted;
  }

  Future<void> _saveAll(List<ActivityRecord> records) async {
    await _prefs.setStringList(_recordsKey, [
      for (final record in records) record.encode(),
    ]);
  }

  static List<ActivityRecord> _sort(List<ActivityRecord> records) {
    return [...records]..sort((a, b) {
      final pinned = _compareBool(
        b.pinned && !b.archived,
        a.pinned && !a.archived,
      );
      if (pinned != 0) return pinned;
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  static int _compareBool(bool left, bool right) {
    if (left == right) return 0;
    return left ? 1 : -1;
  }
}
