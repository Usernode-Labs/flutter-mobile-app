import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

final _log = LoggingService.instance.withTag('usernode/AlarmService');

/// Callback type for handling boot reschedule events
typedef BootRescheduleCallback = Future<void> Function();

/// Callback type for handling native block production events
typedef NativeEventCallback = Future<bool> Function(
    String eventType, Map<String, dynamic> eventData);

class AlarmDebugState {
  const AlarmDebugState({
    required this.alarmId,
    required this.pendingIntentExists,
    this.canScheduleExactAlarms,
    this.scheduledAtMs,
    this.triggerAtMs,
    this.slotNumber,
    this.globalSlot,
    this.epoch,
    this.slotTimeMs,
    this.rustSlotTimeMs,
    this.localSlotTimeMs,
    this.alarmTimeMs,
    this.nativeTriggerAtMs,
    this.scheduledElapsedRealtimeMs,
    this.triggerElapsedRealtimeMs,
    this.requestedDelayMs,
    this.effectiveDelayMs,
    this.rustWakeTimeMs,
    this.localWakeTimeMs,
    this.clockDriftMs,
    this.nodeTimeMsAtSchedule,
    this.systemTimeMsAtSchedule,
    this.clockDriftSampleAgeMs,
    this.purpose,
    this.schedulerReason,
    this.scheduleStatus,
    this.scheduleFailureReason,
    this.receiverEnteredAtMs,
    this.receiverSystemTimeMs,
    this.receiverElapsedRealtimeMs,
    this.receiverLatencyMs,
    this.nativeDeliveryLatencyMs,
    this.elapsedDeliveryLatencyMs,
    this.flutterEventSentAtMs,
    this.cancelledAtMs,
    this.cancelReason,
    this.nodeRunning,
    this.stateUnavailableReason,
  });

  factory AlarmDebugState.fromMap(Map<Object?, Object?> map) {
    return AlarmDebugState(
      alarmId: _alarmDebugString(map['alarmId']) ??
          _alarmDebugString(map['alarm_id']) ??
          'unknown',
      pendingIntentExists: _alarmDebugBool(map['pendingIntentExists']) ??
          _alarmDebugBool(map['pending_intent_exists']) ??
          false,
      canScheduleExactAlarms: _alarmDebugBool(map['canScheduleExactAlarms']) ??
          _alarmDebugBool(map['can_schedule_exact_alarms']),
      scheduledAtMs: _alarmDebugInt(map['scheduledAtMs']) ??
          _alarmDebugInt(map['scheduled_at_ms']),
      triggerAtMs: _alarmDebugInt(map['triggerAtMs']) ??
          _alarmDebugInt(map['trigger_at_ms']),
      slotNumber: _alarmDebugInt(map['slotNumber']) ??
          _alarmDebugInt(map['slot_number']),
      globalSlot: _alarmDebugInt(map['globalSlot']) ??
          _alarmDebugInt(map['global_slot']),
      epoch: _alarmDebugInt(map['epoch']),
      slotTimeMs: _alarmDebugInt(map['slotTimeMs']) ??
          _alarmDebugInt(map['slot_time_ms']),
      rustSlotTimeMs: _alarmDebugInt(map['rustSlotTimeMs']) ??
          _alarmDebugInt(map['rust_slot_time_ms']),
      localSlotTimeMs: _alarmDebugInt(map['localSlotTimeMs']) ??
          _alarmDebugInt(map['local_slot_time_ms']),
      alarmTimeMs: _alarmDebugInt(map['alarmTimeMs']) ??
          _alarmDebugInt(map['alarm_time_ms']),
      nativeTriggerAtMs: _alarmDebugInt(map['nativeTriggerAtMs']) ??
          _alarmDebugInt(map['native_trigger_at_ms']),
      scheduledElapsedRealtimeMs:
          _alarmDebugInt(map['scheduledElapsedRealtimeMs']) ??
              _alarmDebugInt(map['scheduled_elapsed_realtime_ms']),
      triggerElapsedRealtimeMs:
          _alarmDebugInt(map['triggerElapsedRealtimeMs']) ??
              _alarmDebugInt(map['trigger_elapsed_realtime_ms']),
      requestedDelayMs: _alarmDebugInt(map['requestedDelayMs']) ??
          _alarmDebugInt(map['requested_delay_ms']),
      effectiveDelayMs: _alarmDebugInt(map['effectiveDelayMs']) ??
          _alarmDebugInt(map['effective_delay_ms']),
      rustWakeTimeMs: _alarmDebugInt(map['rustWakeTimeMs']) ??
          _alarmDebugInt(map['rust_wake_time_ms']),
      localWakeTimeMs: _alarmDebugInt(map['localWakeTimeMs']) ??
          _alarmDebugInt(map['local_wake_time_ms']),
      clockDriftMs: _alarmDebugInt(map['clockDriftMs']) ??
          _alarmDebugInt(map['clock_drift_ms']),
      nodeTimeMsAtSchedule: _alarmDebugInt(map['nodeTimeMsAtSchedule']) ??
          _alarmDebugInt(map['node_time_ms_at_schedule']),
      systemTimeMsAtSchedule: _alarmDebugInt(map['systemTimeMsAtSchedule']) ??
          _alarmDebugInt(map['system_time_ms_at_schedule']),
      clockDriftSampleAgeMs: _alarmDebugInt(map['clockDriftSampleAgeMs']) ??
          _alarmDebugInt(map['clock_drift_sample_age_ms']),
      purpose: _alarmDebugString(map['purpose']),
      schedulerReason: _alarmDebugString(map['schedulerReason']) ??
          _alarmDebugString(map['scheduler_reason']),
      scheduleStatus: _alarmDebugString(map['scheduleStatus']) ??
          _alarmDebugString(map['schedule_status']),
      scheduleFailureReason: _alarmDebugString(map['scheduleFailureReason']) ??
          _alarmDebugString(map['schedule_failure_reason']),
      receiverEnteredAtMs: _alarmDebugInt(map['receiverEnteredAtMs']) ??
          _alarmDebugInt(map['receiver_entered_at_ms']),
      receiverSystemTimeMs: _alarmDebugInt(map['receiverSystemTimeMs']) ??
          _alarmDebugInt(map['receiver_system_time_ms']),
      receiverElapsedRealtimeMs:
          _alarmDebugInt(map['receiverElapsedRealtimeMs']) ??
              _alarmDebugInt(map['receiver_elapsed_realtime_ms']),
      receiverLatencyMs: _alarmDebugInt(map['receiverLatencyMs']) ??
          _alarmDebugInt(map['receiver_latency_ms']),
      nativeDeliveryLatencyMs: _alarmDebugInt(map['nativeDeliveryLatencyMs']) ??
          _alarmDebugInt(map['native_delivery_latency_ms']),
      elapsedDeliveryLatencyMs:
          _alarmDebugInt(map['elapsedDeliveryLatencyMs']) ??
              _alarmDebugInt(map['elapsed_delivery_latency_ms']),
      flutterEventSentAtMs: _alarmDebugInt(map['flutterEventSentAtMs']) ??
          _alarmDebugInt(map['flutter_event_sent_at_ms']),
      cancelledAtMs: _alarmDebugInt(map['cancelledAtMs']) ??
          _alarmDebugInt(map['cancelled_at_ms']),
      cancelReason: _alarmDebugString(map['cancelReason']) ??
          _alarmDebugString(map['cancel_reason']),
      nodeRunning: _alarmDebugBool(map['nodeRunning']) ??
          _alarmDebugBool(map['node_running']),
      stateUnavailableReason:
          _alarmDebugString(map['stateUnavailableReason']) ??
              _alarmDebugString(map['state_unavailable_reason']),
    );
  }

  final String alarmId;
  final bool pendingIntentExists;
  final bool? canScheduleExactAlarms;
  final int? scheduledAtMs;
  final int? triggerAtMs;
  final int? slotNumber;
  final int? globalSlot;
  final int? epoch;
  final int? slotTimeMs;
  final int? rustSlotTimeMs;
  final int? localSlotTimeMs;
  final int? alarmTimeMs;
  final int? nativeTriggerAtMs;
  final int? scheduledElapsedRealtimeMs;
  final int? triggerElapsedRealtimeMs;
  final int? requestedDelayMs;
  final int? effectiveDelayMs;
  final int? rustWakeTimeMs;
  final int? localWakeTimeMs;
  final int? clockDriftMs;
  final int? nodeTimeMsAtSchedule;
  final int? systemTimeMsAtSchedule;
  final int? clockDriftSampleAgeMs;
  final String? purpose;
  final String? schedulerReason;
  final String? scheduleStatus;
  final String? scheduleFailureReason;
  final int? receiverEnteredAtMs;
  final int? receiverSystemTimeMs;
  final int? receiverElapsedRealtimeMs;
  final int? receiverLatencyMs;
  final int? nativeDeliveryLatencyMs;
  final int? elapsedDeliveryLatencyMs;
  final int? flutterEventSentAtMs;
  final int? cancelledAtMs;
  final String? cancelReason;
  final bool? nodeRunning;
  final String? stateUnavailableReason;

  Map<String, dynamic> get telemetryDetails => {
        'native_pending_intent_exists': pendingIntentExists,
        if (canScheduleExactAlarms != null)
          'native_can_schedule_exact_alarms': canScheduleExactAlarms,
        if (scheduledAtMs != null)
          'native_alarm_scheduled_at_ms': scheduledAtMs,
        if (triggerAtMs != null) 'native_alarm_trigger_at_ms': triggerAtMs,
        if (slotNumber != null) 'native_alarm_slot_number': slotNumber,
        if (globalSlot != null) 'native_alarm_global_slot': globalSlot,
        if (epoch != null) 'native_alarm_epoch': epoch,
        if (slotTimeMs != null) 'native_alarm_slot_time_ms': slotTimeMs,
        if (rustSlotTimeMs != null)
          'native_alarm_rust_slot_time_ms': rustSlotTimeMs,
        if (localSlotTimeMs != null)
          'native_alarm_local_slot_time_ms': localSlotTimeMs,
        if (alarmTimeMs != null) 'native_alarm_alarm_time_ms': alarmTimeMs,
        if (nativeTriggerAtMs != null)
          'native_alarm_native_trigger_at_ms': nativeTriggerAtMs,
        if (scheduledElapsedRealtimeMs != null)
          'native_alarm_scheduled_elapsed_realtime_ms':
              scheduledElapsedRealtimeMs,
        if (triggerElapsedRealtimeMs != null)
          'native_alarm_trigger_elapsed_realtime_ms': triggerElapsedRealtimeMs,
        if (requestedDelayMs != null)
          'native_alarm_requested_delay_ms': requestedDelayMs,
        if (effectiveDelayMs != null)
          'native_alarm_effective_delay_ms': effectiveDelayMs,
        if (rustWakeTimeMs != null)
          'native_alarm_rust_wake_time_ms': rustWakeTimeMs,
        if (localWakeTimeMs != null)
          'native_alarm_local_wake_time_ms': localWakeTimeMs,
        if (clockDriftMs != null) 'native_alarm_clock_drift_ms': clockDriftMs,
        if (nodeTimeMsAtSchedule != null)
          'native_alarm_node_time_ms_at_schedule': nodeTimeMsAtSchedule,
        if (systemTimeMsAtSchedule != null)
          'native_alarm_system_time_ms_at_schedule': systemTimeMsAtSchedule,
        if (clockDriftSampleAgeMs != null)
          'native_alarm_clock_drift_sample_age_ms': clockDriftSampleAgeMs,
        if (purpose != null) 'native_alarm_purpose': purpose,
        if (schedulerReason != null)
          'native_alarm_scheduler_reason': schedulerReason,
        if (scheduleStatus != null)
          'native_alarm_schedule_status': scheduleStatus,
        if (scheduleFailureReason != null)
          'native_alarm_schedule_failure_reason': scheduleFailureReason,
        if (receiverEnteredAtMs != null)
          'native_alarm_receiver_entered_at_ms': receiverEnteredAtMs,
        if (receiverSystemTimeMs != null)
          'native_alarm_receiver_system_time_ms': receiverSystemTimeMs,
        if (receiverElapsedRealtimeMs != null)
          'native_alarm_receiver_elapsed_realtime_ms':
              receiverElapsedRealtimeMs,
        if (receiverLatencyMs != null)
          'native_alarm_receiver_latency_ms': receiverLatencyMs,
        if (nativeDeliveryLatencyMs != null)
          'native_alarm_native_delivery_latency_ms': nativeDeliveryLatencyMs,
        if (elapsedDeliveryLatencyMs != null)
          'native_alarm_elapsed_delivery_latency_ms': elapsedDeliveryLatencyMs,
        if (flutterEventSentAtMs != null)
          'native_alarm_flutter_event_sent_at_ms': flutterEventSentAtMs,
        if (cancelledAtMs != null)
          'native_alarm_cancelled_at_ms': cancelledAtMs,
        if (cancelReason != null) 'native_alarm_cancel_reason': cancelReason,
        if (nodeRunning != null) 'native_alarm_node_running': nodeRunning,
        if (stateUnavailableReason != null)
          'alarm_debug_state_unavailable_reason': stateUnavailableReason,
      };
}

/// Abstract interface for platform-specific alarm/wake-up scheduling
///
/// Android: Uses AlarmManager with exact alarms and Foreground Service
/// iOS: Uses BGProcessingTask and local notifications
class PlatformAlarmService {
  static final PlatformAlarmService instance = PlatformAlarmService._();
  PlatformAlarmService._({ObservabilityReportingService? observability})
      : _observability =
            observability ?? ObservabilityReportingService.instance;

  @visibleForTesting
  PlatformAlarmService.test({
    required ObservabilityReportingService observability,
  }) : _observability = observability;

  static const MethodChannel _channel = MethodChannel('com.usernode.app/alarm');
  final ObservabilityReportingService _observability;

  bool _initialized = false;
  bool _permissionsGranted = false;
  String? _lastAlarmFiredEventKey;
  DateTime? _lastAlarmFiredEventAt;

  static const _alarmFiredDuplicateWindow = Duration(seconds: 10);

  /// Callback to invoke when device reboots and alarms need to be rescheduled
  BootRescheduleCallback? _onBootReschedule;

  /// Callback to invoke when native platform sends a block production event
  NativeEventCallback? _onNativeEvent;

  /// Initialize the platform alarm service
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      _log.info(
          'PlatformAlarmService initializing for ${Platform.operatingSystem}...');

      // Set up method call handler for platform->Flutter calls
      _channel.setMethodCallHandler(_handleMethodCall);

      if (Platform.isAndroid) {
        await _initializeAndroid();
      } else if (Platform.isIOS) {
        await _initializeIOS();
      }

      _initialized = true;
      _log.info('PlatformAlarmService initialized');
      return true;
    } catch (e) {
      _log.error('Error initializing PlatformAlarmService: $e');
      return false;
    }
  }

  /// Handle method calls from platform (Android/iOS)
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    _log.debug('Method call from platform: ${call.method}');

    switch (call.method) {
      case 'rescheduleAfterBoot':
        return await _handleRescheduleAfterBoot();
      case 'onBlockProductionEvent':
        return await _handleNativeEvent(call.arguments);
      default:
        _log.warn('Unknown method call: ${call.method}');
        throw MissingPluginException('Method ${call.method} not implemented');
    }
  }

  /// Handle a native block production event from platform code
  Future<bool> _handleNativeEvent(dynamic arguments) async {
    try {
      if (arguments == null) {
        _log.warn('Received null arguments for onBlockProductionEvent');
        return false;
      }

      final Map<String, dynamic> args = Map<String, dynamic>.from(arguments);
      final String? eventType = args['eventType'] as String?;
      final Map<String, dynamic>? eventData = args['eventData'] != null
          ? Map<String, dynamic>.from(args['eventData'])
          : null;

      if (eventType == null) {
        _log.warn('Received native event with null eventType');
        return false;
      }

      _log.debug('Native event received: $eventType');

      _recordNativeAlarmFiredEvent(eventType, eventData ?? {});

      if (_onNativeEvent == null) {
        _log.warn('No native event callback registered for event: $eventType');
        return false;
      }

      return await _onNativeEvent!(eventType, eventData ?? {});
    } catch (e, st) {
      _log.error(
        'Error handling native event: $e',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  void _recordNativeAlarmFiredEvent(
    String eventType,
    Map<String, dynamic> eventData,
  ) {
    if (eventType != 'android_alarm_fired' &&
        eventType != 'ios_bgtask_executed') {
      return;
    }

    final alarmId = _stringFromDynamic(eventData['alarmId']);
    final legacySlotNumber = _intFromDynamic(eventData['slotNumber']);
    final globalSlot = _globalSlotForAlarm(
      alarmId: alarmId,
      globalSlot: legacySlotNumber,
      data: eventData,
    );
    final alarmTimeMs = _intFromDynamic(eventData['alarmTimeMs']);
    final eventKey = '$eventType:${alarmId ?? ''}:${alarmTimeMs ?? ''}:'
        '${globalSlot ?? legacySlotNumber ?? ''}';
    final now = DateTime.now();
    final lastAt = _lastAlarmFiredEventAt;
    if (_lastAlarmFiredEventKey == eventKey &&
        lastAt != null &&
        now.difference(lastAt) < _alarmFiredDuplicateWindow) {
      return;
    }

    _lastAlarmFiredEventKey = eventKey;
    _lastAlarmFiredEventAt = now;

    final firedAtMs =
        _intFromDynamic(eventData['firedAtMs']) ?? now.millisecondsSinceEpoch;
    final latencyMs = _intFromDynamic(eventData['latencyMs']) ??
        (alarmTimeMs == null ? null : firedAtMs - alarmTimeMs);

    _observability.reportBlockProductionAlarmFired(
      nativeEvent: eventType,
      alarmId: alarmId,
      purpose: _alarmPurposeForNativeEvent(eventType, alarmId),
      globalSlot: globalSlot,
      alarmTimeMs: alarmTimeMs,
      firedAtMs: firedAtMs,
      latencyMs: latencyMs,
      nativeTriggerAtMs: _intFromDynamic(eventData['nativeTriggerAtMs']),
      triggerElapsedRealtimeMs:
          _intFromDynamic(eventData['triggerElapsedRealtimeMs']),
      receiverElapsedRealtimeMs:
          _intFromDynamic(eventData['receiverElapsedRealtimeMs']),
      nativeDeliveryLatencyMs:
          _intFromDynamic(eventData['nativeDeliveryLatencyMs']),
      elapsedDeliveryLatencyMs:
          _intFromDynamic(eventData['elapsedDeliveryLatencyMs']),
      platform: Platform.operatingSystem,
      nodeRunning: _boolFromDynamic(eventData['nodeRunning']),
      batteryLevel: _intFromDynamic(eventData['batteryLevel']),
      networkState: _stringFromDynamic(eventData['networkState']),
    );
  }

  @visibleForTesting
  void handleNativeEventForTest(
    String eventType,
    Map<String, dynamic> eventData,
  ) {
    _recordNativeAlarmFiredEvent(eventType, eventData);
  }

  String _alarmPurposeForNativeEvent(String eventType, String? alarmId) {
    if (alarmId != null) return _alarmPurpose(alarmId, const {});
    if (eventType == 'ios_bgtask_executed') return 'ios_background_task';
    return 'block_production_wake';
  }

  /// Set the callback to invoke when device reboots
  void setBootRescheduleCallback(BootRescheduleCallback callback) {
    _onBootReschedule = callback;
    _log.debug('Boot reschedule callback registered');
  }

  /// Set the callback to invoke when native platform sends an event
  void setNativeEventCallback(NativeEventCallback callback) {
    _onNativeEvent = callback;
    _log.debug('Native event callback registered');
    // AppBootstrap marks native events ready only after RustLib.init() completes.
  }

  /// Handle alarm rescheduling after device reboot
  Future<void> _handleRescheduleAfterBoot() async {
    try {
      _log.info(
          'Handling rescheduleAfterBoot - device rebooted, restoring alarms...');

      if (_onBootReschedule == null) {
        _log.warn('No boot reschedule callback registered!');
        return;
      }

      // Invoke the registered callback
      await _onBootReschedule!();

      _log.info('✓ Boot reschedule callback completed');
    } catch (e) {
      _log.error('Error in rescheduleAfterBoot: $e');
      rethrow;
    }
  }

  Future<void> markReadyForNativeEvents() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod<bool>('markFlutterReadyForAlarmEvents');
      _log.debug('Marked Flutter alarm channel ready on native side');
    } on PlatformException catch (e) {
      _log.warn(
        'Failed to mark Flutter alarm channel ready: ${e.message}',
      );
    } catch (e) {
      _log.warn('Failed to mark Flutter alarm channel ready: $e');
    }
  }

  /// Initialize Android-specific alarm capabilities
  Future<void> _initializeAndroid() async {
    try {
      // Check if all required permissions are granted
      final hasNotifications =
          await _channel.invokeMethod<bool>('hasPostNotificationsPermission') ??
              false;
      final hasExactAlarm =
          await _channel.invokeMethod<bool>('hasExactAlarmPermission') ?? false;

      _permissionsGranted = hasNotifications && hasExactAlarm;

      if (!hasNotifications) {
        _log.warn('Android POST_NOTIFICATIONS permission not granted');
      }
      if (!hasExactAlarm) {
        _log.warn('Android exact alarm permission not granted');
      }
      if (_permissionsGranted) {
        _log.info('All Android permissions granted');
      }
    } on PlatformException catch (e) {
      _log.error('Error initializing Android alarm service: ${e.message}');
    }
  }

  /// Initialize iOS-specific background task capabilities
  Future<void> _initializeIOS() async {
    try {
      // BGTasks are already registered in AppDelegate.didFinishLaunchingWithOptions
      // Apple requires BGTaskScheduler.register() to be called BEFORE app launch completes
      // Calling it again here would violate this requirement and cause main thread blocking
      _log.info(
          'iOS background tasks already registered during app launch (AppDelegate)');

      // Just mark as ready - no need to call native code again
      _permissionsGranted = true;
      _log.info('iOS alarm service initialized successfully');
    } on PlatformException catch (e) {
      _log.error('Error initializing iOS alarm service: ${e.message}');
    }
  }

  /// Check if necessary permissions are granted
  bool get hasPermissions => _permissionsGranted;

  Future<bool> refreshPermissions() async {
    if (!_initialized) {
      _log.debug('Cannot refresh permissions: service not initialized');
      return false;
    }

    if (Platform.isAndroid) {
      final hasNotifications = await hasPostNotificationsPermission();
      final hasExactAlarm = await hasExactAlarmPermission();
      _permissionsGranted = hasNotifications && hasExactAlarm;
      return _permissionsGranted;
    }

    if (Platform.isIOS) {
      _permissionsGranted = true;
      return true;
    }

    _permissionsGranted = false;
    return false;
  }

  /// Request platform-specific permissions
  ///
  /// Android: Opens system settings for exact alarm permission
  /// iOS: Requests notification permissions (if not already granted)
  Future<bool> requestPermissions() async {
    if (!_initialized) {
      _log.warn('Cannot request permissions: service not initialized');
      return false;
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _requestAndroidPermissions();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        return await _requestIOSNotificationPermission();
      }
      return false;
    } catch (e) {
      _log.error('Error requesting permissions: $e');
      return false;
    }
  }

  /// Requests only the node-runtime permissions: SCHEDULE_EXACT_ALARM and the
  /// battery-optimization exemption. Deliberately excludes notifications so
  /// the SV "node needs alarm & battery" sheet never double-prompts.
  ///
  /// Not applicable off Android: resolves true without any platform traffic.
  Future<bool> requestAlarmPermissions() async {
    if (!_initialized) {
      _log.warn('Cannot request alarm permissions: service not initialized');
      return false;
    }
    if (defaultTargetPlatform != TargetPlatform.android) return true;

    try {
      final hasExactAlarm = await _requestAndroidExactAlarmAndBattery();
      _recordRuntimeContextChanged('permissions_changed');
      _recordPowerNetworkServiceContextChanged('permissions_changed');
      return hasExactAlarm;
    } on PlatformException catch (e) {
      _log.error('Error requesting alarm permissions: ${e.message}');
      return false;
    }
  }

  /// Requests only the notification permission (POST_NOTIFICATIONS on
  /// Android 13+, UNUserNotificationCenter on iOS).
  Future<bool> requestNotificationsPermission() async {
    if (!_initialized) {
      _log.warn(
          'Cannot request notification permission: service not initialized');
      return false;
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final granted = await _requestAndroidNotificationsPermission();
        _recordRuntimeContextChanged('permissions_changed');
        return granted;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return await _requestIOSNotificationPermission();
      }
      return false;
    } on PlatformException catch (e) {
      _log.error('Error requesting notification permission: ${e.message}');
      return false;
    }
  }

  /// Whether the OS notification permission is currently granted.
  Future<bool> hasNotificationsPermission() async {
    try {
      final method = defaultTargetPlatform == TargetPlatform.android
          ? 'hasPostNotificationsPermission'
          : 'hasNotificationPermission';
      return await _channel.invokeMethod<bool>(method) ?? false;
    } catch (e) {
      _log.warn('Notification permission probe failed: $e');
      return false;
    }
  }

  /// Opens the OS notification settings page for this app — the only path
  /// left once the OS dialog is exhausted (iOS shows it once ever; Android
  /// stops after two denials).
  Future<bool> openNotificationSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openNotificationSettings') ??
          false;
    } catch (e) {
      _log.error('Error opening notification settings: $e');
      return false;
    }
  }

  /// Current exact-alarm/battery state for the bridge's `startNode` response.
  /// Off Android both concepts are meaningless: `applicable` is false and the
  /// states are null so SV can skip its sheet.
  Future<Map<String, Object?>> alarmPermissionsSnapshot() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const {
        'applicable': false,
        'exactAlarmGranted': null,
        'batteryOptDisabled': null,
      };
    }
    // Independent probes with a short timeout each: one failing (or a stuck
    // channel) must neither block startNode's resolution nor mask the other.
    bool exactAlarm = false;
    bool batteryOptDisabled = false;
    try {
      exactAlarm = await _channel
              .invokeMethod<bool>('hasExactAlarmPermission')
              .timeout(const Duration(seconds: 3)) ??
          false;
    } catch (e) {
      _log.warn('Exact-alarm permission probe failed: $e');
    }
    try {
      batteryOptDisabled = await _channel
              .invokeMethod<bool>('isBatteryOptimizationDisabled')
              .timeout(const Duration(seconds: 3)) ??
          false;
    } catch (e) {
      _log.warn('Battery optimization probe failed: $e');
    }
    return {
      'applicable': true,
      'exactAlarmGranted': exactAlarm,
      'batteryOptDisabled': batteryOptDisabled,
    };
  }

  /// Request Android permissions (POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, Battery Optimization)
  Future<bool> _requestAndroidPermissions() async {
    try {
      _log.info('Requesting Android permissions...');

      // 1. Request POST_NOTIFICATIONS first (Android 13+)
      final hasNotifications = await _requestAndroidNotificationsPermission();

      // 2 + 3. Exact alarm and battery exemption.
      final hasExactAlarm = await _requestAndroidExactAlarmAndBattery();

      // Update permissions granted status
      _permissionsGranted = hasNotifications && hasExactAlarm;

      _recordRuntimeContextChanged('permissions_changed');
      _recordPowerNetworkServiceContextChanged('permissions_changed');

      return _permissionsGranted;
    } on PlatformException catch (e) {
      _log.error('Error requesting Android permissions: ${e.message}');
      return false;
    }
  }

  Future<bool> _requestAndroidNotificationsPermission() async {
    bool hasNotifications =
        await _channel.invokeMethod<bool>('hasPostNotificationsPermission') ??
            false;

    if (!hasNotifications) {
      _log.info('Requesting POST_NOTIFICATIONS permission...');
      await _channel.invokeMethod('requestPostNotificationsPermission');
      // Wait a bit for the permission dialog to be processed
      await Future.delayed(const Duration(milliseconds: 500));
      hasNotifications =
          await _channel.invokeMethod<bool>('hasPostNotificationsPermission') ??
              false;
    }
    return hasNotifications;
  }

  /// Runs the SCHEDULE_EXACT_ALARM and battery-exemption steps; returns
  /// whether the exact-alarm permission is granted afterwards.
  Future<bool> _requestAndroidExactAlarmAndBattery() async {
    bool hasExactAlarm =
        await _channel.invokeMethod<bool>('hasExactAlarmPermission') ?? false;

    if (!hasExactAlarm) {
      _log.info('Requesting SCHEDULE_EXACT_ALARM permission...');
      await _channel.invokeMethod('requestExactAlarmPermission');
      // This opens settings, so we'll need to wait for user to return
      // The permission check will happen when app resumes
    }

    bool hasBatteryExemption =
        await _channel.invokeMethod<bool>('isBatteryOptimizationDisabled') ??
            false;

    if (!hasBatteryExemption) {
      _log.info('Requesting battery optimization exemption...');
      await _channel.invokeMethod('requestBatteryOptimizationExemption');
      // This may open a dialog or settings
      await Future.delayed(const Duration(milliseconds: 500));
      hasBatteryExemption =
          await _channel.invokeMethod<bool>('isBatteryOptimizationDisabled') ??
              false;
    }

    _log.info(
        'Alarm permission status - Exact Alarm: $hasExactAlarm, Battery: $hasBatteryExemption');

    return hasExactAlarm;
  }

  /// Request iOS notification permissions
  Future<bool> _requestIOSNotificationPermission() async {
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestNotificationPermission') ??
              false;
      _permissionsGranted = granted;

      if (granted) {
        _log.info('iOS notification permission granted');
      } else {
        _log.warn('iOS notification permission denied');
      }

      _recordRuntimeContextChanged('permissions_changed');

      return granted;
    } on PlatformException catch (e) {
      _log.error('Error requesting iOS permissions: ${e.message}');
      return false;
    }
  }

  /// Request ONLY the Android exact alarm permission (NEW_UX onboarding step 1)
  ///
  /// On Android 12+ this opens the system settings where the user can allow
  /// exact alarms for the app. On other platforms, this returns true.
  Future<bool> requestExactAlarmOnly() async {
    if (!Platform.isAndroid) {
      return true;
    }
    if (!_initialized) {
      _log.warn('Cannot request exact alarm: service not initialized');
      return false;
    }
    try {
      await _channel.invokeMethod('requestExactAlarmPermission');
      // Give the system a moment and then re-check
      await Future.delayed(const Duration(milliseconds: 500));
      final hasExact = await hasExactAlarmPermission();
      // Do not force notifications here; just update combined flag conservatively
      if (hasExact) {
        _log.info('Exact alarm permission granted');
        await refreshPermissions();
      } else {
        _log.warn('Exact alarm permission still not granted');
      }
      return hasExact;
    } on PlatformException catch (e) {
      _log.error('Error requesting exact alarm permission: ${e.message}');
      return false;
    }
  }

  /// Check if POST_NOTIFICATIONS permission is granted (Android 13+)
  Future<bool> hasPostNotificationsPermission() async {
    if (!Platform.isAndroid) {
      return true; // iOS handles notifications separately
    }

    try {
      return await _channel
              .invokeMethod<bool>('hasPostNotificationsPermission') ??
          false;
    } on PlatformException catch (e) {
      _log.error('Error checking POST_NOTIFICATIONS permission: ${e.message}');
      return false;
    }
  }

  /// Check if SCHEDULE_EXACT_ALARM permission is granted (Android 12+)
  Future<bool> hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasExactAlarmPermission') ??
          false;
    } on PlatformException catch (e) {
      _log.error('Error checking exact alarm permission: ${e.message}');
      return false;
    }
  }

  Future<bool> hasScheduledAlarm(String alarmId) async {
    if (!Platform.isAndroid) return false;
    if (!_initialized) {
      _log.debug('Cannot check scheduled alarm: service not initialized');
      return false;
    }

    try {
      return await _channel.invokeMethod<bool>(
            'hasScheduledAlarm',
            {'alarmId': alarmId},
          ) ??
          false;
    } on PlatformException catch (e) {
      _log.warn('Error checking scheduled alarm $alarmId: ${e.message}');
      return false;
    } catch (e) {
      _log.warn('Error checking scheduled alarm $alarmId: $e');
      return false;
    }
  }

  Future<AlarmDebugState> getAlarmDebugState(String alarmId) async {
    if (!Platform.isAndroid) {
      return AlarmDebugState(
        alarmId: alarmId,
        pendingIntentExists: false,
        stateUnavailableReason: 'unsupported_platform',
      );
    }
    if (!_initialized) {
      _log.debug('Cannot get alarm debug state: service not initialized');
      return AlarmDebugState(
        alarmId: alarmId,
        pendingIntentExists: false,
        stateUnavailableReason: 'service_not_initialized',
      );
    }

    try {
      final raw = await _channel.invokeMethod<Object?>(
        'getAlarmDebugState',
        {'alarmId': alarmId},
      );
      if (raw is Map) {
        return AlarmDebugState.fromMap(raw.cast<Object?, Object?>());
      }
      return AlarmDebugState(
        alarmId: alarmId,
        pendingIntentExists: await hasScheduledAlarm(alarmId),
        stateUnavailableReason: 'invalid_native_state',
      );
    } on PlatformException catch (e) {
      _log.warn('Error getting alarm debug state $alarmId: ${e.message}');
      return AlarmDebugState(
        alarmId: alarmId,
        pendingIntentExists: await hasScheduledAlarm(alarmId),
        stateUnavailableReason: 'platform_exception',
      );
    } catch (e) {
      _log.warn('Error getting alarm debug state $alarmId: $e');
      return AlarmDebugState(
        alarmId: alarmId,
        pendingIntentExists: await hasScheduledAlarm(alarmId),
        stateUnavailableReason: 'exception',
      );
    }
  }

  Future<bool> wasForceStoppedOnStartup() async {
    if (!Platform.isAndroid) return false;
    if (!_initialized) return false;

    try {
      return await _channel.invokeMethod<bool>('wasForceStoppedOnStartup') ??
          false;
    } on PlatformException catch (e) {
      _log.debug('Force-stop startup check unavailable: ${e.message}');
      return false;
    } catch (e) {
      _log.debug('Force-stop startup check failed: $e');
      return false;
    }
  }

  Future<bool> ensureAlarmWatchdogScheduled({required String reason}) async {
    if (!Platform.isAndroid) return false;
    if (!_initialized) {
      _log.debug('Cannot schedule alarm watchdog: service not initialized');
      return false;
    }

    try {
      final success = await _channel.invokeMethod<bool>(
            'ensureAlarmWatchdogScheduled',
            {'reason': reason},
          ) ??
          false;
      _observability.reportBlockProductionAlarmAuditEvent(
        event: 'android_workmanager_watchdog_scheduled',
        details: {
          'reason': reason,
          'periodic': true,
          'success': success,
        },
      );
      return success;
    } on PlatformException catch (e) {
      _log.warn('Error scheduling alarm watchdog: ${e.message}');
      _observability.reportBlockProductionAlarmAuditEvent(
        event: 'android_workmanager_watchdog_scheduled',
        details: {
          'reason': reason,
          'periodic': true,
          'success': false,
          'failure_reason': 'platform_exception',
          'error': e.message,
        },
      );
      return false;
    } catch (e) {
      _log.warn('Error scheduling alarm watchdog: $e');
      return false;
    }
  }

  Future<bool> requestAlarmWatchdogRun({required String reason}) async {
    if (!Platform.isAndroid) return false;
    if (!_initialized) {
      _log.debug('Cannot request alarm watchdog run: service not initialized');
      return false;
    }

    try {
      final success = await _channel.invokeMethod<bool>(
            'requestAlarmWatchdogRun',
            {'reason': reason},
          ) ??
          false;
      _observability.reportBlockProductionAlarmAuditEvent(
        event: 'android_workmanager_watchdog_scheduled',
        details: {
          'reason': reason,
          'one_time': true,
          'success': success,
        },
      );
      return success;
    } on PlatformException catch (e) {
      _log.warn('Error requesting alarm watchdog run: ${e.message}');
      return false;
    } catch (e) {
      _log.warn('Error requesting alarm watchdog run: $e');
      return false;
    }
  }

  Future<bool> cancelAlarmWatchdog() async {
    if (!Platform.isAndroid) return false;
    if (!_initialized) return false;

    try {
      return await _channel.invokeMethod<bool>('cancelAlarmWatchdog') ?? false;
    } on PlatformException catch (e) {
      _log.warn('Error cancelling alarm watchdog: ${e.message}');
      return false;
    } catch (e) {
      _log.warn('Error cancelling alarm watchdog: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getAlarmWatchdogState() async {
    if (!Platform.isAndroid) return null;
    if (!_initialized) return null;

    try {
      final raw = await _channel.invokeMethod<Object?>(
        'getAlarmWatchdogState',
      );
      if (raw is Map) {
        return raw.map((key, value) => MapEntry(key.toString(), value));
      }
    } on PlatformException catch (e) {
      _log.warn('Error getting alarm watchdog state: ${e.message}');
    } catch (e) {
      _log.warn('Error getting alarm watchdog state: $e');
    }
    return null;
  }

  Future<bool> isAlarmWatchdogDeliveryInProgress() async {
    if (!Platform.isAndroid) return false;

    try {
      return await _channel.invokeMethod<bool>(
            'isAlarmWatchdogDeliveryInProgress',
          ) ??
          false;
    } catch (e) {
      _log.warn('Error checking alarm watchdog delivery state: $e');
      return false;
    }
  }

  /// Request battery optimization exemption
  Future<bool> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) {
      return true; // iOS doesn't have this concept
    }

    try {
      await _channel.invokeMethod('requestBatteryOptimizationExemption');
      // Check if exemption was granted
      await Future.delayed(const Duration(milliseconds: 500));
      return await isBatteryOptimizationDisabled();
    } on PlatformException catch (e) {
      _log.error(
          'Error requesting battery optimization exemption: ${e.message}');
      return false;
    }
  }

  /// Schedule an exact alarm using a resolved delay.
  ///
  /// Android: Schedules exact alarm + starts Foreground Service
  /// iOS: Schedules BGProcessingTask + local notification
  Future<bool> scheduleAlarm({
    required String alarmId,
    required int globalSlot,
    required int delayMs,
    Map<String, dynamic>? data,
  }) async {
    final alarmData = Map<String, dynamic>.from(data ?? const {});
    final requestedDelayMs = delayMs;
    final normalizedDelayMs = delayMs < 0 ? 0 : delayMs;
    final scheduledAtMs = DateTime.now().millisecondsSinceEpoch;
    final alarmTimeMs = _intFromDynamic(alarmData['alarmTimeMs']) ??
        scheduledAtMs + normalizedDelayMs;
    alarmData.putIfAbsent('alarmTimeMs', () => alarmTimeMs);
    alarmData.putIfAbsent('systemTimeMsAtSchedule', () => scheduledAtMs);
    final resolvedGlobalSlot = _globalSlotForAlarm(
      alarmId: alarmId,
      globalSlot: globalSlot,
      data: alarmData,
    );
    if (resolvedGlobalSlot != null) {
      alarmData['globalSlot'] = resolvedGlobalSlot;
    }

    void recordScheduleResult({
      required bool success,
      String? failureReason,
    }) {
      final slotTimeMs = _slotTimeMsFromData(alarmData);
      final leadMs = slotTimeMs == null ? null : slotTimeMs - alarmTimeMs;
      _observability.reportBlockProductionAlarmScheduled(
        alarmId: alarmId,
        purpose: _alarmPurpose(alarmId, alarmData),
        globalSlot: resolvedGlobalSlot,
        epoch: _intFromDynamic(alarmData['epoch']),
        slotTimeMs: slotTimeMs,
        rustSlotTimeMs: _intFromDynamic(alarmData['rustSlotTimeMs']),
        localSlotTimeMs:
            _intFromDynamic(alarmData['localSlotTimeMs']) ?? slotTimeMs,
        scheduledAtMs: scheduledAtMs,
        alarmTimeMs: alarmTimeMs,
        requestedDelayMs: requestedDelayMs,
        delayMs: normalizedDelayMs,
        leadMs: leadMs,
        platform: Platform.operatingSystem,
        success: success,
        schedulerReason: _stringFromDynamic(alarmData['reason']),
        nodeRunning: _boolFromDynamic(alarmData['nodeRunning']),
        rustWakeTimeMs: _intFromDynamic(alarmData['rustWakeTimeMs']),
        localWakeTimeMs: _intFromDynamic(alarmData['localWakeTimeMs']),
        clockDriftMs: _intFromDynamic(alarmData['clockDriftMs']),
        nodeTimeMsAtSchedule:
            _intFromDynamic(alarmData['nodeTimeMsAtSchedule']),
        systemTimeMsAtSchedule:
            _intFromDynamic(alarmData['systemTimeMsAtSchedule']),
        clockDriftSampleAgeMs:
            _intFromDynamic(alarmData['clockDriftSampleAgeMs']),
        failureReason: failureReason,
      );
    }

    if (!_initialized) {
      _log.warn('Cannot schedule alarm: service not initialized');
      recordScheduleResult(
        success: false,
        failureReason: 'service_not_initialized',
      );
      return false;
    }

    if (!_permissionsGranted) {
      _log.warn('Cannot schedule alarm: permissions not granted');
      recordScheduleResult(
        success: false,
        failureReason: 'permissions_not_granted',
      );
      return false;
    }

    try {
      final params = {
        'alarmId': alarmId,
        'globalSlot': resolvedGlobalSlot ?? globalSlot,
        'delayMs': normalizedDelayMs,
        'data': alarmData,
      };

      bool success;
      if (Platform.isAndroid) {
        success = await _scheduleAndroidAlarm(params);
      } else if (Platform.isIOS) {
        success = await _scheduleIOSAlarm(params);
      } else {
        recordScheduleResult(
          success: false,
          failureReason: 'unsupported_platform',
        );
        return false;
      }

      recordScheduleResult(
        success: success,
        failureReason: success ? null : 'platform_schedule_failed',
      );
      return success;
    } catch (e) {
      _log.error('Error scheduling alarm: $e');
      recordScheduleResult(
        success: false,
        failureReason: 'schedule_exception',
      );
      return false;
    }
  }

  String _alarmPurpose(String alarmId, Map<String, dynamic> data) {
    final explicitPurpose = _stringFromDynamic(data['purpose']);
    if (explicitPurpose != null) return explicitPurpose;
    if (alarmId == 'fg_resume') return 'foreground_resume';
    return 'block_production_wake';
  }

  int? _globalSlotForAlarm({
    required String? alarmId,
    required int? globalSlot,
    required Map<String, dynamic> data,
  }) {
    for (final key in const [
      'globalSlot',
      'global_slot',
      'targetGlobalSlot',
      'target_global_slot',
    ]) {
      final explicit = _intFromDynamic(data[key]);
      if (explicit != null && explicit > 0) {
        return explicit;
      }
    }

    if (globalSlot != null && globalSlot > 0) {
      return globalSlot;
    }

    final alarmSlot = _slotFromAlarmId(alarmId);
    if (alarmSlot != null) {
      return alarmSlot;
    }

    return _slotFromReason(_stringFromDynamic(data['reason']));
  }

  int? _slotFromAlarmId(String? alarmId) {
    if (alarmId == null || !alarmId.startsWith('slot_')) {
      return null;
    }
    final slot = int.tryParse(alarmId.substring('slot_'.length));
    return slot != null && slot > 0 ? slot : null;
  }

  int? _slotFromReason(String? reason) {
    if (reason == null || !reason.startsWith('next_won_slot:')) {
      return null;
    }
    final slot = int.tryParse(reason.substring('next_won_slot:'.length));
    return slot != null && slot > 0 ? slot : null;
  }

  int? _slotTimeMsFromData(Map<String, dynamic> data) {
    final explicitMs = _intFromDynamic(data['slotTimeMs']);
    if (explicitMs != null) return explicitMs;

    final slotTime = _stringFromDynamic(data['slotTime']);
    if (slotTime == null) return null;
    return DateTime.tryParse(slotTime)?.millisecondsSinceEpoch;
  }

  int? _intFromDynamic(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  bool? _boolFromDynamic(Object? value) {
    if (value is bool) return value;
    if (value is String) {
      if (value == 'true') return true;
      if (value == 'false') return false;
    }
    return null;
  }

  String? _stringFromDynamic(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  /// Schedule Android exact alarm
  Future<bool> _scheduleAndroidAlarm(Map<String, dynamic> params) async {
    try {
      final success =
          await _channel.invokeMethod<bool>('scheduleExactAlarm', params) ??
              false;

      if (success) {
        _log.info(
            'Android exact alarm scheduled for global slot ${params['globalSlot']}');
      } else {
        _log.warn('Failed to schedule Android exact alarm');
      }

      return success;
    } on PlatformException catch (e) {
      _log.error('Error scheduling Android alarm: ${e.message}');
      return false;
    }
  }

  /// Schedule iOS background task and notification
  Future<bool> _scheduleIOSAlarm(Map<String, dynamic> params) async {
    try {
      final success =
          await _channel.invokeMethod<bool>('scheduleIOSBGTask', params) ??
              false;

      if (success) {
        _log.info(
            'iOS BGTask scheduled for global slot ${params['globalSlot']}');
      } else {
        _log.warn('Failed to schedule iOS BGTask');
      }

      return success;
    } on PlatformException catch (e) {
      _log.error('Error scheduling iOS BGTask: ${e.message}');
      return false;
    }
  }

  /// Cancel a specific alarm
  Future<bool> cancelAlarm(String alarmId) async {
    if (!_initialized) {
      _log.warn('Cannot cancel alarm: service not initialized');
      return false;
    }

    try {
      final success = await _channel
              .invokeMethod<bool>('cancelAlarm', {'alarmId': alarmId}) ??
          false;

      if (success) {
        _log.debug('Alarm cancelled: $alarmId');
      } else {
        _log.warn('Failed to cancel alarm: $alarmId');
      }

      return success;
    } on PlatformException catch (e) {
      _log.error('Error cancelling alarm: ${e.message}');
      return false;
    }
  }

  /// Cancel all scheduled alarms
  Future<bool> cancelAllAlarms() async {
    if (!_initialized) {
      _log.warn('Cannot cancel alarms: service not initialized');
      return false;
    }

    try {
      final success =
          await _channel.invokeMethod<bool>('cancelAllAlarms') ?? false;

      if (success) {
        _log.info('All alarms cancelled');
      } else {
        _log.warn('Failed to cancel all alarms');
      }

      return success;
    } on PlatformException catch (e) {
      _log.error('Error cancelling all alarms: ${e.message}');
      return false;
    }
  }

  /// Start foreground service (Android only)
  ///
  /// This must be called when an alarm fires to keep the app running
  /// during block production monitoring.
  Future<bool> startForegroundService({
    required String title,
    required String message,
    required int globalSlot,
  }) async {
    if (!Platform.isAndroid) {
      _log.debug('Foreground service is Android-only');
      return false;
    }

    try {
      final params = {
        'title': title,
        'message': message,
        'globalSlot': globalSlot,
      };

      final success =
          await _channel.invokeMethod<bool>('startForegroundService', params) ??
              false;

      if (success) {
        _log.info('Foreground service started for global slot $globalSlot');
        _recordPowerNetworkServiceContextChanged('foreground_service_changed');
      } else {
        _log.warn('Failed to start foreground service');
      }

      return success;
    } on PlatformException catch (e) {
      _log.error('Error starting foreground service: ${e.message}');
      return false;
    }
  }

  /// Stop foreground service (Android only)
  Future<bool> stopForegroundService() async {
    if (!Platform.isAndroid) {
      _log.debug('Foreground service is Android-only');
      return false;
    }

    try {
      final success =
          await _channel.invokeMethod<bool>('stopForegroundService') ?? false;

      if (success) {
        _log.info('Foreground service stopped');
        _recordPowerNetworkServiceContextChanged('foreground_service_changed');
      } else {
        _log.warn('Failed to stop foreground service');
      }

      return success;
    } on PlatformException catch (e) {
      _log.error('Error stopping foreground service: ${e.message}');
      return false;
    }
  }

  /// Start persistent foreground service (Android only)
  ///
  /// This keeps the app running continuously in the foreground,
  /// providing 100% reliability for block production monitoring
  /// at the cost of higher battery usage.
  Future<bool> startPersistentForegroundService() async {
    if (!Platform.isAndroid) {
      _log.debug('Persistent foreground service is Android-only');
      return false;
    }

    try {
      final success = await _channel
              .invokeMethod<bool>('startPersistentForegroundService') ??
          false;

      if (success) {
        _log.info('Persistent foreground service started');
        _recordPowerNetworkServiceContextChanged('foreground_service_changed');
      } else {
        _log.warn('Failed to start persistent foreground service');
      }

      return success;
    } on PlatformException catch (e) {
      _log.error('Error starting persistent foreground service: ${e.message}');
      return false;
    }
  }

  /// Stop persistent foreground service (Android only)
  Future<bool> stopPersistentForegroundService() async {
    if (!Platform.isAndroid) {
      _log.debug('Persistent foreground service is Android-only');
      return false;
    }

    try {
      final success = await _channel
              .invokeMethod<bool>('stopPersistentForegroundService') ??
          false;

      if (success) {
        _log.info('Persistent foreground service stopped');
        _recordPowerNetworkServiceContextChanged('foreground_service_changed');
      } else {
        _log.warn('Failed to stop persistent foreground service');
      }

      return success;
    } on PlatformException catch (e) {
      _log.error('Error stopping persistent foreground service: ${e.message}');
      return false;
    }
  }

  /// Check if persistent foreground service is running (Android only)
  Future<bool> isPersistentForegroundRunning() async {
    if (!Platform.isAndroid) return false;
    try {
      final isRunning =
          await _channel.invokeMethod<bool>('isPersistentForegroundRunning');
      return isRunning ?? false;
    } catch (e) {
      _log.error('Error checking persistent foreground status: $e');
      return false;
    }
  }

  /// Open battery optimization settings
  ///
  /// Helps users exempt the app from battery optimization on OEM devices.
  Future<bool> openBatteryOptimizationSettings() async {
    try {
      final success =
          await _channel.invokeMethod<bool>('openBatterySettings') ?? false;

      if (success) {
        _log.info('Opened battery optimization settings');
      } else {
        _log.warn('Failed to open battery optimization settings');
      }

      return success;
    } on PlatformException catch (e) {
      _log.error('Error opening battery settings: ${e.message}');
      return false;
    }
  }

  /// Check if battery optimization is disabled for this app
  Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) {
      return true; // iOS doesn't have this concept
    }

    try {
      return await _channel
              .invokeMethod<bool>('isBatteryOptimizationDisabled') ??
          false;
    } on PlatformException catch (e) {
      _log.error('Error checking battery optimization: ${e.message}');
      return false;
    }
  }

  /// Get OEM device manufacturer
  ///
  /// Useful for providing OEM-specific guidance (Xiaomi, Samsung, Oppo, etc.)
  Future<String?> getDeviceManufacturer() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      return await _channel.invokeMethod<String>('getDeviceManufacturer');
    } on PlatformException catch (e) {
      _log.error('Error getting device manufacturer: ${e.message}');
      return null;
    }
  }

  /// Check if foreground service is currently running (Android only)
  Future<bool> isForegroundServiceRunning() async {
    if (!Platform.isAndroid) return false;
    try {
      final isRunning =
          await _channel.invokeMethod<bool>('isForegroundServiceRunning');
      return isRunning ?? false;
    } catch (e) {
      _log.error('Error checking foreground service status: $e');
      return false;
    }
  }

  /// Check if wakelock is currently held (Android only)
  Future<bool> isWakelockHeld() async {
    if (!Platform.isAndroid) return false;
    try {
      final isHeld = await _channel.invokeMethod<bool>('isWakelockHeld');
      return isHeld ?? false;
    } catch (e) {
      _log.error('Error checking wakelock status: $e');
      return false;
    }
  }

  /// Acquire a native Android PARTIAL_WAKE_LOCK (does not require a foreground Activity).
  ///
  /// This is used for background/foreground service work where `wakelock_plus` would throw
  /// `NoActivityException`.
  Future<bool> acquireWakelock() async {
    if (!Platform.isAndroid) return false;
    try {
      await _channel.invokeMethod('acquireWakelock');
      _recordRuntimeContextChanged('keep_alive_changed');
      _recordPowerNetworkServiceContextChanged('foreground_service_changed');
      return true;
    } catch (e) {
      _log.error('Error acquiring wakelock: $e');
      return false;
    }
  }

  /// Release the native Android PARTIAL_WAKE_LOCK.
  Future<bool> releaseWakelock() async {
    if (!Platform.isAndroid) return false;
    try {
      await _channel.invokeMethod('releaseWakelock');
      _recordRuntimeContextChanged('keep_alive_changed');
      _recordPowerNetworkServiceContextChanged('foreground_service_changed');
      return true;
    } catch (e) {
      _log.error('Error releasing wakelock: $e');
      return false;
    }
  }

  Future<bool> restartActivity() async {
    if (!Platform.isAndroid) {
      _log.debug('Activity restart is Android-only');
      return false;
    }

    try {
      final restarted =
          await _channel.invokeMethod<bool>('restartActivity') ?? false;

      if (restarted) {
        _log.info('Requested Android activity restart');
      } else {
        _log.warn('Android activity restart was not performed');
      }

      return restarted;
    } on PlatformException catch (e) {
      _log.error('Error restarting activity: ${e.message}');
      return false;
    }
  }

  /// Get background task execution statistics (Android only)
  Future<Map<String, dynamic>> getBackgroundTaskStats() async {
    if (!Platform.isAndroid) {
      return {
        'execution_count': 0,
        'last_execution_time': 0,
        'success_count': 0,
        'failure_count': 0,
      };
    }
    try {
      final stats = await _channel.invokeMethod<Map>('getBackgroundTaskStats');
      return Map<String, dynamic>.from(stats ?? {});
    } catch (e) {
      _log.error('Error getting background task stats: $e');
      return {
        'execution_count': 0,
        'last_execution_time': 0,
        'success_count': 0,
        'failure_count': 0,
      };
    }
  }

  /// Increment background task execution count (Android only)
  Future<void> incrementBackgroundTaskCount() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('incrementBackgroundTaskCount');
    } catch (e) {
      _log.error('Error incrementing background task count: $e');
    }
  }

  void _recordRuntimeContextChanged(String reason) {
    unawaited(
      _observability.reportRuntimeMobileContextSnapshot(
        reason: reason,
      ),
    );
  }

  void _recordPowerNetworkServiceContextChanged(String reason) {
    unawaited(
      _observability.reportPowerNetworkServiceContextSnapshot(
        reason: reason,
        force: true,
      ),
    );
  }

  void resetForAppRestart() {
    _initialized = false;
    _permissionsGranted = false;
    _onBootReschedule = null;
    _onNativeEvent = null;
  }
}

int? _alarmDebugInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool? _alarmDebugBool(Object? value) {
  if (value is bool) return value;
  if (value is String) {
    if (value == 'true') return true;
    if (value == 'false') return false;
  }
  return null;
}

String? _alarmDebugString(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

/// Result of an alarm scheduling operation
class AlarmScheduleResult {
  final bool success;
  final String? error;
  final bool needsPermission;
  final bool needsBatteryOptDisabled;

  AlarmScheduleResult({
    required this.success,
    this.error,
    this.needsPermission = false,
    this.needsBatteryOptDisabled = false,
  });
}
