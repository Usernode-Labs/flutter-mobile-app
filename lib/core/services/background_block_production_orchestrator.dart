import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/log_tag.dart';
import '../models/block_production_state.dart';
import '../models/block_production_event.dart';
import '../models/backend_rpc_response.dart';
import '../models/vrf_status.dart';
import '../data/block_production_state_repository.dart';
import '../data/slot_production_repository.dart';
import '../../features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import '../config/app_config.dart';
import 'platform_alarm_service.dart';
import 'slot_monitor_service.dart';
import 'epoch_slot_scheduler_service.dart' as legacy;

final _log = LoggingService.instance.withTag(LogTag.node);

/// Unified orchestrator for background block production
///
/// This service consolidates the functionality of:
/// - EpochSlotSchedulerService (epoch monitoring, slot scheduling)
/// - AlarmCallbackService (alarm callback handling)
/// - SlotNotificationManager (notification scheduling)
///
/// It provides a single entry point for all block production logic with:
/// - Smart epoch monitoring (VRF-aware, RPC-driven)
/// - Unified state management
/// - Event emission for metrics collection
/// - Integrated notification scheduling
class BackgroundBlockProductionOrchestrator {
  static final BackgroundBlockProductionOrchestrator instance =
      BackgroundBlockProductionOrchestrator._();
  BackgroundBlockProductionOrchestrator._();

  final _stateRepository = BlockProductionStateRepository.instance;
  final _battery = Battery();

  // State
  BlockProductionState _state = BlockProductionState.initial();
  bool _initialized = false;
  Timer? _epochMonitoringTimer;
  StreamSubscription<SlotMonitoringEvent>? _monitoringSubscription;

  // Event stream for metrics and observers
  final _eventController = StreamController<BlockProductionEvent>.broadcast();
  Stream<BlockProductionEvent> get events => _eventController.stream;

  // Configuration from AppConfig (.env variables)
  Duration get _baseEpochCheckInterval => AppConfig.epochMonitorBaseInterval;
  Duration get _wakeBeforeSlot => AppConfig.blockProductionWakeBeforeSlot;

  /// Check if the service is initialized
  bool get isInitialized => _initialized;

  /// Get current state (read-only)
  BlockProductionState get state => _state;

  /// Get current epoch
  int get currentEpoch => _state.currentEpoch;

  /// Get scheduled slots
  List<ScheduledSlot> get scheduledSlots => _state.scheduledSlots;

  /// Initialize the orchestrator
  ///
  /// This loads persisted state and starts epoch monitoring.
  Future<bool> initialize() async {
    if (_initialized) {
      _log.info('BackgroundBlockProductionOrchestrator already initialized');
      return true;
    }

    try {
      _log.info('Initializing BackgroundBlockProductionOrchestrator...');

      // Load persisted state
      _state = await _stateRepository.load();
      _log.info('Loaded state: ${_state.toString()}');

      // Start epoch monitoring
      _log.debug('Starting epoch monitoring');
      _startEpochMonitoring();

      // Register native event callback
      _log.debug('Registering native event callback');
      PlatformAlarmService.instance.setNativeEventCallback(_handleNativeEvent);
      _log.debug('Native event callback registered with PlatformAlarmService');

      // Perform initial epoch check
      _log.debug('Performing initial epoch check');
      await _checkEpochTransition();

      _initialized = true;
      LoggingService.instance.info(
          'BackgroundBlockProductionOrchestrator initialized successfully');
      return true;
    } catch (e, st) {
      _log.error('Error initializing BackgroundBlockProductionOrchestrator: $e',
          error: e, stackTrace: st);
      return false;
    }
  }

  /// Start periodic epoch monitoring with smart intervals
  void _startEpochMonitoring() {
    if (_epochMonitoringTimer != null && _epochMonitoringTimer!.isActive) {
      _log.debug('Epoch monitoring already active');
      return;
    }

    _log.info(
        'Starting epoch monitoring (base interval: $_baseEpochCheckInterval)');

    // Initial check uses base interval
    _epochMonitoringTimer = Timer.periodic(_baseEpochCheckInterval, (_) {
      _checkEpochTransition();
    });
  }

  /// Stop epoch monitoring
  void _stopEpochMonitoring() {
    if (_epochMonitoringTimer != null) {
      _log.info('Stopping epoch monitoring');
      _epochMonitoringTimer!.cancel();
      _epochMonitoringTimer = null;
    }
  }

  /// Check for epoch transitions with VRF awareness
  ///
  /// This is the smart epoch monitoring logic that queries the backend RPC
  /// and adjusts its behavior based on VRF calculation status.
  Future<void> _checkEpochTransition() async {
    try {
      _log.debug('Checking for epoch transition...');

      final now = DateTime.now();
      _state = _state.copyWith(lastEpochCheck: now);

      // Query backend for epoch info (includes VRF status)
      final epochInfo = await RustBackendService.instance.getEpochInfo();

      if (epochInfo == null) {
        _log.warn('Failed to get epoch info from backend');
        // Schedule retry in 5 minutes on error
        _rescheduleEpochCheck(const Duration(minutes: 5));
        return;
      }

      _log.debug('Backend epoch info: ${epochInfo.toString()}');

      // Update VRF status in state
      _state = _state.copyWith(currentVrfStatus: epochInfo.vrfStatus);

      // Check if epoch has changed
      if (_state.currentEpoch == 0 ||
          epochInfo.currentEpoch != _state.currentEpoch) {
        final oldEpoch = _state.currentEpoch;
        _log.info(
            'Epoch transition detected: $oldEpoch → ${epochInfo.currentEpoch}');
        await _handleEpochTransition(oldEpoch, epochInfo);
      } else {
        _log.debug('No epoch change (still epoch ${epochInfo.currentEpoch})');
      }

      // Calculate next check interval based on VRF status and epoch progress
      final nextCheckInterval = _calculateNextCheckInterval(epochInfo);
      _rescheduleEpochCheck(nextCheckInterval);

      // Persist updated state
      await _stateRepository.save(_state);
    } catch (e, st) {
      _log.error('Error checking epoch transition: $e',
          error: e, stackTrace: st);
      _emitEvent(BlockProductionErrorEvent(
        errorType: 'epoch_check',
        errorMessage: e.toString(),
        stackTrace: st.toString(),
      ));
      // Retry in 5 minutes on error
      _rescheduleEpochCheck(const Duration(minutes: 5));
    }
  }

  /// Handle epoch transition event
  Future<void> _handleEpochTransition(
      int? oldEpoch, BackendRPCResponse epochInfo) async {
    try {
      final newEpoch = epochInfo.currentEpoch;
      _log.info('Handling epoch transition to epoch $newEpoch');

      // Update epoch in state
      _state = _state.copyWith(currentEpoch: newEpoch);

      // Cancel old epoch alarms
      if (_state.scheduledSlots.isNotEmpty) {
        _log.info(
            'Cancelling ${_state.scheduledSlots.length} alarms from old epoch');
        await _cancelAllSlotAlarms();
      }

      // Check if VRF is complete and we can schedule slots
      if (epochInfo.canScheduleSlots) {
        _log.info(
            'VRF complete! Scheduling ${epochInfo.wonSlots.length} won slots');
        final slotsScheduled = await _scheduleSlots(epochInfo.wonSlots);

        // Get next alarm time (first scheduled slot)
        DateTime? nextAlarmTime;
        if (_state.scheduledSlots.isNotEmpty) {
          nextAlarmTime = _state.scheduledSlots
              .map((s) => s.alarmTime)
              .reduce((a, b) => a.isBefore(b) ? a : b);
          _log.debug('Next alarm scheduled for: $nextAlarmTime');
        }

        // Emit epoch transition event with enhanced metadata
        _emitEvent(BlockProductionEpochTransitionEvent(
          previousEpoch: oldEpoch ?? 0,
          newEpoch: newEpoch,
          slotsScheduled: slotsScheduled,
          vrfStatus: epochInfo.vrfStatus.displayName,
          nextAlarmTime: nextAlarmTime,
        ));
      } else {
        _log.info(
            'VRF not complete yet (status: ${epochInfo.vrfStatus.displayName}), will check again');

        // Emit epoch transition event with no slots scheduled yet
        _emitEvent(BlockProductionEpochTransitionEvent(
          previousEpoch: oldEpoch ?? 0,
          newEpoch: newEpoch,
          slotsScheduled: 0,
          vrfStatus: epochInfo.vrfStatus.displayName,
        ));
      }

      // Persist state
      await _stateRepository.save(_state);
    } catch (e, st) {
      _log.error('Error handling epoch transition: $e',
          error: e, stackTrace: st);
      _emitEvent(BlockProductionErrorEvent(
        errorType: 'epoch_transition',
        errorMessage: e.toString(),
        stackTrace: st.toString(),
      ));
    }
  }

  /// Calculate next epoch check interval based on VRF status and progress
  ///
  /// Smart interval calculation:
  /// - VRF complete: Check near end of epoch (save resources)
  /// - VRF in progress with ETA: Check at ETA + buffer
  /// - VRF in progress with progress: Use progress-based intervals
  /// - VRF not started: Check in 10 minutes
  /// - Error or unknown: Use base interval
  Duration _calculateNextCheckInterval(BackendRPCResponse epochInfo) {
    // If VRF complete, check again near the end of the epoch
    if (epochInfo.vrfStatus == VRFStatus.complete) {
      // Check 5 minutes before epoch is expected to end
      // For now, use a long interval since we don't calculate exact epoch end time yet
      final longInterval = const Duration(hours: 1); // Simplified for Phase 2
      _log.debug(
          'VRF complete, scheduling next check in ${longInterval.inMinutes} minutes');
      return longInterval;
    }

    // If VRF has estimated time remaining, use it + buffer
    if (epochInfo.vrfEstimatedTimeRemaining != null) {
      final interval = epochInfo.vrfEstimatedTimeRemaining! +
          const Duration(minutes: 1); // 1 min buffer
      _log.debug(
          'VRF ETA available, scheduling next check in ${interval.inMinutes} minutes');
      return interval;
    }

    // If VRF has progress info, use progress-based intervals
    if (epochInfo.vrfProgress != null) {
      final progress = epochInfo.vrfProgress!;
      Duration interval;

      if (progress < 0.25) {
        interval = const Duration(minutes: 10); // Check in 10 minutes
      } else if (progress < 0.75) {
        interval = const Duration(minutes: 5); // Check in 5 minutes
      } else {
        interval = const Duration(minutes: 2); // Check in 2 minutes
      }

      _log.debug(
          'VRF progress ${(progress * 100).toStringAsFixed(1)}%, next check in ${interval.inMinutes} minutes');
      return interval;
    }

    // If VRF not started, check in 10 minutes
    if (epochInfo.vrfStatus == VRFStatus.notStarted) {
      _log.debug('VRF not started, scheduling next check in 10 minutes');
      return const Duration(minutes: 10);
    }

    // Fallback to base interval
    _log.debug(
        'Using base interval for next check: ${_baseEpochCheckInterval.inMinutes} minutes');
    return _baseEpochCheckInterval;
  }

  /// Reschedule the epoch monitoring timer with a new interval
  void _rescheduleEpochCheck(Duration interval) {
    _stopEpochMonitoring();
    _log.debug('Rescheduling epoch check in ${interval.inMinutes} minutes');
    _epochMonitoringTimer = Timer.periodic(interval, (_) {
      _checkEpochTransition();
    });
  }

  /// Handle app resumed event
  ///
  /// This is called when the app comes back to the foreground.
  /// It performs an immediate epoch check.
  Future<void> onAppResumed() async {
    _log.info('App resumed, performing immediate epoch check');

    // Emit app resumed event
    _emitEvent(BlockProductionAppResumedEvent(
      currentEpoch: _state.currentEpoch,
      nodeRunning: RustBackendService.instance.isRunning,
      scheduledSlotsCount: _state.scheduledSlots.length,
    ));

    // Perform immediate epoch check
    await _checkEpochTransition();
  }

  /// Handle slot wake up (alarm fired)
  ///
  /// This is called when a platform alarm fires for a scheduled slot.
  Future<void> handleSlotWakeUp(int slotNumber) async {
    try {
      _log.info('Slot wake-up for slot $slotNumber');

      final now = DateTime.now();
      _state = _state.copyWith(lastWakeUp: now);

      // Get battery level
      int batteryLevel = 0;
      try {
        _log.debug('Attempting to get battery level for wake-up event...');
        batteryLevel = await _battery.batteryLevel;
        _log.debug('Battery level for wake-up: $batteryLevel%');
      } catch (e, stackTrace) {
        _log.warn('Could not get battery level: $e');
        _log.debug('Battery error stacktrace: $stackTrace');
      }

      // Calculate alarm latency (find scheduled slot)
      final scheduledSlot = _state.scheduledSlots
          .where((s) => s.slotNumber == slotNumber)
          .firstOrNull;
      int? alarmLatencyMs;
      if (scheduledSlot != null) {
        alarmLatencyMs = now.difference(scheduledSlot.alarmTime).inMilliseconds;
        _log.debug('Alarm latency: ${alarmLatencyMs}ms');
      }

      // Start foreground service (Android)
      try {
        await PlatformAlarmService.instance.startForegroundService(
          title: 'Block Production',
          message: 'Monitoring slot $slotNumber',
          slotNumber: slotNumber,
        );
        _log.debug('Started foreground service');
      } catch (e) {
        _log.warn('Error starting foreground service: $e');
        // Continue anyway - not critical
      }

      // Emit app wake-up event with enhanced metadata (PROOF that alarm worked!)
      _emitEvent(BlockProductionAppWakeUpEvent(
        slotNumber: slotNumber,
        alarmTime: now,
        batteryLevel: batteryLevel,
        alarmLatencyMs: alarmLatencyMs,
        deviceState: 'active', // Could be enhanced with actual device state
        networkStatus: 'unknown', // Could be enhanced with network_info package
        wakeSource: 'alarm', // Default to alarm
      ));

      // Find the scheduled slot
      final slot = _state.scheduledSlots.firstWhere(
        (s) => s.slotNumber == slotNumber,
        orElse: () => ScheduledSlot(
          slotNumber: slotNumber,
          slotTime: now,
          alarmTime: now,
          epoch: _state.currentEpoch,
        ),
      );

      // Start slot monitoring
      await _startSlotMonitoring(slot);

      // Persist state
      await _stateRepository.save(_state);
    } catch (e, st) {
      _log.error('Error handling slot wake-up: $e', error: e, stackTrace: st);
      _emitEvent(BlockProductionErrorEvent(
        errorType: 'slot_wake_up',
        errorMessage: e.toString(),
        stackTrace: st.toString(),
      ));
    }
  }

  /// Start monitoring a slot for block production
  Future<void> _startSlotMonitoring(ScheduledSlot slot) async {
    try {
      _log.info('Starting slot monitoring for slot ${slot.slotNumber}');

      // Get node state for the monitoring start event
      String nodeState = 'unknown';
      try {
        final status = await RustBackendService.instance.getStatus();
        nodeState = status?.blockProducer?.status.toString() ?? 'unknown';
      } catch (e) {
        _log.warn('Could not get node state: $e');
      }

      // Emit monitoring start event
      _emitEvent(BlockProductionMonitoringStartEvent(
        slotNumber: slot.slotNumber,
        slotTime: slot.slotTime,
        nodeState: nodeState,
      ));

      // Listen to monitoring events
      _monitoringSubscription?.cancel();
      _monitoringSubscription =
          SlotMonitorService.instance.monitoringEvents.listen(
        _handleMonitoringEvent,
        onError: (error) {
          _log.error('Error in monitoring event stream: $error');
        },
      );

      // Start the actual monitoring (convert to legacy ScheduledSlot type)
      final legacySlot = legacy.ScheduledSlot(
        slotNumber: slot.slotNumber,
        slotTime: slot.slotTime,
        alarmTime: slot.alarmTime,
        epoch: slot.epoch,
      );
      await SlotMonitorService.instance.startMonitoringSlot(legacySlot);

      _log.info('Slot monitoring started successfully');
    } catch (e, st) {
      _log.error('Error starting slot monitoring: $e',
          error: e, stackTrace: st);
      _emitEvent(BlockProductionErrorEvent(
        errorType: 'monitoring_start',
        errorMessage: e.toString(),
        stackTrace: st.toString(),
      ));
    }
  }

  /// Handle native events from platform code (Android/iOS)
  ///
  /// This receives events forwarded from native code via PlatformAlarmService
  void _handleNativeEvent(String eventType, Map<String, dynamic> eventData) {
    _log.debug('Handling native event: $eventType with data: $eventData');

    try {
      switch (eventType) {
        case 'android_alarm_fired':
          _handleAndroidAlarmFiredEvent(eventData);
          break;
        case 'android_foreground_service_started':
          _handleAndroidForegroundServiceStartedEvent(eventData);
          break;
        case 'android_foreground_service_stopped':
          _handleAndroidForegroundServiceStoppedEvent(eventData);
          break;
        case 'android_boot_reschedule_started':
          _handleAndroidBootRescheduleStartedEvent(eventData);
          break;
        case 'android_boot_reschedule_completed':
          _handleAndroidBootRescheduleCompletedEvent(eventData);
          break;
        case 'android_exact_alarm_permission_granted':
          _handleAndroidExactAlarmPermissionGrantedEvent(eventData);
          break;
        case 'android_exact_alarm_permission_denied':
          _handleAndroidExactAlarmPermissionDeniedEvent(eventData);
          break;
        case 'android_battery_optimization_disabled':
          _handleAndroidBatteryOptimizationDisabledEvent(eventData);
          break;
        case 'ios_notification_scheduled':
          _handleIosNotificationScheduledEvent(eventData);
          break;
        case 'ios_notification_delivered':
          _handleIosNotificationDeliveredEvent(eventData);
          break;
        case 'ios_notification_tapped':
          _handleIosNotificationTappedEvent(eventData);
          break;
        case 'ios_bgtask_scheduled':
          _handleIosBgtaskScheduledEvent(eventData);
          break;
        case 'ios_bgtask_executed':
          _handleIosBgtaskExecutedEvent(eventData);
          break;
        case 'ios_bgtask_expired':
          _handleIosBgtaskExpiredEvent(eventData);
          break;
        case 'ios_notification_permission_granted':
          _handleIosNotificationPermissionGrantedEvent(eventData);
          break;
        case 'ios_notification_permission_denied':
          _handleIosNotificationPermissionDeniedEvent(eventData);
          break;
        default:
          _log.warn('Unknown native event type: $eventType');
      }
    } catch (e, st) {
      _log.error('Error handling native event: $e', error: e, stackTrace: st);
    }
  }

  // Android native event handlers

  void _handleAndroidAlarmFiredEvent(Map<String, dynamic> data) {
    final alarmId = data['alarmId'] as String?;
    final slotNumber = data['slotNumber'] as int?;
    final batteryLevel = data['batteryLevel'] as int?;
    final networkState = data['networkState'] as String?;

    if (slotNumber == null) {
      _log.warn('Android alarm fired event missing slotNumber');
      return;
    }

    _log.debug('Android alarm fired for slot $slotNumber');

    _emitEvent(BlockProductionAndroidAlarmFiredEvent(
      alarmId: alarmId ?? 'unknown',
      slotNumber: slotNumber,
      batteryLevel: batteryLevel ?? 0,
      networkState: networkState,
    ));

    // Trigger slot monitoring when Android alarm fires
    handleSlotWakeUp(slotNumber);
  }

  void _handleAndroidForegroundServiceStartedEvent(Map<String, dynamic> data) {
    final slotNumber = data['slotNumber'] as int? ?? 0;
    final wakeLockAcquired = data['wakeLockAcquired'] as bool? ?? false;

    _log.debug('Android foreground service started for slot $slotNumber');

    _emitEvent(BlockProductionAndroidForegroundServiceStartedEvent(
      slotNumber: slotNumber,
      wakeLockAcquired: wakeLockAcquired,
    ));
  }

  void _handleAndroidForegroundServiceStoppedEvent(Map<String, dynamic> data) {
    final slotNumber = data['slotNumber'] as int? ?? 0;
    final reason = data['reason'] as String? ?? 'unknown';

    _log.debug('Android foreground service stopped for slot $slotNumber');

    _emitEvent(BlockProductionAndroidForegroundServiceStoppedEvent(
      slotNumber: slotNumber,
      reason: reason,
    ));
  }

  void _handleAndroidBootRescheduleStartedEvent(Map<String, dynamic> data) {
    _log.debug('Android boot reschedule started');
    _emitEvent(BlockProductionAndroidBootRescheduleStartedEvent());
  }

  void _handleAndroidBootRescheduleCompletedEvent(Map<String, dynamic> data) {
    final slotsRescheduled = data['slotsRescheduled'] as int?;
    final success = data['success'] as bool?;
    _log.debug(
        'Android boot reschedule completed - Slots: $slotsRescheduled, Success: $success');
    _emitEvent(BlockProductionAndroidBootRescheduleCompletedEvent(
      slotsRescheduled: slotsRescheduled ?? 0,
      success: success ?? false,
    ));
  }

  void _handleAndroidExactAlarmPermissionGrantedEvent(
      Map<String, dynamic> data) {
    _log.debug('Android exact alarm permission granted');

    _emitEvent(BlockProductionAndroidExactAlarmPermissionGrantedEvent());
  }

  void _handleAndroidExactAlarmPermissionDeniedEvent(
      Map<String, dynamic> data) {
    _log.debug('Android exact alarm permission denied');

    _emitEvent(BlockProductionAndroidExactAlarmPermissionDeniedEvent());
  }

  void _handleAndroidBatteryOptimizationDisabledEvent(
      Map<String, dynamic> data) {
    _log.debug('Android battery optimization disabled');
    _emitEvent(BlockProductionAndroidBatteryOptimizationDisabledEvent());
  }

  // iOS native event handlers

  void _handleIosNotificationScheduledEvent(Map<String, dynamic> data) {
    final slotNumber = data['slotNumber'] as int?;
    final scheduledTime = data['scheduledTime'] as int?;

    _log.debug('iOS notification scheduled for slot $slotNumber');

    _emitEvent(BlockProductionIosNotificationScheduledEvent(
      slotNumber: slotNumber ?? 0,
      scheduledTime: scheduledTime != null
          ? DateTime.fromMillisecondsSinceEpoch(scheduledTime)
          : DateTime.now(),
    ));
  }

  void _handleIosNotificationDeliveredEvent(Map<String, dynamic> data) {
    final slotNumber = data['slotNumber'] as int?;
    _log.debug('iOS notification delivered for slot $slotNumber');
    _emitEvent(BlockProductionIosNotificationDeliveredEvent(
      slotNumber: slotNumber ?? 0,
    ));
  }

  void _handleIosNotificationTappedEvent(Map<String, dynamic> data) {
    final slotNumber = data['slotNumber'] as int?;

    _log.debug('iOS notification tapped for slot $slotNumber');

    _emitEvent(BlockProductionIosNotificationTappedEvent(
      slotNumber: slotNumber ?? 0,
    ));
  }

  void _handleIosBgtaskScheduledEvent(Map<String, dynamic> data) {
    final slotNumber = data['slotNumber'] as int?;
    final scheduledTime = data['scheduledTime'] as int?;

    _log.debug('iOS BGTask scheduled for slot $slotNumber');

    _emitEvent(BlockProductionIosBgtaskScheduledEvent(
      slotNumber: slotNumber ?? 0,
      scheduledTime: scheduledTime != null
          ? DateTime.fromMillisecondsSinceEpoch(scheduledTime)
          : DateTime.now(),
    ));
  }

  void _handleIosBgtaskExecutedEvent(Map<String, dynamic> data) {
    final slotNumber = data['slotNumber'] as int?;
    final executionDuration = data['executionDuration'] as int?;

    _log.debug('iOS BGTask executed for slot $slotNumber');

    _emitEvent(BlockProductionIosBgtaskExecutedEvent(
      slotNumber: slotNumber ?? 0,
      executionDuration: executionDuration ?? 0,
    ));
  }

  void _handleIosBgtaskExpiredEvent(Map<String, dynamic> data) {
    final slotNumber = data['slotNumber'] as int?;
    _log.debug('iOS BGTask expired for slot $slotNumber');
    _emitEvent(BlockProductionIosBgtaskExpiredEvent(
      slotNumber: slotNumber ?? 0,
    ));
  }

  void _handleIosNotificationPermissionGrantedEvent(Map<String, dynamic> data) {
    final alertsEnabled = data['alertsEnabled'] as bool? ?? true;
    final soundEnabled = data['soundEnabled'] as bool? ?? true;
    final badgeEnabled = data['badgeEnabled'] as bool? ?? true;

    _log.debug('iOS notification permission granted');

    _emitEvent(BlockProductionIosNotificationPermissionGrantedEvent(
      alertsEnabled: alertsEnabled,
      soundEnabled: soundEnabled,
      badgeEnabled: badgeEnabled,
    ));
  }

  void _handleIosNotificationPermissionDeniedEvent(Map<String, dynamic> data) {
    _log.debug('iOS notification permission denied');

    _emitEvent(BlockProductionIosNotificationPermissionDeniedEvent());
  }

  /// Handle monitoring events from SlotMonitorService
  void _handleMonitoringEvent(SlotMonitoringEvent event) {
    _log.debug('Monitoring event: ${event.type} for slot ${event.slotNumber}');

    switch (event.type) {
      case MonitoringEventType.poll:
        // Forward poll events to metrics system
        _emitEvent(BlockProductionMonitoringPollEvent(
          slotNumber: event.slotNumber,
          pollAttempt: event.pollAttempt ?? 0,
          nodeState: event.nodeState ?? 'unknown',
          success: event.success ?? false,
        ));
        break;
      case MonitoringEventType.slotProduced:
        _handleSlotProduced(event);
        break;
      case MonitoringEventType.timeout:
        _handleSlotFailed(event, 'Monitoring timeout');
        break;
      case MonitoringEventType.error:
        _handleSlotFailed(event, event.error ?? 'Unknown error');
        break;
      case MonitoringEventType.stopped:
        _handleMonitoringStopped(event);
        break;
      default:
        // Other events (started, stateChanged, tipAdvanced) don't need special handling
        break;
    }
  }

  /// Handle successful slot production
  void _handleSlotProduced(SlotMonitoringEvent event) {
    _log.info('Slot ${event.slotNumber} produced successfully!');

    // Update state with production result
    final result = BlockProductionResult(
      slotNumber: event.slotNumber,
      timestamp: event.timestamp,
      success: true,
      blockHash: null, // Would need to query blockchain for hash
      blockHeight: event.blockHeight,
      error: null,
    );

    final updatedHistory =
        Map<int, BlockProductionResult>.from(_state.productionHistory);
    updatedHistory[event.slotNumber] = result;
    _state = _state.copyWith(productionHistory: updatedHistory);

    // Emit success event
    _emitEvent(BlockProductionSlotProducedEvent(
      slotNumber: event.slotNumber,
      blockHash: '', // Would query blockchain
      blockHeight: event.blockHeight ?? 0,
      productionTime: event.timestamp,
    ));

    // Stop foreground service
    _stopForegroundService();

    // Persist state
    _stateRepository.save(_state);
  }

  /// Handle failed slot production
  void _handleSlotFailed(SlotMonitoringEvent event, String reason) {
    _log.warn('Slot ${event.slotNumber} failed: $reason');

    // Update state with production result
    final result = BlockProductionResult(
      slotNumber: event.slotNumber,
      timestamp: event.timestamp,
      success: false,
      blockHash: null,
      blockHeight: null,
      error: reason,
    );

    final updatedHistory =
        Map<int, BlockProductionResult>.from(_state.productionHistory);
    updatedHistory[event.slotNumber] = result;
    _state = _state.copyWith(productionHistory: updatedHistory);

    // Emit failure event
    _emitEvent(BlockProductionSlotFailedEvent(
      slotNumber: event.slotNumber,
      reason: reason,
      errorDetails: event.error,
    ));

    // Stop foreground service
    _stopForegroundService();

    // Persist state
    _stateRepository.save(_state);
  }

  /// Handle monitoring stopped event
  void _handleMonitoringStopped(SlotMonitoringEvent event) {
    _log.debug('Monitoring stopped for slot ${event.slotNumber}');
    _monitoringSubscription?.cancel();
    _monitoringSubscription = null;
  }

  /// Stop foreground service
  Future<void> _stopForegroundService() async {
    try {
      await PlatformAlarmService.instance.stopForegroundService();
      _log.debug('Stopped foreground service');
    } catch (e) {
      _log.warn('Error stopping foreground service: $e');
    }
  }

  /// Schedule alarms and notifications for won slots
  ///
  /// This is the core slot scheduling logic that:
  /// 1. Records won slots to statistics
  /// 2. Calculates alarm times (slot time - wake before duration)
  /// 3. Schedules platform alarms
  /// 4. Schedules notifications (integrated)
  /// 5. Updates state
  ///
  /// Returns the number of successfully scheduled slots.
  Future<int> _scheduleSlots(List<RpcEpochWonSlot> wonSlots) async {
    try {
      _log.info('Scheduling ${wonSlots.length} won slots');

      final List<ScheduledSlot> newSlots = [];
      int successCount = 0;
      int failureCount = 0;

      for (final wonSlot in wonSlots) {
        final slotNumber = wonSlot.globalSlot;
        final slotTime = DateTime.fromMillisecondsSinceEpoch(
          wonSlot.expectedTimeMs.toInt(),
        );
        final alarmTime = slotTime.subtract(_wakeBeforeSlot);

        // Record won slot to statistics repository
        try {
          await SlotProductionRepository.instance.recordWonSlot(
            slotNumber: slotNumber,
            epoch: _state.currentEpoch,
            slotTime: slotTime,
          );
          _log.debug('Recorded won slot $slotNumber to statistics');
        } catch (e) {
          _log.warn('Failed to record won slot $slotNumber: $e');
        }

        // Only schedule future slots
        if (alarmTime.isAfter(DateTime.now())) {
          final scheduled = ScheduledSlot(
            slotNumber: slotNumber,
            slotTime: slotTime,
            alarmTime: alarmTime,
            epoch: _state.currentEpoch,
            notificationScheduled: _state.notificationsEnabled,
          );

          // Schedule alarm via platform service
          final alarmSuccess = await _scheduleSlotAlarm(scheduled);

          if (alarmSuccess) {
            newSlots.add(scheduled.copyWith(
              notificationScheduled: false,
            ));
            successCount++;
          } else {
            failureCount++;
          }
        } else {
          LoggingService.instance.debug(
              'Skipping past slot $slotNumber (alarm time already passed)');
        }
      }

      // Update state with new scheduled slots
      _state = _state.copyWith(scheduledSlots: newSlots);

      _log.info(
        'Scheduled $successCount slots successfully, $failureCount failures',
      );

      return successCount;
    } catch (e, st) {
      _log.error('Error scheduling slots: $e', error: e, stackTrace: st);
      _emitEvent(BlockProductionErrorEvent(
        errorType: 'slot_scheduling',
        errorMessage: e.toString(),
        stackTrace: st.toString(),
      ));
      return 0;
    }
  }

  /// Schedule platform alarm for a specific slot
  Future<bool> _scheduleSlotAlarm(ScheduledSlot slot) async {
    try {
      _log.debug(
        'Scheduling alarm for slot ${slot.slotNumber} at ${slot.alarmTime}',
      );

      final alarmId = 'slot_${slot.slotNumber}';
      final success = await PlatformAlarmService.instance.scheduleAlarm(
        alarmId: alarmId,
        alarmTime: slot.alarmTime,
        slotNumber: slot.slotNumber,
        data: {
          'epoch': slot.epoch,
          'slotTime': slot.slotTime.toIso8601String(),
        },
      );

      if (success) {
        _log.info('Successfully scheduled alarm for slot ${slot.slotNumber}');

        // Emit alarm scheduled event
        _emitEvent(BlockProductionAlarmScheduledEvent(
          slotNumber: slot.slotNumber,
          alarmTime: slot.alarmTime,
          platform: 'flutter', // Will be android or ios from native
          alarmId: alarmId,
        ));
      } else {
        _log.warn('Failed to schedule alarm for slot ${slot.slotNumber}');
      }

      return success;
    } catch (e) {
      _log.error('Error scheduling slot alarm: $e');
      return false;
    }
  }

  /// Cancel all scheduled slot alarms
  Future<void> _cancelAllSlotAlarms() async {
    try {
      _log.info('Cancelling ${_state.scheduledSlots.length} scheduled slots');

      for (final slot in _state.scheduledSlots) {
        await _cancelSlotAlarm(slot);
      }

      // Clear scheduled slots from state
      _state = _state.copyWith(scheduledSlots: []);

      _log.info('All slots cancelled');
    } catch (e) {
      _log.error('Error cancelling all slots: $e');
    }
  }

  /// Cancel alarm for a specific slot
  Future<void> _cancelSlotAlarm(ScheduledSlot slot) async {
    try {
      final alarmId = 'slot_${slot.slotNumber}';
      await PlatformAlarmService.instance.cancelAlarm(alarmId);

      _log.debug('Cancelled alarm for slot ${slot.slotNumber}');
    } catch (e) {
      _log.error('Error cancelling slot alarm: $e');
    }
  }

  /// Emit an event to the event stream
  void _emitEvent(BlockProductionEvent event) {
    _log.debug('Emitting event: ${event.eventType}');
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Get a state snapshot for debugging
  Future<Map<String, dynamic>> getStateSnapshot() async {
    return await _stateRepository.getSnapshot();
  }

  /// Dispose the orchestrator
  void dispose() {
    _log.info('Disposing BackgroundBlockProductionOrchestrator');
    _stopEpochMonitoring();
    _monitoringSubscription?.cancel();
    _eventController.close();
    _initialized = false;
  }
}
