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
    test('write path records slots without throwing and clears state',
        () async {
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
      await repo.recordProductionSuccess(
          slotNumber: 1, blockHeight: 100, producedTime: t1);
      await repo.recordProductionFailure(
          slotNumber: 2, failedTime: t2, reason: 'missed');

      // Records are persisted (under a network-prefixed key) on each write.
      final prefs = await SharedPreferences.getInstance();
      bool hasRecordsKey() => prefs
          .getKeys()
          .any((k) => k.endsWith('slot_production_records'));
      expect(hasRecordsKey(), isTrue);

      await repo.clearAll();
      expect(hasRecordsKey(), isFalse);
    });
  });
}
