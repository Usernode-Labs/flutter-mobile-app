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

  BlockProductionEpochTransitionEvent({
    required this.previousEpoch,
    required this.newEpoch,
    required this.slotsScheduled,
    DateTime? timestamp,
  }) : super(eventType: 'epoch_transition', timestamp: timestamp);

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'previousEpoch': previousEpoch,
        'newEpoch': newEpoch,
        'slotsScheduled': slotsScheduled,
      };
}

/// Event emitted when an alarm fires and the app wakes up
///
/// This is PROOF that the alarm system is working!
class BlockProductionAppWakeUpEvent extends BlockProductionEvent {
  final int slotNumber;
  final DateTime alarmTime;
  final int batteryLevel;

  BlockProductionAppWakeUpEvent({
    required this.slotNumber,
    required this.alarmTime,
    required this.batteryLevel,
    DateTime? timestamp,
  }) : super(eventType: 'app_wake_up', timestamp: timestamp);

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'alarmTime': alarmTime.toIso8601String(),
        'batteryLevel': batteryLevel,
      };
}

/// Event emitted when slot monitoring starts
class BlockProductionMonitoringStartEvent extends BlockProductionEvent {
  final int slotNumber;
  final DateTime slotTime;
  final String nodeState;

  BlockProductionMonitoringStartEvent({
    required this.slotNumber,
    required this.slotTime,
    required this.nodeState,
    DateTime? timestamp,
  }) : super(eventType: 'slot_monitoring_start', timestamp: timestamp);

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'slotTime': slotTime.toIso8601String(),
        'nodeState': nodeState,
      };
}

/// Event emitted when a block is successfully produced
class BlockProductionSlotProducedEvent extends BlockProductionEvent {
  final int slotNumber;
  final String blockHash;
  final int blockHeight;
  final DateTime productionTime;

  BlockProductionSlotProducedEvent({
    required this.slotNumber,
    required this.blockHash,
    required this.blockHeight,
    required this.productionTime,
    DateTime? timestamp,
  }) : super(eventType: 'slot_produced', timestamp: timestamp);

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'blockHash': blockHash,
        'blockHeight': blockHeight,
        'productionTime': productionTime.toIso8601String(),
      };
}

/// Event emitted when a block production fails or slot is missed
class BlockProductionSlotFailedEvent extends BlockProductionEvent {
  final int slotNumber;
  final String reason;
  final String? errorDetails;

  BlockProductionSlotFailedEvent({
    required this.slotNumber,
    required this.reason,
    this.errorDetails,
    DateTime? timestamp,
  }) : super(eventType: 'slot_failed', timestamp: timestamp);

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slotNumber': slotNumber,
        'reason': reason,
        if (errorDetails != null) 'errorDetails': errorDetails,
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
    DateTime? timestamp,
  }) : super(eventType: 'app_resumed', timestamp: timestamp);

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
    DateTime? timestamp,
  }) : super(eventType: 'error', timestamp: timestamp);

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
    DateTime? timestamp,
  }) : super(eventType: 'health_check', timestamp: timestamp);

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'currentEpoch': currentEpoch,
        'scheduledSlotsCount': scheduledSlotsCount,
        'nodeRunning': nodeRunning,
      };
}
