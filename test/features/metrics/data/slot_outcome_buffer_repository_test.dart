import 'package:crypto_mobile_app/features/metrics/data/slot_outcome_buffer_repository.dart';
import 'package:crypto_mobile_app/features/metrics/models/slot_outcome_report.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SlotOutcomeReport _report({
  required int globalSlot,
  required int capturedAtMs,
  SlotOutcomeKind outcome = SlotOutcomeKind.produced,
}) {
  return SlotOutcomeReport(
    id: SlotOutcomeReport.buildId(globalSlot, capturedAtMs),
    capturedAtMs: capturedAtMs,
    globalSlot: globalSlot,
    outcome: outcome,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Ensure each test starts with an empty buffer; the singleton instance
    // is shared but the underlying prefs are reset by setMockInitialValues.
    await SlotOutcomeBufferRepository.instance.clearAll();
  });

  group('SlotOutcomeBufferRepository', () {
    test('append + drain roundtrips a single report', () async {
      final repo = SlotOutcomeBufferRepository.instance;
      await repo.append(_report(globalSlot: 1, capturedAtMs: 100));

      final pending = await repo.drain();
      expect(pending, hasLength(1));
      expect(pending.first.globalSlot, 1);
      expect(pending.first.outcome, SlotOutcomeKind.produced);
    });

    test('append is idempotent on id (last write wins)', () async {
      final repo = SlotOutcomeBufferRepository.instance;
      await repo.append(_report(globalSlot: 1, capturedAtMs: 100));
      await repo.append(
        _report(
          globalSlot: 1,
          capturedAtMs: 100,
          outcome: SlotOutcomeKind.monitoringTimeout,
        ),
      );

      final pending = await repo.drain();
      expect(pending, hasLength(1));
      expect(pending.first.outcome, SlotOutcomeKind.monitoringTimeout);
    });

    test('drain does not remove records — discard does', () async {
      final repo = SlotOutcomeBufferRepository.instance;
      await repo.append(_report(globalSlot: 1, capturedAtMs: 100));
      await repo.append(_report(globalSlot: 2, capturedAtMs: 200));

      final firstDrain = await repo.drain();
      expect(firstDrain, hasLength(2));

      // Drain again without discard: still both present.
      expect(await repo.drain(), hasLength(2));

      await repo.discard([firstDrain.first.id]);
      final remaining = await repo.drain();
      expect(remaining, hasLength(1));
      expect(remaining.single.id, firstDrain.last.id);
    });

    test(
      'discard between drain and ship leaves only un-shipped records',
      () async {
        final repo = SlotOutcomeBufferRepository.instance;
        // Sim: shipping batch [A, B] while [C] arrives concurrently.
        final a = _report(globalSlot: 1, capturedAtMs: 100);
        final b = _report(globalSlot: 2, capturedAtMs: 200);
        await repo.append(a);
        await repo.append(b);

        final shipped = await repo.drain();
        // Concurrent append between drain and POST success.
        await repo.append(_report(globalSlot: 3, capturedAtMs: 300));

        // Discard only what was actually shipped.
        await repo.discard(shipped.map((r) => r.id));

        final remaining = await repo.drain();
        expect(remaining, hasLength(1));
        expect(remaining.single.globalSlot, 3);
      },
    );

    test('persists across an instance restart (via prefs reload)', () async {
      final repo = SlotOutcomeBufferRepository.instance;
      await repo.append(_report(globalSlot: 42, capturedAtMs: 1700));

      // Simulate restart by reading via a fresh getInstance() — the prefs
      // singleton survives, but the buffer reads through it on every call.
      final reloaded = await repo.drain();
      expect(reloaded, hasLength(1));
      expect(reloaded.single.globalSlot, 42);
    });

    test('trims oldest when buffer exceeds cap (200)', () async {
      final repo = SlotOutcomeBufferRepository.instance;
      // 250 entries with monotonically increasing capturedAtMs so the
      // 50 oldest get trimmed, leaving slots [50..249].
      for (var i = 0; i < 250; i++) {
        await repo.append(_report(globalSlot: i, capturedAtMs: 1000 + i));
      }

      final pending = await repo.drain();
      expect(pending, hasLength(200));
      final slots = pending.map((r) => r.globalSlot).toSet();
      expect(slots.contains(0), isFalse);
      expect(slots.contains(49), isFalse);
      expect(slots.contains(50), isTrue);
      expect(slots.contains(249), isTrue);
    });

    test('discard with empty id set is a no-op', () async {
      final repo = SlotOutcomeBufferRepository.instance;
      await repo.append(_report(globalSlot: 1, capturedAtMs: 100));
      await repo.discard(const <String>[]);
      expect(await repo.drain(), hasLength(1));
    });

    test('clearAll empties everything', () async {
      final repo = SlotOutcomeBufferRepository.instance;
      await repo.append(_report(globalSlot: 1, capturedAtMs: 100));
      await repo.append(_report(globalSlot: 2, capturedAtMs: 200));

      await repo.clearAll();

      expect(await repo.drain(), isEmpty);
    });
  });
}
