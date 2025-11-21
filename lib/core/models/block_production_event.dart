/// Base class for all block production lifecycle events
///
/// These events are emitted by the BackgroundBlockProductionOrchestrator
/// and can be consumed by the metrics collector and other observers.
abstract class BlockProductionEvent {
  final DateTime timestamp;
  final String eventType;

  BlockProductionEvent({
    required this.eventType,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'eventType': eventType,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Event emitted when a new epoch transition is detected
class BlockProductionEpochTransitionEvent extends BlockProductionEvent {
  final int previousEpoch;
  final int newEpoch;
  final int slotsScheduled;
  final String? vrfStatus; // Enhanced: VRF status (e.g., 'complete', 'in_progress')
  final DateTime? nextAlarmTime; // Enhanced: When is the next alarm scheduled

  BlockProductionEpochTransitionEvent({
    required this.previousEpoch,
    required this.newEpoch,
    required this.slotsScheduled,
    this.vrfStatus,
    this.nextAlarmTime,
    super.timestamp,
  }) : super(eventType: 'epoch_transition');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'previousEpoch': previousEpoch,
        'newEpoch': newEpoch,
        'slotsScheduled': slotsScheduled,
        if (vrfStatus != null) 'vrfStatus': vrfStatus,
        if (nextAlarmTime != null)
          'nextAlarmTime': nextAlarmTime!.toIso8601String(),
      };
}

/// Event emitted when an alarm fires and the app wakes up
///
/// This is PROOF that the alarm system is working!
class BlockProductionAppWakeUpEvent extends BlockProductionEvent {
  final int slotNumber;
  final DateTime alarmTime;
  final int batteryLevel;
  final int? alarmLatencyMs; // Enhanced: How late was the alarm (ms)
  final String? deviceState; // Enhanced: 'locked', 'unlocked', 'doze', etc.
  final String? networkStatus; // Enhanced: 'wifi', 'cellular', 'none'
  final String? wakeSource; // Enhanced: 'alarm', 'notification', 'bgtask', 'user'

  BlockProductionAppWakeUpEvent({
    required this.slotNumber,
    required this.alarmTime,
    required this.batteryLevel,
    this.alarmLatencyMs,
    this.deviceState,
    this.networkStatus,
    this.wakeSource,
    super.timestamp,
  }) : super(eventType: 'app_wake_up');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'alarmTime': alarmTime.toIso8601String(),
        'batteryLevel': batteryLevel,
        if (alarmLatencyMs != null) 'alarmLatencyMs': alarmLatencyMs,
        if (deviceState != null) 'deviceState': deviceState,
        if (networkStatus != null) 'networkStatus': networkStatus,
        if (wakeSource != null) 'wakeSource': wakeSource,
      };
}

/// Event emitted when slot monitoring starts
class BlockProductionMonitoringStartEvent extends BlockProductionEvent {
  final int slotNumber;
  final DateTime slotTime;
  final String nodeState;
  final int? currentEpoch; // Enhanced: Current epoch number
  final bool? foregroundServiceActive; // Enhanced: Android foreground service status

  BlockProductionMonitoringStartEvent({
    required this.slotNumber,
    required this.slotTime,
    required this.nodeState,
    this.currentEpoch,
    this.foregroundServiceActive,
    super.timestamp,
  }) : super(eventType: 'slot_monitoring_start');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'slotTime': slotTime.toIso8601String(),
        'nodeState': nodeState,
        if (currentEpoch != null) 'currentEpoch': currentEpoch,
        if (foregroundServiceActive != null)
          'foregroundServiceActive': foregroundServiceActive,
      };
}

/// Event emitted when a block is successfully produced
class BlockProductionSlotProducedEvent extends BlockProductionEvent {
  final int slotNumber;
  final String blockHash;
  final int blockHeight;
  final DateTime productionTime;
  final String? nodeState; // Enhanced: Node state at production time
  final String? consensusState; // Enhanced: Consensus state info

  BlockProductionSlotProducedEvent({
    required this.slotNumber,
    required this.blockHash,
    required this.blockHeight,
    required this.productionTime,
    this.nodeState,
    this.consensusState,
    super.timestamp,
  }) : super(eventType: 'slot_produced');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'blockHash': blockHash,
        'blockHeight': blockHeight,
        'productionTime': productionTime.toIso8601String(),
        if (nodeState != null) 'nodeState': nodeState,
        if (consensusState != null) 'consensusState': consensusState,
      };
}

/// Event emitted when a block production fails or slot is missed
class BlockProductionSlotFailedEvent extends BlockProductionEvent {
  final int slotNumber;
  final String reason;
  final String? errorDetails;
  final String? nodeState; // Enhanced: Node state at failure time
  final String? consensusState; // Enhanced: Consensus state info

  BlockProductionSlotFailedEvent({
    required this.slotNumber,
    required this.reason,
    this.errorDetails,
    this.nodeState,
    this.consensusState,
    super.timestamp,
  }) : super(eventType: 'slot_failed');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'reason': reason,
        if (errorDetails != null) 'errorDetails': errorDetails,
        if (nodeState != null) 'nodeState': nodeState,
        if (consensusState != null) 'consensusState': consensusState,
      };
}

/// Event emitted when block production is detected for a slot
class BlockProductionBlockProductionDetectedEvent
    extends BlockProductionEvent {
  final int slotNumber;
  final String blockHash;
  final int blockHeight;
  final DateTime detectionTime;

  BlockProductionBlockProductionDetectedEvent({
    required this.slotNumber,
    required this.blockHash,
    required this.blockHeight,
    required this.detectionTime,
    super.timestamp,
  }) : super(eventType: 'block_production_detected');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'blockHash': blockHash,
        'blockHeight': blockHeight,
        'detectionTime': detectionTime.toIso8601String(),
      };
}

/// Event emitted when node start is initiated
class BlockProductionNodeStartInitiatedEvent extends BlockProductionEvent {
  final String reason;
  final int slotNumber;

  BlockProductionNodeStartInitiatedEvent({
    required this.reason,
    required this.slotNumber,
    super.timestamp,
  }) : super(eventType: 'node_start_initiated');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'reason': reason,
        'slotNumber': slotNumber,
      };
}

/// Event emitted when node start completes successfully
class BlockProductionNodeStartCompletedEvent extends BlockProductionEvent {
  final int slotNumber;
  final int startDurationMs;
  final String peerId;

  BlockProductionNodeStartCompletedEvent({
    required this.slotNumber,
    required this.startDurationMs,
    required this.peerId,
    super.timestamp,
  }) : super(eventType: 'node_start_completed');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'startDurationMs': startDurationMs,
        'peerId': peerId,
      };
}

/// Event emitted when node start fails
class BlockProductionNodeStartFailedEvent extends BlockProductionEvent {
  final int slotNumber;
  final String errorMessage;
  final int attemptDurationMs;

  BlockProductionNodeStartFailedEvent({
    required this.slotNumber,
    required this.errorMessage,
    required this.attemptDurationMs,
    super.timestamp,
  }) : super(eventType: 'node_start_failed');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'errorMessage': errorMessage,
        'attemptDurationMs': attemptDurationMs,
      };
}

/// Event emitted when the app resumes from background
class BlockProductionAppResumedEvent extends BlockProductionEvent {
  final int currentEpoch;
  final bool nodeRunning;
  final int scheduledSlotsCount;

  BlockProductionAppResumedEvent({
    required this.currentEpoch,
    required this.nodeRunning,
    required this.scheduledSlotsCount,
    super.timestamp,
  }) : super(eventType: 'app_resumed');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'currentEpoch': currentEpoch,
        'nodeRunning': nodeRunning,
        'scheduledSlotsCount': scheduledSlotsCount,
      };
}

/// Event emitted when an error occurs in the production system
class BlockProductionErrorEvent extends BlockProductionEvent {
  final String errorType;
  final String errorMessage;
  final String? stackTrace;

  BlockProductionErrorEvent({
    required this.errorType,
    required this.errorMessage,
    this.stackTrace,
    super.timestamp,
  }) : super(eventType: 'error');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'errorType': errorType,
        'errorMessage': errorMessage,
        if (stackTrace != null) 'stackTrace': stackTrace,
      };
}

/// Event emitted periodically for health checks (from metrics collector)
class BlockProductionHealthCheckEvent extends BlockProductionEvent {
  final int currentEpoch;
  final int scheduledSlotsCount;
  final bool nodeRunning;

  BlockProductionHealthCheckEvent({
    required this.currentEpoch,
    required this.scheduledSlotsCount,
    required this.nodeRunning,
    super.timestamp,
  }) : super(eventType: 'health_check');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'currentEpoch': currentEpoch,
        'scheduledSlotsCount': scheduledSlotsCount,
        'nodeRunning': nodeRunning,
      };
}

// ============================================================================
// PLATFORM-AGNOSTIC EVENTS (New)
// ============================================================================

/// Event emitted when an alarm/notification is scheduled
class BlockProductionAlarmScheduledEvent extends BlockProductionEvent {
  final int slotNumber;
  final DateTime alarmTime;
  final String platform; // 'android' or 'ios'
  final String? alarmId;

  BlockProductionAlarmScheduledEvent({
    required this.slotNumber,
    required this.alarmTime,
    required this.platform,
    this.alarmId,
    super.timestamp,
  }) : super(eventType: 'alarm_scheduled');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'alarmTime': alarmTime.toIso8601String(),
        'platform': platform,
        if (alarmId != null) 'alarmId': alarmId,
      };
}

/// Event emitted during each node status poll while monitoring a slot
class BlockProductionMonitoringPollEvent extends BlockProductionEvent {
  final int slotNumber;
  final int pollAttempt;
  final String nodeState;
  final bool success;

  BlockProductionMonitoringPollEvent({
    required this.slotNumber,
    required this.pollAttempt,
    required this.nodeState,
    required this.success,
    super.timestamp,
  }) : super(eventType: 'monitoring_poll');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'pollAttempt': pollAttempt,
        'nodeState': nodeState,
        'success': success,
      };
}

/// Event emitted when an expected alarm doesn't fire within tolerance
class BlockProductionAlarmMissedEvent extends BlockProductionEvent {
  final int slotNumber;
  final DateTime expectedAlarmTime;
  final int minutesPastExpected;

  BlockProductionAlarmMissedEvent({
    required this.slotNumber,
    required this.expectedAlarmTime,
    required this.minutesPastExpected,
    super.timestamp,
  }) : super(eventType: 'alarm_missed');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'expectedAlarmTime': expectedAlarmTime.toIso8601String(),
        'minutesPastExpected': minutesPastExpected,
      };
}

// ============================================================================
// ANDROID-SPECIFIC EVENTS (New)
// ============================================================================

/// Event emitted when Android AlarmReceiver receives an alarm broadcast
class BlockProductionAndroidAlarmFiredEvent extends BlockProductionEvent {
  final String alarmId;
  final int slotNumber;
  final int batteryLevel;
  final String? networkState;

  BlockProductionAndroidAlarmFiredEvent({
    required this.alarmId,
    required this.slotNumber,
    required this.batteryLevel,
    this.networkState,
    super.timestamp,
  }) : super(eventType: 'android_alarm_fired');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'alarmId': alarmId,
        'slotNumber': slotNumber,
        'batteryLevel': batteryLevel,
        if (networkState != null) 'networkState': networkState,
      };
}

/// Event emitted when Android foreground service starts
class BlockProductionAndroidForegroundServiceStartedEvent
    extends BlockProductionEvent {
  final int slotNumber;
  final bool wakeLockAcquired;

  BlockProductionAndroidForegroundServiceStartedEvent({
    required this.slotNumber,
    required this.wakeLockAcquired,
    super.timestamp,
  }) : super(eventType: 'android_foreground_service_started');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'wakeLockAcquired': wakeLockAcquired,
      };
}

/// Event emitted when Android foreground service stops
class BlockProductionAndroidForegroundServiceStoppedEvent
    extends BlockProductionEvent {
  final int slotNumber;
  final String reason;

  BlockProductionAndroidForegroundServiceStoppedEvent({
    required this.slotNumber,
    required this.reason,
    super.timestamp,
  }) : super(eventType: 'android_foreground_service_stopped');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'reason': reason,
      };
}

/// Event emitted when alarms are rescheduled after Android device reboot
class BlockProductionAndroidBootAlarmRescheduledEvent
    extends BlockProductionEvent {
  final int alarmsRescheduled;
  final List<int> slotNumbers;

  BlockProductionAndroidBootAlarmRescheduledEvent({
    required this.alarmsRescheduled,
    required this.slotNumbers,
    super.timestamp,
  }) : super(eventType: 'android_boot_alarm_rescheduled');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'alarmsRescheduled': alarmsRescheduled,
        'slotNumbers': slotNumbers,
      };
}

// ============================================================================
// iOS-SPECIFIC EVENTS (New)
// ============================================================================

/// Event emitted when iOS local notification is scheduled
class BlockProductionIosNotificationScheduledEvent
    extends BlockProductionEvent {
  final int slotNumber;
  final DateTime scheduledTime;

  BlockProductionIosNotificationScheduledEvent({
    required this.slotNumber,
    required this.scheduledTime,
    super.timestamp,
  }) : super(eventType: 'ios_notification_scheduled');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'scheduledTime': scheduledTime.toIso8601String(),
      };
}

/// Event emitted when user taps iOS notification
class BlockProductionIosNotificationTappedEvent extends BlockProductionEvent {
  final int slotNumber;

  BlockProductionIosNotificationTappedEvent({
    required this.slotNumber,
    super.timestamp,
  }) : super(eventType: 'ios_notification_tapped');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
      };
}

/// Event emitted when iOS BGTask is scheduled
class BlockProductionIosBgtaskScheduledEvent extends BlockProductionEvent {
  final int slotNumber;
  final DateTime scheduledTime;

  BlockProductionIosBgtaskScheduledEvent({
    required this.slotNumber,
    required this.scheduledTime,
    super.timestamp,
  }) : super(eventType: 'ios_bgtask_scheduled');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'scheduledTime': scheduledTime.toIso8601String(),
      };
}

/// Event emitted when iOS BGTask actually executes (rare)
class BlockProductionIosBgtaskExecutedEvent extends BlockProductionEvent {
  final int slotNumber;
  final int executionDuration;

  BlockProductionIosBgtaskExecutedEvent({
    required this.slotNumber,
    required this.executionDuration,
    super.timestamp,
  }) : super(eventType: 'ios_bgtask_executed');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'executionDuration': executionDuration,
      };
}

// ============================================================================
// PERMISSION EVENTS (New) - Android
// ============================================================================

/// Event emitted when Android exact alarm permission is requested
class BlockProductionAndroidExactAlarmPermissionRequestedEvent
    extends BlockProductionEvent {
  BlockProductionAndroidExactAlarmPermissionRequestedEvent({
    super.timestamp,
  }) : super(eventType: 'android_exact_alarm_permission_requested');
}

/// Event emitted when Android exact alarm permission is granted
class BlockProductionAndroidExactAlarmPermissionGrantedEvent
    extends BlockProductionEvent {
  BlockProductionAndroidExactAlarmPermissionGrantedEvent({
    super.timestamp,
  }) : super(eventType: 'android_exact_alarm_permission_granted');
}

/// Event emitted when Android exact alarm permission is denied
class BlockProductionAndroidExactAlarmPermissionDeniedEvent
    extends BlockProductionEvent {
  BlockProductionAndroidExactAlarmPermissionDeniedEvent({
    super.timestamp,
  }) : super(eventType: 'android_exact_alarm_permission_denied');
}

/// Event emitted when battery optimization status is checked
class BlockProductionAndroidBatteryOptimizationCheckedEvent
    extends BlockProductionEvent {
  final bool isOptimized;
  final bool isWhitelisted;

  BlockProductionAndroidBatteryOptimizationCheckedEvent({
    required this.isOptimized,
    required this.isWhitelisted,
    super.timestamp,
  }) : super(eventType: 'android_battery_optimization_checked');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'isOptimized': isOptimized,
        'isWhitelisted': isWhitelisted,
      };
}

/// Event emitted when user is prompted to disable battery optimization
class BlockProductionAndroidBatteryOptimizationRequestedEvent
    extends BlockProductionEvent {
  BlockProductionAndroidBatteryOptimizationRequestedEvent({
    super.timestamp,
  }) : super(eventType: 'android_battery_optimization_requested');
}

/// Event emitted when Android notification permission is requested
class BlockProductionAndroidNotificationPermissionRequestedEvent
    extends BlockProductionEvent {
  BlockProductionAndroidNotificationPermissionRequestedEvent({
    super.timestamp,
  }) : super(eventType: 'android_notification_permission_requested');
}

/// Event emitted when Android notification permission is granted
class BlockProductionAndroidNotificationPermissionGrantedEvent
    extends BlockProductionEvent {
  BlockProductionAndroidNotificationPermissionGrantedEvent({
    super.timestamp,
  }) : super(eventType: 'android_notification_permission_granted');
}

/// Event emitted when Android notification permission is denied
class BlockProductionAndroidNotificationPermissionDeniedEvent
    extends BlockProductionEvent {
  BlockProductionAndroidNotificationPermissionDeniedEvent({
    super.timestamp,
  }) : super(eventType: 'android_notification_permission_denied');
}

// ============================================================================
// PERMISSION EVENTS (New) - iOS
// ============================================================================

/// Event emitted when iOS notification permission is requested
class BlockProductionIosNotificationPermissionRequestedEvent
    extends BlockProductionEvent {
  BlockProductionIosNotificationPermissionRequestedEvent({
    super.timestamp,
  }) : super(eventType: 'ios_notification_permission_requested');
}

/// Event emitted when iOS notification permission is granted
class BlockProductionIosNotificationPermissionGrantedEvent
    extends BlockProductionEvent {
  final bool alertsEnabled;
  final bool soundEnabled;
  final bool badgeEnabled;

  BlockProductionIosNotificationPermissionGrantedEvent({
    required this.alertsEnabled,
    required this.soundEnabled,
    required this.badgeEnabled,
    super.timestamp,
  }) : super(eventType: 'ios_notification_permission_granted');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'alertsEnabled': alertsEnabled,
        'soundEnabled': soundEnabled,
        'badgeEnabled': badgeEnabled,
      };
}

/// Event emitted when iOS notification permission is denied
class BlockProductionIosNotificationPermissionDeniedEvent
    extends BlockProductionEvent {
  BlockProductionIosNotificationPermissionDeniedEvent({
    super.timestamp,
  }) : super(eventType: 'ios_notification_permission_denied');
}

/// Event emitted when iOS background refresh status is checked
class BlockProductionIosBackgroundRefreshStatusCheckedEvent
    extends BlockProductionEvent {
  final String status; // 'available', 'denied', 'restricted'

  BlockProductionIosBackgroundRefreshStatusCheckedEvent({
    required this.status,
    super.timestamp,
  }) : super(eventType: 'ios_background_refresh_status_checked');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'status': status,
      };
}

/// Event emitted when Android boot reschedule starts
class BlockProductionAndroidBootRescheduleStartedEvent
    extends BlockProductionEvent {
  BlockProductionAndroidBootRescheduleStartedEvent({
    super.timestamp,
  }) : super(eventType: 'android_boot_reschedule_started');
}

/// Event emitted when Android boot reschedule completes
class BlockProductionAndroidBootRescheduleCompletedEvent
    extends BlockProductionEvent {
  final int slotsRescheduled;
  final bool success;

  BlockProductionAndroidBootRescheduleCompletedEvent({
    required this.slotsRescheduled,
    required this.success,
    super.timestamp,
  }) : super(eventType: 'android_boot_reschedule_completed');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotsRescheduled': slotsRescheduled,
        'success': success,
      };
}

/// Event emitted when Android battery optimization is disabled
class BlockProductionAndroidBatteryOptimizationDisabledEvent
    extends BlockProductionEvent {
  BlockProductionAndroidBatteryOptimizationDisabledEvent({
    super.timestamp,
  }) : super(eventType: 'android_battery_optimization_disabled');
}

/// Event emitted when iOS notification is delivered
class BlockProductionIosNotificationDeliveredEvent
    extends BlockProductionEvent {
  final int slotNumber;

  BlockProductionIosNotificationDeliveredEvent({
    required this.slotNumber,
    super.timestamp,
  }) : super(eventType: 'ios_notification_delivered');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
      };
}

/// Event emitted when iOS background task expires
class BlockProductionIosBgtaskExpiredEvent extends BlockProductionEvent {
  final int slotNumber;

  BlockProductionIosBgtaskExpiredEvent({
    required this.slotNumber,
    super.timestamp,
  }) : super(eventType: 'ios_bgtask_expired');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
      };
}
