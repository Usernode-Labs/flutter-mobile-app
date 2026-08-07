import 'dart:convert';

import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_collector_service.dart';
import 'package:crypto_mobile_app/features/metrics/mobile_context_snapshot_collector.dart';
import 'package:crypto_mobile_app/src/rust/observability.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ObservabilityReportingService mobile context snapshots', () {
    test('node initialization emits static context once for a node run',
        () async {
      final records = <_CapturedObservabilityRecord>[];
      final service = _service(records);

      addTearDown(service.stopMobileContextSnapshotReporting);

      await service.reportNodeInitialized(resetStaticContext: true);
      await service.reportNodeInitialized();

      final staticRecords = _staticRecords(records);
      expect(staticRecords, hasLength(1));
      final record = staticRecords.single;
      expect(record.kind, FlutterObservabilityKind.event);
      expect(record.event, 'app_mobile_context_snapshot');

      final payload = record.payload;
      expect(
        payload.keys,
        unorderedEquals(['event_data', 'runtime', 'platform', 'device']),
      );
      expect(payload['event_data'], {'snapshot_reason': 'node_initialized'});
      expect(payload['runtime'], {
        'app_version': '1.2.3',
        'app_build_number': '45',
      });
      expect(payload['platform'], {
        'platform': 'android',
        'platform_version': '14',
        'system_architecture': 'arm64-v8a',
      });
      expect(payload['device'], {
        'device_id_hash': 'hashed-device-id',
        'device_manufacturer': 'ExampleCo',
        'device_model': 'Example Phone',
        'is_physical_device': true,
      });
    });

    test('node initialization static context includes persisted participant id',
        () async {
      SharedPreferences.setMockInitialValues({
        NetworkPrefs.networkKey: 'testnet',
        'testnet:acct:guest:leaderboard:participant_id': 123,
      });
      await NetworkPrefs.init();

      final records = <_CapturedObservabilityRecord>[];
      final container = ProviderContainer(
        overrides: [
          participantIdProvider.overrideWith((ref) => loadParticipantId()),
        ],
      );
      final collector = MetricsCollectorService.instance;
      collector.reset();
      collector.initialize(container);

      final service = ObservabilityReportingService.test(
        collector: collector,
        canRecord: () => records.isEmpty,
        record: ({
          required FlutterObservabilityKind kind,
          required String event,
          String? payloadJson,
        }) {
          records.add(
            _CapturedObservabilityRecord(
              kind: kind,
              event: event,
              payload: jsonDecode(payloadJson ?? '{}') as Map<String, dynamic>,
            ),
          );
          return const FlutterObservabilityRecordResult(
            queued: true,
            discarded: false,
          );
        },
      );

      addTearDown(() async {
        await service.stopMobileContextSnapshotReporting();
        container.dispose();
        collector.reset();
      });

      await service.reportNodeInitialized(resetStaticContext: true);

      final firstMobileContextRecord = records.firstWhere(
        (record) => record.event == 'app_mobile_context_snapshot',
      );
      expect(firstMobileContextRecord.payload['event_data'], {
        'snapshot_reason': 'node_initialized',
      });
      expect(firstMobileContextRecord.payload['identity'], {
        'participant_id': 123,
      });
    });

    test('static context emits again after a new node start signal', () async {
      final records = <_CapturedObservabilityRecord>[];
      final service = _service(records);

      addTearDown(service.stopMobileContextSnapshotReporting);

      await service.reportNodeInitialized(resetStaticContext: true);
      await service.reportNodeInitialized();
      await service.reportNodeInitialized(resetStaticContext: true);

      final staticRecords = _staticRecords(records);
      expect(staticRecords, hasLength(2));
      expect(
        staticRecords.map((record) => record.payload['event_data']).toList(),
        [
          {'snapshot_reason': 'node_initialized'},
          {'snapshot_reason': 'node_initialized'},
        ],
      );
    });

    test('dynamic updates omit static app, platform, and device sections',
        () async {
      final records = <_CapturedObservabilityRecord>[];
      final service = _service(records);

      await service.reportRuntimeMobileContextSnapshot(
        reason: 'foreground',
        eventData: {'lifecycle_state': 'resumed'},
      );
      await service.reportPowerNetworkServiceContextSnapshot(
        reason: 'network_changed',
        force: true,
      );

      expect(records, hasLength(2));

      final runtimePayload = records[0].payload;
      expect(runtimePayload.keys, unorderedEquals(['event_data', 'runtime']));
      expect(runtimePayload['event_data'], {
        'snapshot_reason': 'foreground',
        'lifecycle_state': 'resumed',
      });
      expect(runtimePayload['runtime'], {
        'app_state': 'foreground',
        'app_uptime_ms': 1200,
        'keep_alive_mode_active': true,
        'notifications_enabled': false,
      });
      expect(runtimePayload.containsKey('platform'), isFalse);
      expect(runtimePayload.containsKey('device'), isFalse);
      expect(runtimePayload.containsKey('battery'), isFalse);
      expect(runtimePayload.containsKey('network'), isFalse);

      final powerPayload = records[1].payload;
      expect(
        powerPayload.keys,
        unorderedEquals([
          'event_data',
          'battery',
          'network',
          'foreground_service',
        ]),
      );
      expect(powerPayload['event_data'], {
        'snapshot_reason': 'network_changed',
      });
      expect(powerPayload['battery'], {
        'battery_level': 88,
        'battery_state': 'discharging',
        'battery_optimization_disabled': true,
        'power_save_mode': false,
        'low_power_mode': false,
      });
      expect(powerPayload['network'], {
        'network_type': 'wifi',
        'network_connected': true,
      });
      expect(powerPayload['foreground_service'], {
        'foreground_service_running': true,
        'wakelock_held': true,
      });
      expect(powerPayload.containsKey('runtime'), isFalse);
      expect(powerPayload.containsKey('platform'), isFalse);
      expect(powerPayload.containsKey('device'), isFalse);
    });

    test('mobile context snapshots are suppressed while node runtime sleeps',
        () async {
      final records = <_CapturedObservabilityRecord>[];
      final service = _service(
        records,
        isNodeRuntimeActive: () => false,
      );

      await service.reportRuntimeMobileContextSnapshot(
        reason: 'foreground',
        eventData: {'lifecycle_state': 'resumed'},
      );
      await service.reportPowerNetworkServiceContextSnapshot(
        reason: 'periodic',
        force: true,
      );

      expect(records, isEmpty);

      service.recordEvent(
        event: 'app_sleep_control',
        details: {'state': 'sleeping'},
      );

      expect(records, hasLength(1));
      expect(records.single.event, 'app_sleep_control');
      expect(records.single.payload, {'state': 'sleeping'});
    });

    test('node resume restarts mobile context with immediate fresh snapshots',
        () async {
      final records = <_CapturedObservabilityRecord>[];
      var nodeRuntimeActive = false;
      final service = _service(
        records,
        isNodeRuntimeActive: () => nodeRuntimeActive,
      );

      await service.startMobileContextSnapshotReporting(
        initialReason: 'startup',
      );
      expect(records, isEmpty);

      nodeRuntimeActive = true;
      await service.resumeMobileContextSnapshotReportingAfterNodeResume();

      expect(records, hasLength(2));
      expect(records.map((record) => record.event).toList(), [
        'app_mobile_context_snapshot',
        'app_mobile_context_snapshot',
      ]);
      expect(records[0].payload['event_data'], {
        'snapshot_reason': 'node_wake',
      });
      expect(records[0].payload.containsKey('runtime'), isTrue);
      expect(records[1].payload['event_data'], {
        'snapshot_reason': 'node_wake',
      });
      expect(records[1].payload.containsKey('battery'), isTrue);
      expect(records[1].payload.containsKey('network'), isTrue);
    });

    test('semantic record methods own observability kind selection', () {
      final records = <_CapturedObservabilityRecord>[];
      final service = _service(records);

      service.recordEvent(
        event: 'app_mobile_context_snapshot',
        details: {'source': 'event'},
      );
      service.recordMetricSample(
        event: 'flutter_metric_sample',
        details: {'source': 'metric'},
      );
      service.recordError(
        event: 'flutter_error',
        details: {'source': 'error'},
      );

      expect(
        records.map((record) => record.kind).toList(),
        [
          FlutterObservabilityKind.event,
          FlutterObservabilityKind.metrics,
          FlutterObservabilityKind.error,
        ],
      );
      expect(records.map((record) => record.event).toList(), [
        'app_mobile_context_snapshot',
        'flutter_metric_sample',
        'flutter_error',
      ]);
    });

    test('block production alarm scheduling is reported as an event', () {
      final records = <_CapturedObservabilityRecord>[];
      final service = _service(records);

      service.reportBlockProductionAlarmScheduled(
        alarmId: 'fg_resume',
        purpose: 'foreground_resume',
        globalSlot: 42,
        epoch: 7,
        slotTimeMs: 1700000060000,
        scheduledAtMs: 1700000000000,
        alarmTimeMs: 1700000005000,
        requestedDelayMs: 5000,
        delayMs: 5000,
        leadMs: 55000,
        platform: 'android',
        success: true,
      );

      expect(records, hasLength(1));
      final record = records.single;
      expect(record.kind, FlutterObservabilityKind.event);
      expect(record.event, 'app_block_production_alarm_scheduled');
      expect(record.payload, {
        'alarm_id': 'fg_resume',
        'purpose': 'foreground_resume',
        'global_slot': 42,
        'epoch': 7,
        'slot_time_ms': 1700000060000,
        'scheduled_at_ms': 1700000000000,
        'alarm_time_ms': 1700000005000,
        'requested_delay_ms': 5000,
        'delay_ms': 5000,
        'lead_ms': 55000,
        'platform': 'android',
        'success': true,
      });
    });

    test('block production alarm fire is reported as an event', () {
      final records = <_CapturedObservabilityRecord>[];
      final service = _service(records, nodeInitialized: false);

      service.reportBlockProductionAlarmFired(
        nativeEvent: 'android_alarm_fired',
        alarmId: 'fg_resume',
        purpose: 'foreground_resume',
        globalSlot: 42,
        alarmTimeMs: 1700000005000,
        firedAtMs: 1700000005123,
        latencyMs: 123,
        platform: 'android',
        nodeRunning: true,
        batteryLevel: 88,
        networkState: 'wifi',
      );

      expect(records, hasLength(1));
      final record = records.single;
      expect(record.kind, FlutterObservabilityKind.event);
      expect(record.event, 'app_block_production_alarm_fired');
      expect(record.payload, {
        'native_event': 'android_alarm_fired',
        'alarm_id': 'fg_resume',
        'purpose': 'foreground_resume',
        'global_slot': 42,
        'alarm_time_ms': 1700000005000,
        'fired_at_ms': 1700000005123,
        'latency_ms': 123,
        'platform': 'android',
        'node_running': true,
        'battery_level': 88,
        'network_state': 'wifi',
      });
    });

    test('non-alarm records remain gated before node initialization', () {
      final records = <_CapturedObservabilityRecord>[];
      final service = _service(records, nodeInitialized: false);

      final result = service.recordEvent(
        event: 'ordinary_flutter_event',
        details: {'source': 'test'},
      );

      expect(result.discarded, isTrue);
      expect(result.reason, 'observability_disabled');
      expect(records, isEmpty);
    });

    test('alarm fire is retained until node initialization when node is absent',
        () async {
      final records = <_CapturedObservabilityRecord>[];
      var nodeRunning = false;
      final service = _service(
        records,
        nodeInitialized: false,
        record: ({
          required FlutterObservabilityKind kind,
          required String event,
          String? payloadJson,
        }) {
          if (!nodeRunning) {
            return const FlutterObservabilityRecordResult(
              queued: false,
              discarded: true,
              reason: 'node_not_running',
            );
          }

          records.add(
            _CapturedObservabilityRecord(
              kind: kind,
              event: event,
              payload: jsonDecode(payloadJson ?? '{}') as Map<String, dynamic>,
            ),
          );
          return const FlutterObservabilityRecordResult(
            queued: true,
            discarded: false,
          );
        },
      );

      final result = service.reportBlockProductionAlarmFired(
        nativeEvent: 'android_alarm_fired',
        alarmId: 'fg_resume',
        purpose: 'foreground_resume',
        globalSlot: 42,
        alarmTimeMs: 1700000005000,
        firedAtMs: 1700000005123,
        platform: 'android',
      );

      expect(result.queued, isTrue);
      expect(records, isEmpty);

      nodeRunning = true;
      service.markNodeInitialized();

      final firedRecords = records
          .where((record) => record.event == 'app_block_production_alarm_fired')
          .toList();
      expect(firedRecords, hasLength(1));
      expect(firedRecords.single.payload['global_slot'], 42);
    });

    test('native fired resume alarms report target global slot', () {
      final records = <_CapturedObservabilityRecord>[];
      final service = _service(records, nodeInitialized: false);
      final alarmService = PlatformAlarmService.test(observability: service);

      alarmService.handleNativeEventForTest('android_alarm_fired', {
        'alarmId': 'fg_resume',
        'globalSlot': 42,
        'alarmTimeMs': 1700000005000,
        'firedAtMs': 1700000005123,
        'latencyMs': 123,
        'reason': 'next_won_slot:42',
      });

      expect(records, hasLength(1));
      expect(records.single.event, 'app_block_production_alarm_fired');
      expect(records.single.payload['global_slot'], 42);
      expect(records.single.payload['purpose'], 'foreground_resume');
    });

    test('native fired resume alarms derive target slot from reason', () {
      final records = <_CapturedObservabilityRecord>[];
      final service = _service(records, nodeInitialized: false);
      final alarmService = PlatformAlarmService.test(observability: service);

      alarmService.handleNativeEventForTest('android_alarm_fired', {
        'alarmId': 'fg_resume',
        'alarmTimeMs': 1700000005000,
        'firedAtMs': 1700000005123,
        'reason': 'next_won_slot:43',
      });

      expect(records, hasLength(1));
      expect(records.single.payload['global_slot'], 43);
    });

    test('duplicate native fired events are suppressed', () {
      final records = <_CapturedObservabilityRecord>[];
      final service = _service(records, nodeInitialized: false);
      final alarmService = PlatformAlarmService.test(observability: service);
      final eventData = {
        'alarmId': 'fg_resume',
        'globalSlot': 42,
        'alarmTimeMs': 1700000005000,
        'firedAtMs': 1700000005123,
      };

      alarmService.handleNativeEventForTest('android_alarm_fired', eventData);
      alarmService.handleNativeEventForTest('android_alarm_fired', eventData);

      expect(records, hasLength(1));
    });
  });
}

List<_CapturedObservabilityRecord> _staticRecords(
  List<_CapturedObservabilityRecord> records,
) {
  return records.where((record) {
    return record.payload.containsKey('platform') &&
        record.payload.containsKey('device');
  }).toList();
}

ObservabilityReportingService _service(
  List<_CapturedObservabilityRecord> records, {
  bool nodeInitialized = true,
  ObservabilityRecordClient? record,
  NodeRuntimeActiveGetter? isNodeRuntimeActive,
}) {
  final service = ObservabilityReportingService.test(
    collector: _FakeMobileContextCollector(),
    canRecord: () => true,
    isNodeRuntimeActive: isNodeRuntimeActive,
    record: record ??
        ({
          required FlutterObservabilityKind kind,
          required String event,
          String? payloadJson,
        }) {
          records.add(
            _CapturedObservabilityRecord(
              kind: kind,
              event: event,
              payload: jsonDecode(payloadJson ?? '{}') as Map<String, dynamic>,
            ),
          );
          return const FlutterObservabilityRecordResult(
            queued: true,
            discarded: false,
          );
        },
  );
  if (nodeInitialized) {
    service.markNodeInitialized();
  }
  return service;
}

class _CapturedObservabilityRecord {
  const _CapturedObservabilityRecord({
    required this.kind,
    required this.event,
    required this.payload,
  });

  final FlutterObservabilityKind kind;
  final String event;
  final Map<String, dynamic> payload;
}

class _FakeMobileContextCollector implements MobileContextSnapshotCollector {
  @override
  Future<Map<String, dynamic>> collectStaticMobileContextSnapshot({
    Map<String, dynamic>? eventData,
  }) async {
    return {
      if (eventData != null && eventData.isNotEmpty) 'event_data': eventData,
      'runtime': {
        'app_version': '1.2.3',
        'app_build_number': '45',
      },
      'platform': {
        'platform': 'android',
        'platform_version': '14',
        'system_architecture': 'arm64-v8a',
      },
      'device': {
        'device_id_hash': 'hashed-device-id',
        'device_manufacturer': 'ExampleCo',
        'device_model': 'Example Phone',
        'is_physical_device': true,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> collectRuntimeMobileContextSnapshot({
    Map<String, dynamic>? eventData,
  }) async {
    return {
      if (eventData != null && eventData.isNotEmpty) 'event_data': eventData,
      'runtime': {
        'app_state': 'foreground',
        'app_uptime_ms': 1200,
        'keep_alive_mode_active': true,
        'notifications_enabled': false,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> collectPowerNetworkServiceContextSnapshot({
    Map<String, dynamic>? eventData,
  }) async {
    return {
      if (eventData != null && eventData.isNotEmpty) 'event_data': eventData,
      'battery': {
        'battery_level': 88,
        'battery_state': 'discharging',
        'battery_optimization_disabled': true,
        'power_save_mode': false,
        'low_power_mode': false,
      },
      'network': {
        'network_type': 'wifi',
        'network_connected': true,
      },
      'foreground_service': {
        'foreground_service_running': true,
        'wakelock_held': true,
      },
    };
  }
}
