import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/data/slot_production_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SlotProductionRecord', () {
    SlotProductionRecord rec() => SlotProductionRecord(
          slotNumber: 5,
          epoch: 2,
          slotTime: DateTime.utc(2024, 1, 1),
          recordedAt: DateTime.utc(2024, 1, 1, 0, 0, 1),
          status: SlotProductionStatus.won,
        );

    test('copyWith updates status/timings, keeps identity fields', () {
      final r = rec().copyWith(
        status: SlotProductionStatus.produced,
        blockHeight: 99,
        producedTime: DateTime.utc(2024, 1, 1, 1),
      );
      expect(r.status, SlotProductionStatus.produced);
      expect(r.blockHeight, 99);
      expect(r.slotNumber, 5);
      expect(r.epoch, 2);
    });

    test('toJson/fromJson round-trips including optional fields', () {
      final r = rec().copyWith(
        status: SlotProductionStatus.failed,
        failedTime: DateTime.utc(2024, 1, 1, 2),
        failureReason: 'timeout',
      );
      final back = SlotProductionRecord.fromJson(r.toJson());
      expect(back.slotNumber, 5);
      expect(back.status, SlotProductionStatus.failed);
      expect(back.failureReason, 'timeout');
      expect(back.failedTime, r.failedTime);
      expect(back.attemptTime, isNull);
    });
  });

  group('SlotProductionStats', () {
    test('toJson/fromJson round-trip and toString', () {
      final s = SlotProductionStats(
        totalWonSlots: 4,
        totalProduced: 3,
        totalFailed: 1,
        totalAttempted: 4,
        successRate: 75.0,
        lastUpdated: DateTime.utc(2024, 1, 2),
      );
      final back = SlotProductionStats.fromJson(s.toJson());
      expect(back.totalWonSlots, 4);
      expect(back.successRate, 75.0);
      expect(s.toString(), contains('rate: 75.0%'));
    });
  });

  group('SlotProductionRepository lifecycle', () {
    test('records won/produced/failed slots and computes stats', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SlotProductionRepository.instance;
      await repo.clearAll(); // reset singleton in-memory state
      expect(await repo.initialize(), isTrue);
      // second initialize is a no-op fast path
      expect(await repo.initialize(), isTrue);

      final t1 = DateTime.utc(2024, 1, 1, 10);
      final t2 = DateTime.utc(2024, 1, 1, 11);
      await repo.recordWonSlot(slotNumber: 1, epoch: 7, slotTime: t1);
      await repo.recordWonSlot(slotNumber: 2, epoch: 7, slotTime: t2);

      // Attempt on a slot with no won record just warns (no throw).
      await repo.recordProductionAttempt(
          slotNumber: 999, attemptTime: DateTime.utc(2024, 1, 1, 9));

      await repo.recordProductionSuccess(
          slotNumber: 1, blockHeight: 100, producedTime: t1);
      await repo.recordProductionFailure(
          slotNumber: 2, failedTime: t2, reason: 'missed');

      expect(repo.getAllRecords(), hasLength(2));
      expect(repo.getRecordsForEpoch(7), hasLength(2));
      expect(repo.getRecordsForEpoch(0), isEmpty);

      // Recent records are newest-first by slotTime.
      final recent = repo.getRecentRecords(limit: 1);
      expect(recent, hasLength(1));
      expect(recent.first.slotNumber, 2);

      final stats = repo.getStats();
      expect(stats.totalWonSlots, 2);
      expect(stats.totalAttempted, 2);
      expect(stats.totalProduced, 1);
      expect(stats.totalFailed, 1);
      expect(stats.successRate, closeTo(50.0, 1e-9));

      // Clearing records older than a future cutoff removes everything.
      await repo.clearOldRecords(DateTime.utc(2025));
      expect(repo.getAllRecords(), isEmpty);

      await repo.clearAll();
      expect(repo.getStats().totalWonSlots, 0);
    });
  });
}
