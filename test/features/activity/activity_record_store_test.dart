import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/features/activity/data/activity_record_store.dart';
import 'package:crypto_mobile_app/features/activity/models/activity_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('orders pinned records first and newest records next', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = ActivityRecordStore(prefs: prefs);
    final now = DateTime(2026, 6, 19, 12);

    await store.upsert(
      _record('older', now.subtract(const Duration(hours: 2))),
    );
    await store.upsert(_record('newer', now));
    await store.upsert(
      _record('pinned', now.subtract(const Duration(days: 1)), pinned: true),
    );

    final records = await store.loadRecords();

    expect(records.map((record) => record.id), ['pinned', 'newer', 'older']);
  });

  test('dedupes records by dedupeKey', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = ActivityRecordStore(prefs: prefs);
    final now = DateTime(2026, 6, 19, 12);

    await store.upsert(_record('first', now, dedupeKey: 'same'));
    await store.upsert(
      _record(
        'second',
        now.add(const Duration(minutes: 1)),
        dedupeKey: 'same',
        title: 'Updated',
      ),
    );

    final records = await store.loadRecords();

    expect(records, hasLength(1));
    expect(records.single.id, 'second');
    expect(records.single.title, 'Updated');
  });

  test('marks records read and archived', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = ActivityRecordStore(prefs: prefs);

    await store.upsert(_record('a', DateTime(2026, 6, 19, 12)));
    final read = await store.markRead('a');
    final archived = await store.archive('a');

    expect(read.single.readAt, isNotNull);
    expect(archived.single.archivedAt, isNotNull);
  });
}

ActivityRecord _record(
  String id,
  DateTime createdAt, {
  bool pinned = false,
  String? dedupeKey,
  String title = 'Title',
}) {
  return ActivityRecord(
    id: id,
    source: ActivitySource.mock,
    category: ActivityCategory.challengePromotion,
    eventType: 'test',
    title: title,
    body: 'Body',
    createdAt: createdAt,
    priority: pinned ? ActivityPriority.persistent : ActivityPriority.standard,
    pinned: pinned,
    dedupeKey: dedupeKey,
    targetRoute: '/activity',
  );
}
