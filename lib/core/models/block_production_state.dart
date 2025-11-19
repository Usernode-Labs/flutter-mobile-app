import 'vrf_status.dart';

/// Represents a scheduled slot with all relevant timing information
class ScheduledSlot {
  final int slotNumber;
  final DateTime slotTime;
  final DateTime alarmTime;
  final int epoch;
  final bool notificationScheduled;
  final String status; // 'pending', 'monitoring', 'produced', 'failed'

  const ScheduledSlot({
    required this.slotNumber,
    required this.slotTime,
    required this.alarmTime,
    required this.epoch,
    this.notificationScheduled = false,
    this.status = 'pending',
  });

  Map<String, dynamic> toJson() => {
        'slotNumber': slotNumber,
        'slotTime': slotTime.toIso8601String(),
        'alarmTime': alarmTime.toIso8601String(),
        'epoch': epoch,
        'notificationScheduled': notificationScheduled,
        'status': status,
      };

  factory ScheduledSlot.fromJson(Map<String, dynamic> json) => ScheduledSlot(
        slotNumber: json['slotNumber'] as int,
        slotTime: DateTime.parse(json['slotTime'] as String),
        alarmTime: DateTime.parse(json['alarmTime'] as String),
        epoch: json['epoch'] as int,
        notificationScheduled: json['notificationScheduled'] as bool? ?? false,
        status: json['status'] as String? ?? 'pending',
      );

  ScheduledSlot copyWith({
    int? slotNumber,
    DateTime? slotTime,
    DateTime? alarmTime,
    int? epoch,
    bool? notificationScheduled,
    String? status,
  }) =>
      ScheduledSlot(
        slotNumber: slotNumber ?? this.slotNumber,
        slotTime: slotTime ?? this.slotTime,
        alarmTime: alarmTime ?? this.alarmTime,
        epoch: epoch ?? this.epoch,
        notificationScheduled:
            notificationScheduled ?? this.notificationScheduled,
        status: status ?? this.status,
      );
}

/// Represents the result of a block production attempt
class BlockProductionResult {
  final int slotNumber;
  final DateTime timestamp;
  final bool success;
  final String? blockHash;
  final int? blockHeight;
  final String? error;

  const BlockProductionResult({
    required this.slotNumber,
    required this.timestamp,
    required this.success,
    this.blockHash,
    this.blockHeight,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'slotNumber': slotNumber,
        'timestamp': timestamp.toIso8601String(),
        'success': success,
        if (blockHash != null) 'blockHash': blockHash,
        if (blockHeight != null) 'blockHeight': blockHeight,
        if (error != null) 'error': error,
      };

  factory BlockProductionResult.fromJson(Map<String, dynamic> json) =>
      BlockProductionResult(
        slotNumber: json['slotNumber'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
        success: json['success'] as bool,
        blockHash: json['blockHash'] as String?,
        blockHeight: json['blockHeight'] as int?,
        error: json['error'] as String?,
      );
}

/// The unified state for the background block production system
///
/// This single state object replaces scattered state across multiple services.
class BlockProductionState {
  final int currentEpoch;
  final List<ScheduledSlot> scheduledSlots;
  final Map<int, BlockProductionResult> productionHistory;
  final DateTime? lastHealthCheck;
  final DateTime? lastWakeUp;
  final DateTime? lastEpochCheck;
  final VRFStatus? currentVrfStatus;
  final bool notificationsEnabled;

  const BlockProductionState({
    required this.currentEpoch,
    required this.scheduledSlots,
    required this.productionHistory,
    this.lastHealthCheck,
    this.lastWakeUp,
    this.lastEpochCheck,
    this.currentVrfStatus,
    this.notificationsEnabled = true,
  });

  /// Create an empty initial state
  factory BlockProductionState.initial() => const BlockProductionState(
        currentEpoch: 0,
        scheduledSlots: [],
        productionHistory: {},
        notificationsEnabled: true,
      );

  Map<String, dynamic> toJson() => {
        'currentEpoch': currentEpoch,
        'scheduledSlots':
            scheduledSlots.map((slot) => slot.toJson()).toList(),
        'productionHistory': productionHistory.map(
          (key, value) => MapEntry(key.toString(), value.toJson()),
        ),
        if (lastHealthCheck != null)
          'lastHealthCheck': lastHealthCheck!.toIso8601String(),
        if (lastWakeUp != null) 'lastWakeUp': lastWakeUp!.toIso8601String(),
        if (lastEpochCheck != null)
          'lastEpochCheck': lastEpochCheck!.toIso8601String(),
        if (currentVrfStatus != null)
          'currentVrfStatus': currentVrfStatus!.name,
        'notificationsEnabled': notificationsEnabled,
      };

  factory BlockProductionState.fromJson(Map<String, dynamic> json) {
    // Parse scheduled slots
    final slotsList = json['scheduledSlots'] as List<dynamic>? ?? [];
    final slots = slotsList
        .map((slot) => ScheduledSlot.fromJson(slot as Map<String, dynamic>))
        .toList();

    // Parse production history
    final historyMap = json['productionHistory'] as Map<String, dynamic>? ?? {};
    final history = <int, BlockProductionResult>{};
    historyMap.forEach((key, value) {
      final slotNumber = int.parse(key);
      history[slotNumber] =
          BlockProductionResult.fromJson(value as Map<String, dynamic>);
    });

    // Parse VRF status
    VRFStatus? vrfStatus;
    final vrfStatusStr = json['currentVrfStatus'] as String?;
    if (vrfStatusStr != null) {
      vrfStatus = VRFStatus.values.firstWhere(
        (e) => e.name == vrfStatusStr,
        orElse: () => VRFStatus.notStarted,
      );
    }

    return BlockProductionState(
      currentEpoch: json['currentEpoch'] as int? ?? 0,
      scheduledSlots: slots,
      productionHistory: history,
      lastHealthCheck: json['lastHealthCheck'] != null
          ? DateTime.parse(json['lastHealthCheck'] as String)
          : null,
      lastWakeUp: json['lastWakeUp'] != null
          ? DateTime.parse(json['lastWakeUp'] as String)
          : null,
      lastEpochCheck: json['lastEpochCheck'] != null
          ? DateTime.parse(json['lastEpochCheck'] as String)
          : null,
      currentVrfStatus: vrfStatus,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    );
  }

  BlockProductionState copyWith({
    int? currentEpoch,
    List<ScheduledSlot>? scheduledSlots,
    Map<int, BlockProductionResult>? productionHistory,
    DateTime? lastHealthCheck,
    DateTime? lastWakeUp,
    DateTime? lastEpochCheck,
    VRFStatus? currentVrfStatus,
    bool? notificationsEnabled,
  }) =>
      BlockProductionState(
        currentEpoch: currentEpoch ?? this.currentEpoch,
        scheduledSlots: scheduledSlots ?? this.scheduledSlots,
        productionHistory: productionHistory ?? this.productionHistory,
        lastHealthCheck: lastHealthCheck ?? this.lastHealthCheck,
        lastWakeUp: lastWakeUp ?? this.lastWakeUp,
        lastEpochCheck: lastEpochCheck ?? this.lastEpochCheck,
        currentVrfStatus: currentVrfStatus ?? this.currentVrfStatus,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      );

  /// Get the next upcoming slot
  ScheduledSlot? get nextSlot {
    if (scheduledSlots.isEmpty) return null;

    final now = DateTime.now();
    final upcomingSlots = scheduledSlots
        .where((slot) => slot.slotTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.slotTime.compareTo(b.slotTime));

    return upcomingSlots.isNotEmpty ? upcomingSlots.first : null;
  }

  /// Get count of successful productions
  int get successfulProductionsCount =>
      productionHistory.values.where((r) => r.success).length;

  /// Get count of failed productions
  int get failedProductionsCount =>
      productionHistory.values.where((r) => !r.success).length;

  @override
  String toString() {
    return 'BlockProductionState('
        'epoch: $currentEpoch, '
        'scheduledSlots: ${scheduledSlots.length}, '
        'nextSlot: ${nextSlot?.slotNumber ?? "none"}, '
        'vrfStatus: ${currentVrfStatus?.displayName ?? "unknown"}, '
        'produced: $successfulProductionsCount, '
        'failed: $failedProductionsCount'
        ')';
  }
}
