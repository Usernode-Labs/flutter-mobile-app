import 'package:crypto_mobile_app/features/metrics/models/slot_outcome_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SlotOutcomeReport', () {
    test('JSON roundtrips with full field set', () {
      const report = SlotOutcomeReport(
        id: '12345:1700000000000',
        capturedAtMs: 1700000000000,
        globalSlot: 12345,
        epoch: 7,
        slotInEpoch: 25,
        slotTimeMs: 1699999999000,
        chainId: 'usernet-alpha',
        walletAddress: 'ut1abc',
        outcome: SlotOutcomeKind.produced,
        outcomeReason: null,
        blockHash: '0xdead',
        blockHeight: 999,
        canonical: true,
        producedAtMs: 1700000000200,
        flowOutcome: 'block_injected',
        terminalStage: 'inject',
        discardReason: null,
        buildMs: 12,
        dbDiffMs: 34,
        signMs: 56,
        injectMs: 78,
        batchFetchMs: 90,
        hydrationVisibleMs: 100,
        appState: 'foreground',
        networkType: 'wifi',
        networkConnected: true,
        platform: 'android',
        platformVersion: '14',
        appVersion: '1.2.3',
        appBuildNumber: '456',
        batteryLevel: 87,
        wakelockHeld: true,
        foregroundServiceRunning: true,
        alarmScheduledAtMs: 1699999998000,
        alarmFiredAtMs: 1699999999500,
        monitoringStartedAtMs: 1699999999700,
      );

      final decoded = SlotOutcomeReport.fromJson(report.toJson());

      expect(decoded.id, report.id);
      expect(decoded.globalSlot, 12345);
      expect(decoded.epoch, 7);
      expect(decoded.outcome, SlotOutcomeKind.produced);
      expect(decoded.canonical, true);
      expect(decoded.flowOutcome, 'block_injected');
      expect(decoded.terminalStage, 'inject');
      expect(decoded.appState, 'foreground');
      expect(decoded.networkType, 'wifi');
      expect(decoded.batteryLevel, 87);
      expect(decoded.alarmScheduledAtMs, 1699999998000);
      expect(decoded.injectMs, 78);
    });

    test('omits null fields from JSON to keep payload tight', () {
      const report = SlotOutcomeReport(
        id: '1:2',
        capturedAtMs: 2,
        globalSlot: 1,
        outcome: SlotOutcomeKind.monitoringTimeout,
        outcomeReason: 'Monitoring timeout',
      );

      final json = report.toJson();

      expect(json.containsKey('global_slot'), isTrue);
      expect(json.containsKey('outcome'), isTrue);
      expect(json.containsKey('outcome_reason'), isTrue);
      expect(json.containsKey('epoch'), isFalse);
      expect(json.containsKey('block_hash'), isFalse);
      expect(json.containsKey('flow_outcome'), isFalse);
      expect(json.containsKey('app_state'), isFalse);
      expect(json.containsKey('alarm_scheduled_at_ms'), isFalse);
    });

    test('outcome wire format pins backend contract', () {
      // Pinning these exact strings prevents accidental rename of an enum
      // variant from breaking the topochain consumer.
      final outcomes = {
        SlotOutcomeKind.produced: 'produced',
        SlotOutcomeKind.monitoringTimeout: 'monitoring_timeout',
        SlotOutcomeKind.alarmMissed: 'alarm_missed',
        SlotOutcomeKind.appDead: 'app_dead',
        SlotOutcomeKind.unknown: 'unknown',
      };

      for (final entry in outcomes.entries) {
        final report = SlotOutcomeReport(
          id: 'x',
          capturedAtMs: 0,
          globalSlot: 0,
          outcome: entry.key,
        );
        expect(report.toJson()['outcome'], entry.value,
            reason: 'wire format for ${entry.key.name}');
      }
    });

    test('forward-compatible: ignores unknown JSON fields', () {
      // If topochain (or a future Flutter version) starts sending extra
      // keys, decoding here must not throw.
      final json = {
        'id': 'x:1',
        'captured_at_ms': 1,
        'global_slot': 42,
        'outcome': 'produced',
        'totally_new_field': 'whatever',
        'nested': {'unknown': 1},
      };

      final report = SlotOutcomeReport.fromJson(json);

      expect(report.globalSlot, 42);
      expect(report.outcome, SlotOutcomeKind.produced);
    });

    test('falls back to "unknown" outcome for unrecognised wire string', () {
      final report = SlotOutcomeReport.fromJson({
        'id': 'x:1',
        'captured_at_ms': 1,
        'global_slot': 1,
        'outcome': 'something_new_from_the_future',
      });

      expect(report.outcome, SlotOutcomeKind.unknown);
    });

    test('buildId composes id from globalSlot and capturedAtMs', () {
      expect(SlotOutcomeReport.buildId(42, 1700), '42:1700');
    });

    test('node-side enrichment fields roundtrip through JSON', () {
      // These fields are populated from the `epoch_slot_details` RPC after
      // FRB regen flattened `PersistedFlowSummary` onto `RpcSlotDetail`.
      // Pinning the wire keys here prevents a Dart-side refactor from
      // silently breaking the topochain join.
      const report = SlotOutcomeReport(
        id: '1:2',
        capturedAtMs: 2,
        globalSlot: 1,
        outcome: SlotOutcomeKind.produced,
        nodeSlotStatus: 'Won',
        flowOutcome: 'block_injected',
        flowOutcomeDetail: 'ok',
        discardReason: null,
        emptyReason: null,
        blockInjectedAtMs: 1700000000123,
        discardedAtMs: null,
        flowSummaryAtMs: 1700000000456,
        buildMs: 11,
        dbDiffMs: 22,
        signMs: 33,
        injectMs: 44,
        batchFetchMs: 55,
        hydrationVisibleMs: 66,
      );

      final json = report.toJson();
      expect(json['node_slot_status'], 'Won');
      expect(json['flow_outcome'], 'block_injected');
      expect(json['flow_outcome_detail'], 'ok');
      expect(json['block_injected_at_ms'], 1700000000123);
      expect(json['flow_summary_at_ms'], 1700000000456);
      expect(json.containsKey('discard_reason'), isFalse);
      expect(json.containsKey('empty_reason'), isFalse);
      expect(json.containsKey('discarded_at_ms'), isFalse);

      final decoded = SlotOutcomeReport.fromJson(json);
      expect(decoded.nodeSlotStatus, 'Won');
      expect(decoded.flowOutcome, 'block_injected');
      expect(decoded.flowOutcomeDetail, 'ok');
      expect(decoded.blockInjectedAtMs, 1700000000123);
      expect(decoded.flowSummaryAtMs, 1700000000456);
      expect(decoded.buildMs, 11);
      expect(decoded.signMs, 33);
      expect(decoded.injectMs, 44);
    });
  });
}
