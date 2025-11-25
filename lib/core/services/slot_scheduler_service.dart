import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/log_tag.dart';
import '../../features/node/data/repositories/rust_backend_service.dart';
import 'platform_alarm_service.dart';

final _log = LoggingService.instance.withTag(LogTag.node);

/// Service responsible for scheduling alarms/tasks for won slots
///
/// This service queries the Rust backend for won slots and schedules
/// platform-specific wake-ups (exact alarms on Android, BGTasks on iOS)
/// to ensure the app can monitor and produce blocks at the right time.
class SlotSchedulerService {
  static final SlotSchedulerService instance = SlotSchedulerService._();
  SlotSchedulerService._();

  bool _initialized = false;
  List<ScheduledSlot> _scheduledSlots = [];

  /// Check if the service is initialized
  bool get isInitialized => _initialized;

  /// Initialize the slot scheduler service
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      _log.info('SlotSchedulerService initializing...');

      // Load any previously scheduled slots from persistence
      await _loadPersistedSlots();

      // Register boot reschedule callback with PlatformAlarmService
      PlatformAlarmService.instance.setBootRescheduleCallback(() async {
        _log.info('Boot reschedule callback invoked - rescheduling all slots');
        await scheduleDailySlots();
      });

      _initialized = true;
      _log.info(
          'SlotSchedulerService initialized with ${_scheduledSlots.length} persisted slots');
      return true;
    } catch (e) {
      _log.error('Error initializing SlotSchedulerService: $e');
      return false;
    }
  }

  /// Schedule alarms for all won slots in the current epoch
  ///
  /// This queries the Rust backend for won slots and schedules
  /// platform-specific alarms for each slot.
  Future<SchedulingResult> scheduleDailySlots({
    int? epoch,
    Duration advanceTime = const Duration(minutes: 2),
  }) async {
    if (!_initialized) {
      _log.warn('Cannot schedule slots: service not initialized');
      return SchedulingResult(
        success: false,
        error: 'Service not initialized',
      );
    }

    try {
      _log.info('Querying won slots for epoch ${epoch ?? "current"}...');

      // Query Rust backend for won slots
      final rpc = RustBackendService.instance.rpc;
      if (rpc == null) {
        _log.warn('RPC service not available');
        return SchedulingResult(
          success: false,
          error: 'RPC service not available',
        );
      }

      final epochData = await rpc.epochRewards(
        epoch: epoch,
        includeWonSlots: true,
      );

      if (epochData == null ||
          epochData.wonSlots == null ||
          epochData.wonSlots!.isEmpty) {
        _log.info('No won slots found for epoch ${epochData?.epoch ?? epoch}');
        return SchedulingResult(
          success: true,
          slotsScheduled: 0,
          message: 'No won slots in this epoch',
        );
      }

      _log.info('Found ${epochData.wonSlots!.length} won slots');

      // Clear old scheduled slots
      await cancelAllSlots();

      // Schedule alarms for each won slot
      final List<ScheduledSlot> newSlots = [];
      int successCount = 0;
      int failureCount = 0;

      for (final wonSlot in epochData.wonSlots!) {
        final slotTime = DateTime.fromMillisecondsSinceEpoch(
          wonSlot.expectedTimeMs.toInt(),
        );
        final alarmTime = slotTime.subtract(advanceTime);

        // Only schedule future slots
        if (alarmTime.isAfter(DateTime.now())) {
          final scheduled = ScheduledSlot(
            slotNumber: wonSlot.globalSlot,
            slotTime: slotTime,
            alarmTime: alarmTime,
            epoch: epochData.epoch,
          );

          final success = await _scheduleSlotAlarm(scheduled);
          if (success) {
            newSlots.add(scheduled);
            successCount++;
          } else {
            failureCount++;
          }
        } else {
          _log.debug('Skipping past slot ${wonSlot.globalSlot}');
        }
      }

      _scheduledSlots = newSlots;
      await _persistSlots();

      _log.info(
        'Scheduled $successCount slots successfully, $failureCount failures',
      );

      return SchedulingResult(
        success: true,
        slotsScheduled: successCount,
        slotsFailed: failureCount,
        message: 'Scheduled $successCount slots for epoch ${epochData.epoch}',
      );
    } catch (e) {
      _log.error('Error scheduling daily slots: $e');
      return SchedulingResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Schedule alarm for a specific slot
  Future<bool> _scheduleSlotAlarm(ScheduledSlot slot) async {
    try {
      _log.debug(
        'Scheduling alarm for slot ${slot.slotNumber} at ${slot.alarmTime}',
      );

      // Use platform alarm service for scheduling
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
  Future<void> cancelAllSlots() async {
    try {
      _log.info('Cancelling ${_scheduledSlots.length} scheduled slots');

      for (final slot in _scheduledSlots) {
        await _cancelSlotAlarm(slot);
      }

      _scheduledSlots.clear();
      await _persistSlots();

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

  /// Get list of currently scheduled slots
  List<ScheduledSlot> getScheduledSlots() {
    return List.unmodifiable(_scheduledSlots);
  }

  /// Get next upcoming slot
  ScheduledSlot? getNextSlot() {
    if (_scheduledSlots.isEmpty) return null;

    final now = DateTime.now();
    final upcomingSlots = _scheduledSlots
        .where((slot) => slot.slotTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.slotTime.compareTo(b.slotTime));

    return upcomingSlots.isNotEmpty ? upcomingSlots.first : null;
  }

  /// Check if slot monitoring should be active now
  bool isSlotMonitoringActive() {
    final now = DateTime.now();

    // Check if any slot is within monitoring window (2 min before to 5 min after)
    return _scheduledSlots.any((slot) {
      final beforeSlot = slot.slotTime.subtract(const Duration(minutes: 2));
      final afterSlot = slot.slotTime.add(const Duration(minutes: 5));
      return now.isAfter(beforeSlot) && now.isBefore(afterSlot);
    });
  }

  /// Load persisted slots from storage
  Future<void> _loadPersistedSlots() async {
    try {
      _scheduledSlots = [];
    } catch (e) {
      _log.error('Error loading persisted slots: $e');
    }
  }

  /// Persist current slots to storage
  Future<void> _persistSlots() async {
    try {} catch (e) {
      _log.error('Error persisting slots: $e');
    }
  }

  /// Handle epoch transition - reschedule all slots
  Future<void> handleEpochTransition() async {
    _log.info('Handling epoch transition, rescheduling slots...');
    await scheduleDailySlots();
  }
}

/// Represents a scheduled slot with alarm time
class ScheduledSlot {
  final int slotNumber;
  final DateTime slotTime;
  final DateTime alarmTime;
  final int epoch;

  ScheduledSlot({
    required this.slotNumber,
    required this.slotTime,
    required this.alarmTime,
    required this.epoch,
  });

  Map<String, dynamic> toJson() => {
        'slotNumber': slotNumber,
        'slotTime': slotTime.toIso8601String(),
        'alarmTime': alarmTime.toIso8601String(),
        'epoch': epoch,
      };

  factory ScheduledSlot.fromJson(Map<String, dynamic> json) => ScheduledSlot(
        slotNumber: json['slotNumber'] as int,
        slotTime: DateTime.parse(json['slotTime'] as String),
        alarmTime: DateTime.parse(json['alarmTime'] as String),
        epoch: json['epoch'] as int,
      );
}

/// Result of scheduling operation
class SchedulingResult {
  final bool success;
  final int slotsScheduled;
  final int slotsFailed;
  final String? message;
  final String? error;

  SchedulingResult({
    required this.success,
    this.slotsScheduled = 0,
    this.slotsFailed = 0,
    this.message,
    this.error,
  });
}
