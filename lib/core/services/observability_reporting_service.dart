import 'dart:async';
import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/metrics/mobile_context_snapshot_collector.dart';
import 'package:crypto_mobile_app/src/rust/observability.dart';
import 'package:flutter/widgets.dart';

final _log = LoggingService.instance.withTag('usernode/Observability');

typedef ObservabilityRecordClient = FlutterObservabilityRecordResult Function({
  required FlutterObservabilityKind kind,
  required String event,
  String? payloadJson,
});

typedef _MobileContextCollectorCall = Future<Map<String, dynamic>> Function({
  Map<String, dynamic>? eventData,
});

typedef NodeRuntimeActiveGetter = bool Function();

class ObservabilityReportingService {
  ObservabilityReportingService._()
      : _record = observabilityRecord,
        _canRecordOverride = null,
        _isNodeRuntimeActive = null;

  ObservabilityReportingService.test({
    required MobileContextSnapshotCollector collector,
    required ObservabilityRecordClient record,
    bool Function()? canRecord,
    NodeRuntimeActiveGetter? isNodeRuntimeActive,
  })  : _collector = collector,
        _record = record,
        _canRecordOverride = canRecord,
        _isNodeRuntimeActive = isNodeRuntimeActive;

  static final ObservabilityReportingService instance =
      ObservabilityReportingService._();

  static const _lifecycleDuplicateWindow = Duration(seconds: 2);
  static const _powerNetworkServiceSnapshotInterval = Duration(minutes: 10);
  static const _powerNetworkServiceSnapshotMinimumGap = Duration(minutes: 1);
  static const _batteryUsageSampleWindow = Duration(minutes: 5);
  static const _batteryStateDuplicateWindow = Duration(seconds: 30);
  static const _maxPendingEarlyRecords = 16;

  final ObservabilityRecordClient _record;
  final bool Function()? _canRecordOverride;
  NodeRuntimeActiveGetter? _isNodeRuntimeActive;
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  MobileContextSnapshotCollector? _collector;

  String? _lastLifecycleEvent;
  DateTime? _lastLifecycleEventAt;
  Timer? _powerNetworkServiceSnapshotTimer;
  StreamSubscription<BatteryState>? _batteryStateSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _mobileContextReportingStarted = false;
  bool _staticMobileContextReported = false;
  bool _powerNetworkServiceSnapshotInFlight = false;
  bool _nodeInitialized = false;
  final List<_PendingObservabilityRecord> _pendingEarlyRecords = [];
  DateTime? _lastPowerNetworkServiceSnapshotAt;
  int? _lastBatteryLevel;
  DateTime? _lastBatteryLevelAt;
  BatteryState? _lastBatteryStateEvent;
  DateTime? _lastBatteryStateEventAt;

  void markNodeInitialized({bool resetStaticContext = false}) {
    _nodeInitialized = true;
    if (resetStaticContext) {
      _staticMobileContextReported = false;
    }
    _flushPendingEarlyRecords();
  }

  void configureMobileContextCollector(
      MobileContextSnapshotCollector collector) {
    _collector = collector;
  }

  void configureNodeRuntimeActiveGetter(NodeRuntimeActiveGetter getter) {
    _isNodeRuntimeActive = getter;
  }

  Future<void> reportNodeInitialized({
    bool resetStaticContext = false,
  }) async {
    markNodeInitialized(resetStaticContext: resetStaticContext);
    await reportStaticMobileContextSnapshot(reason: 'node_initialized');
    await startMobileContextSnapshotReporting(initialReason: 'startup');
  }

  Future<void> reportLifecycleStateChanged(AppLifecycleState state) async {
    final event = switch (state) {
      AppLifecycleState.resumed => 'app_foreground',
      AppLifecycleState.paused ||
      AppLifecycleState.hidden ||
      AppLifecycleState.detached =>
        'app_background',
      AppLifecycleState.inactive => null,
    };

    if (event == null || _isDuplicateLifecycleEvent(event)) {
      return;
    }

    final eventData = {'lifecycle_state': state.name};
    await reportRuntimeMobileContextSnapshot(
      reason: event == 'app_foreground' ? 'foreground' : 'background',
      eventData: eventData,
    );
    await reportPowerNetworkServiceContextSnapshot(
      reason: event == 'app_foreground' ? 'foreground' : 'background',
      eventData: eventData,
      force: true,
    );
  }

  bool _isDuplicateLifecycleEvent(String event) {
    final now = DateTime.now();
    final lastAt = _lastLifecycleEventAt;
    if (_lastLifecycleEvent == event &&
        lastAt != null &&
        now.difference(lastAt) < _lifecycleDuplicateWindow) {
      return true;
    }

    _lastLifecycleEvent = event;
    _lastLifecycleEventAt = now;
    return false;
  }

  Future<void> startMobileContextSnapshotReporting({
    String initialReason = 'startup',
    Map<String, dynamic>? initialEventData,
  }) async {
    if (!_canReportMobileContextSnapshots) {
      return;
    }

    if (_mobileContextReportingStarted) {
      await reportRuntimeMobileContextSnapshot(
        reason: initialReason,
        eventData: initialEventData,
      );
      await reportPowerNetworkServiceContextSnapshot(
        reason: initialReason,
        eventData: initialEventData,
        force: true,
      );
      return;
    }

    _mobileContextReportingStarted = true;
    _batteryStateSubscription = _battery.onBatteryStateChanged.listen(
      _handleBatteryStateChanged,
      onError: (Object e) {
        _log.debug('Battery state stream error: $e');
      },
    );
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleNetworkChanged,
      onError: (Object e) {
        _log.debug('Connectivity stream error: $e');
      },
    );
    _powerNetworkServiceSnapshotTimer = Timer.periodic(
      _powerNetworkServiceSnapshotInterval,
      (_) => unawaited(
        reportPowerNetworkServiceContextSnapshot(reason: 'periodic'),
      ),
    );

    await reportRuntimeMobileContextSnapshot(
      reason: initialReason,
      eventData: initialEventData,
    );
    await reportPowerNetworkServiceContextSnapshot(
      reason: initialReason,
      eventData: initialEventData,
      force: true,
    );
  }

  Future<void> stopMobileContextSnapshotReporting() async {
    _powerNetworkServiceSnapshotTimer?.cancel();
    _powerNetworkServiceSnapshotTimer = null;
    await _batteryStateSubscription?.cancel();
    _batteryStateSubscription = null;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _mobileContextReportingStarted = false;
    _powerNetworkServiceSnapshotInFlight = false;
  }

  Future<void> pauseMobileContextSnapshotReportingForNodePause() async {
    await stopMobileContextSnapshotReporting();
  }

  Future<void> resumeMobileContextSnapshotReportingAfterNodeResume() async {
    await startMobileContextSnapshotReporting(
      initialReason: 'node_wake',
    );
  }

  FlutterObservabilityRecordResult recordEvent({
    required String event,
    Map<String, dynamic>? details,
  }) {
    return _recordStructured(
      kind: FlutterObservabilityKind.event,
      event: event,
      details: details,
    );
  }

  FlutterObservabilityRecordResult recordMetricSample({
    required String event,
    Map<String, dynamic>? details,
  }) {
    return _recordStructured(
      kind: FlutterObservabilityKind.metrics,
      event: event,
      details: details,
    );
  }

  FlutterObservabilityRecordResult recordError({
    required String event,
    Map<String, dynamic>? details,
  }) {
    return _recordStructured(
      kind: FlutterObservabilityKind.error,
      event: event,
      details: details,
    );
  }

  FlutterObservabilityRecordResult reportBlockProductionAlarmScheduled({
    required String alarmId,
    required int scheduledAtMs,
    required int alarmTimeMs,
    required int requestedDelayMs,
    required int delayMs,
    required String platform,
    required bool success,
    String? purpose,
    int? globalSlot,
    int? epoch,
    int? slotTimeMs,
    int? rustSlotTimeMs,
    int? localSlotTimeMs,
    int? leadMs,
    String? schedulerReason,
    bool? nodeRunning,
    int? rustWakeTimeMs,
    int? localWakeTimeMs,
    int? clockDriftMs,
    int? nodeTimeMsAtSchedule,
    int? systemTimeMsAtSchedule,
    int? clockDriftSampleAgeMs,
    String? failureReason,
  }) {
    return recordEvent(
      event: 'app_block_production_alarm_scheduled',
      details: {
        'alarm_id': alarmId,
        if (purpose != null) 'purpose': purpose,
        if (globalSlot != null) 'global_slot': globalSlot,
        if (epoch != null) 'epoch': epoch,
        if (slotTimeMs != null) 'slot_time_ms': slotTimeMs,
        if (rustSlotTimeMs != null) 'rust_slot_time_ms': rustSlotTimeMs,
        if (localSlotTimeMs != null) 'local_slot_time_ms': localSlotTimeMs,
        'scheduled_at_ms': scheduledAtMs,
        'alarm_time_ms': alarmTimeMs,
        'requested_delay_ms': requestedDelayMs,
        'delay_ms': delayMs,
        if (leadMs != null) 'lead_ms': leadMs,
        'platform': platform,
        'success': success,
        if (schedulerReason != null) 'scheduler_reason': schedulerReason,
        if (nodeRunning != null) 'node_running': nodeRunning,
        if (rustWakeTimeMs != null) 'rust_wake_time_ms': rustWakeTimeMs,
        if (localWakeTimeMs != null) 'local_wake_time_ms': localWakeTimeMs,
        if (clockDriftMs != null) 'clock_drift_ms': clockDriftMs,
        if (nodeTimeMsAtSchedule != null)
          'node_time_ms_at_schedule': nodeTimeMsAtSchedule,
        if (systemTimeMsAtSchedule != null)
          'system_time_ms_at_schedule': systemTimeMsAtSchedule,
        if (clockDriftSampleAgeMs != null)
          'clock_drift_sample_age_ms': clockDriftSampleAgeMs,
        if (failureReason != null) 'failure_reason': failureReason,
      },
    );
  }

  FlutterObservabilityRecordResult reportBlockProductionAlarmFired({
    required String nativeEvent,
    required int firedAtMs,
    required String platform,
    String? alarmId,
    String? purpose,
    int? globalSlot,
    int? alarmTimeMs,
    int? latencyMs,
    int? nativeTriggerAtMs,
    int? triggerElapsedRealtimeMs,
    int? receiverElapsedRealtimeMs,
    int? nativeDeliveryLatencyMs,
    int? elapsedDeliveryLatencyMs,
    bool? nodeRunning,
    int? batteryLevel,
    String? networkState,
  }) {
    return _recordStructured(
      kind: FlutterObservabilityKind.event,
      event: 'app_block_production_alarm_fired',
      details: {
        'native_event': nativeEvent,
        if (alarmId != null) 'alarm_id': alarmId,
        if (purpose != null) 'purpose': purpose,
        if (globalSlot != null) 'global_slot': globalSlot,
        if (alarmTimeMs != null) 'alarm_time_ms': alarmTimeMs,
        'fired_at_ms': firedAtMs,
        if (latencyMs != null) 'latency_ms': latencyMs,
        if (nativeTriggerAtMs != null)
          'native_trigger_at_ms': nativeTriggerAtMs,
        if (triggerElapsedRealtimeMs != null)
          'trigger_elapsed_realtime_ms': triggerElapsedRealtimeMs,
        if (receiverElapsedRealtimeMs != null)
          'receiver_elapsed_realtime_ms': receiverElapsedRealtimeMs,
        if (nativeDeliveryLatencyMs != null)
          'native_delivery_latency_ms': nativeDeliveryLatencyMs,
        if (elapsedDeliveryLatencyMs != null)
          'elapsed_delivery_latency_ms': elapsedDeliveryLatencyMs,
        'platform': platform,
        if (nodeRunning != null) 'node_running': nodeRunning,
        if (batteryLevel != null) 'battery_level': batteryLevel,
        if (networkState != null) 'network_state': networkState,
      },
      requireNodeInitialized: false,
      retainUntilNodeInitialized: true,
    );
  }

  FlutterObservabilityRecordResult reportBlockProductionAlarmAuditEvent({
    required String event,
    Map<String, dynamic>? details,
  }) {
    return _recordStructured(
      kind: FlutterObservabilityKind.event,
      event: event,
      details: details,
      requireNodeInitialized: false,
      retainUntilNodeInitialized: true,
    );
  }

  Future<void> reportStaticMobileContextSnapshot({
    String reason = 'node_initialized',
    Map<String, dynamic>? eventData,
  }) async {
    if (_staticMobileContextReported) {
      return;
    }

    final collector = _collector;
    if (collector == null) {
      _log.debug('Skipping static mobile context; collector not configured');
      return;
    }

    final recorded = await _recordMobileContextSnapshot(
      reason: reason,
      eventData: eventData,
      collect: collector.collectStaticMobileContextSnapshot,
    );
    if (recorded) {
      _staticMobileContextReported = true;
    }
  }

  Future<void> reportRuntimeMobileContextSnapshot({
    required String reason,
    Map<String, dynamic>? eventData,
  }) async {
    final collector = _collector;
    if (collector == null) {
      _log.debug('Skipping runtime mobile context; collector not configured');
      return;
    }

    await _recordMobileContextSnapshot(
      reason: reason,
      eventData: eventData,
      collect: collector.collectRuntimeMobileContextSnapshot,
    );
  }

  Future<void> reportPowerNetworkServiceContextSnapshot({
    required String reason,
    Map<String, dynamic>? eventData,
    bool force = false,
  }) async {
    if (!_canReportMobileContextSnapshots ||
        _powerNetworkServiceSnapshotInFlight) {
      return;
    }

    final collector = _collector;
    if (collector == null) {
      _log.debug(
        'Skipping power/network/service mobile context; collector not configured',
      );
      return;
    }

    final now = DateTime.now();
    if (!force &&
        _lastPowerNetworkServiceSnapshotAt != null &&
        now.difference(_lastPowerNetworkServiceSnapshotAt!) <
            _powerNetworkServiceSnapshotMinimumGap) {
      return;
    }

    _lastPowerNetworkServiceSnapshotAt = now;
    _powerNetworkServiceSnapshotInFlight = true;
    try {
      await _recordMobileContextSnapshot(
        reason: reason,
        eventData: eventData,
        collect: collector.collectPowerNetworkServiceContextSnapshot,
        includeBatteryUsage: true,
      );
    } finally {
      _powerNetworkServiceSnapshotInFlight = false;
    }
  }

  bool get _canRecordObservability =>
      _canUseObservabilityTransport && _nodeInitialized;

  bool get _canUseObservabilityTransport =>
      _canRecordOverride?.call() ??
      (!AppConfig.viewOnly &&
          AppConfig.observabilityHubBaseUrl.trim().isNotEmpty);

  bool get _canReportMobileContextSnapshots =>
      _canRecordObservability && _isNodeRuntimeActiveForMobileContext;

  bool get _isNodeRuntimeActiveForMobileContext {
    final isActive = _isNodeRuntimeActive;
    if (isActive == null) {
      return true;
    }

    try {
      return isActive();
    } catch (e) {
      _log.debug('Failed to read node runtime active state: $e');
      return false;
    }
  }

  void _handleBatteryStateChanged(BatteryState state) {
    final now = DateTime.now();
    final lastAt = _lastBatteryStateEventAt;
    if (_lastBatteryStateEvent == state &&
        lastAt != null &&
        now.difference(lastAt) < _batteryStateDuplicateWindow) {
      return;
    }

    _lastBatteryStateEvent = state;
    _lastBatteryStateEventAt = now;
    unawaited(
      reportPowerNetworkServiceContextSnapshot(
        reason: 'battery_state_changed',
        eventData: {'battery_state_changed_to': state.name},
        force: true,
      ),
    );
  }

  void _handleNetworkChanged(List<ConnectivityResult> _) {
    unawaited(
      reportPowerNetworkServiceContextSnapshot(
        reason: 'network_changed',
        force: true,
      ),
    );
  }

  Future<bool> _recordMobileContextSnapshot({
    required String reason,
    Map<String, dynamic>? eventData,
    required _MobileContextCollectorCall collect,
    bool includeBatteryUsage = false,
  }) async {
    if (!_canReportMobileContextSnapshots) {
      return false;
    }

    try {
      final details = await collect(
        eventData: {
          'snapshot_reason': reason,
          if (eventData != null) ...eventData,
        },
      );
      if (includeBatteryUsage) {
        final batteryUsage = _batteryUsageDetails(details);
        if (batteryUsage != null) {
          details['battery_usage'] = batteryUsage;
        }
      }

      final result = recordEvent(
        event: 'app_mobile_context_snapshot',
        details: details,
      );

      if (result.discarded) {
        _log.debug(
          'Observability mobile context snapshot discarded',
          context: {
            'reason': reason,
            if (result.reason != null) 'discard_reason': result.reason,
          },
        );
      }
      return result.queued || !result.discarded;
    } catch (e) {
      _log.warn(
        'Failed to record observability mobile context snapshot: $e',
        context: {'reason': reason},
      );
      return false;
    }
  }

  FlutterObservabilityRecordResult _recordStructured({
    required FlutterObservabilityKind kind,
    required String event,
    Map<String, dynamic>? details,
    bool requireNodeInitialized = true,
    bool retainUntilNodeInitialized = false,
  }) {
    if (!_canUseObservabilityTransport ||
        (requireNodeInitialized && !_nodeInitialized)) {
      return const FlutterObservabilityRecordResult(
        queued: false,
        discarded: true,
        reason: 'observability_disabled',
      );
    }

    String? payloadJson;
    if (details != null) {
      try {
        payloadJson = jsonEncode(details);
      } catch (_) {
        return const FlutterObservabilityRecordResult(
          queued: false,
          discarded: true,
          reason: 'invalid_payload_json',
        );
      }
    }

    final result = _record(
      kind: kind,
      event: event,
      payloadJson: payloadJson,
    );
    if (retainUntilNodeInitialized &&
        result.discarded &&
        result.reason == 'node_not_running') {
      _retainPendingEarlyRecord(
        _PendingObservabilityRecord(
          kind: kind,
          event: event,
          payloadJson: payloadJson,
        ),
      );
      return const FlutterObservabilityRecordResult(
        queued: true,
        discarded: false,
      );
    }

    return result;
  }

  void _retainPendingEarlyRecord(_PendingObservabilityRecord record) {
    if (_pendingEarlyRecords.contains(record)) {
      return;
    }

    if (_pendingEarlyRecords.length >= _maxPendingEarlyRecords) {
      _pendingEarlyRecords.removeAt(0);
    }
    _pendingEarlyRecords.add(record);
  }

  void _flushPendingEarlyRecords() {
    if (!_nodeInitialized ||
        !_canUseObservabilityTransport ||
        _pendingEarlyRecords.isEmpty) {
      return;
    }

    final pending = List<_PendingObservabilityRecord>.of(_pendingEarlyRecords);
    _pendingEarlyRecords.clear();
    for (final record in pending) {
      final result = _record(
        kind: record.kind,
        event: record.event,
        payloadJson: record.payloadJson,
      );
      if (result.discarded && result.reason == 'node_not_running') {
        _retainPendingEarlyRecord(record);
      }
    }
  }

  Map<String, dynamic>? _batteryUsageDetails(Map<String, dynamic> details) {
    final battery = details['battery'];
    if (battery is! Map<String, dynamic>) {
      return null;
    }

    final levelValue = battery['battery_level'];
    final level = switch (levelValue) {
      int value => value,
      num value => value.round(),
      _ => null,
    };
    if (level == null) {
      return null;
    }

    final now = DateTime.now();
    final previousLevel = _lastBatteryLevel;
    final previousAt = _lastBatteryLevelAt;
    _lastBatteryLevel = level;
    _lastBatteryLevelAt = now;

    if (previousLevel == null || previousAt == null) {
      return null;
    }

    final sampleInterval = now.difference(previousAt);
    if (sampleInterval < _batteryUsageSampleWindow) {
      return null;
    }

    final state = battery['battery_state'];
    if (state == 'charging' || state == 'full') {
      return null;
    }

    final deltaPercent = level - previousLevel;
    final drainedPercent = deltaPercent < 0 ? -deltaPercent : 0;
    final sampleHours = sampleInterval.inMilliseconds / 3600000;
    final estimatedDrainPerHour =
        sampleHours <= 0 ? 0.0 : drainedPercent / sampleHours;

    return {
      'previous_battery_level': previousLevel,
      'battery_delta_percent': deltaPercent,
      'battery_sample_interval_ms': sampleInterval.inMilliseconds,
      'estimated_drain_percent_per_hour': estimatedDrainPerHour,
    };
  }
}

class _PendingObservabilityRecord {
  const _PendingObservabilityRecord({
    required this.kind,
    required this.event,
    required this.payloadJson,
  });

  final FlutterObservabilityKind kind;
  final String event;
  final String? payloadJson;

  @override
  bool operator ==(Object other) {
    return other is _PendingObservabilityRecord &&
        other.kind == kind &&
        other.event == event &&
        other.payloadJson == payloadJson;
  }

  @override
  int get hashCode => Object.hash(kind, event, payloadJson);
}
