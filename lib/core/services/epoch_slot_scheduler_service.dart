import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/node/data/repositories/rust_backend_service.dart';
import '../config/blockchain_timing.dart';
import 'platform_alarm_service.dart';
import 'local_notification_service.dart';

/// Service responsible for epoch-aware scheduling of slot alarms/tasks
///
/// This service:
/// - Tracks current epoch and detects transitions
/// - Queries the Rust backend for won slots in each epoch
/// - Schedules platform-specific wake-ups (exact alarms on Android, BGTasks on iOS)
/// - Monitors for epoch changes through periodic polling
/// - Auto-reschedules slots when epoch transitions occur
class EpochSlotSchedulerService {
  static final EpochSlotSchedulerService instance =
      EpochSlotSchedulerService._();
  EpochSlotSchedulerService._();

  final Logger _logger = Logger();

  bool _initialized = false;
  int? _currentEpoch;
  List<ScheduledSlot> _scheduledSlots = [];
  Timer? _epochMonitoringTimer;
  DateTime? _lastEpochCheck;

  // Configuration
  static Duration get _epochCheckInterval =>
      BlockchainTiming.epochCheckIntervalDefault;
  static const String _prefKeyCurrentEpoch = 'epoch_scheduler_current_epoch';
  static const String _prefKeyScheduledSlots =
      'epoch_scheduler_scheduled_slots';
  static const String _prefKeyLastCheck = 'epoch_scheduler_last_check';

  /// Check if the service is initialized
  bool get isInitialized => _initialized;

  /// Get current tracked epoch
  int? get currentEpoch => _currentEpoch;

  /// Get list of scheduled slots
  List<ScheduledSlot> get scheduledSlots => List.unmodifiable(_scheduledSlots);

  /// Initialize the epoch slot scheduler service
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      _logger.i('EpochSlotSchedulerService initializing...');

      // Load persisted state
      await _loadPersistedState();

      // Register boot reschedule callback with PlatformAlarmService
      PlatformAlarmService.instance.setBootRescheduleCallback(() async {
        _logger.i(
            'Boot reschedule callback invoked - checking epoch and rescheduling');
        await _checkForEpochTransition();
      });

      // Start epoch monitoring
      startEpochMonitoring();

      // Perform initial epoch check
      await _checkForEpochTransition();

      _initialized = true;
      _logger.i(
          'EpochSlotSchedulerService initialized with ${_scheduledSlots.length} persisted slots, current epoch: $_currentEpoch');
      return true;
    } catch (e) {
      _logger.e('Error initializing EpochSlotSchedulerService: $e');
      return false;
    }
  }

  /// Start periodic monitoring for epoch transitions
  void startEpochMonitoring() {
    if (_epochMonitoringTimer != null && _epochMonitoringTimer!.isActive) {
      _logger.d('Epoch monitoring already active');
      return;
    }

    _logger.i('Starting epoch monitoring (interval: $_epochCheckInterval)');
    _epochMonitoringTimer = Timer.periodic(_epochCheckInterval, (_) {
      _checkForEpochTransition();
    });
  }

  /// Stop periodic epoch monitoring
  void stopEpochMonitoring() {
    if (_epochMonitoringTimer != null) {
      _logger.i('Stopping epoch monitoring');
      _epochMonitoringTimer!.cancel();
      _epochMonitoringTimer = null;
    }
  }

  /// Adjust epoch monitoring frequency based on current position in epoch.
  ///
  /// Dynamically adjusts the check interval:
  /// - Early epoch (0-25%): Check every 30 minutes
  /// - Mid epoch (25-75%): Check every 15 minutes
  /// - Late epoch (75-100%): Check every 5 minutes
  Future<void> _adjustEpochMonitoringFrequency() async {
    final progress = await getEpochProgress();
    if (progress == null) {
      _logger.d('Cannot adjust epoch monitoring: progress unknown');
      return;
    }

    final newInterval = BlockchainTiming.getEpochCheckInterval(progress);

    // Check if timer is running and if interval needs changing
    if (_epochMonitoringTimer != null && _epochMonitoringTimer!.isActive) {
      // Only restart timer if interval changed significantly (more than 1 minute difference)
      final currentInterval = _epochCheckInterval;
      final diff =
          (newInterval.inMilliseconds - currentInterval.inMilliseconds).abs();

      if (diff > 60000) {
        // More than 1 minute difference
        _logger.i('Adjusting epoch check interval based on progress: '
            '${(progress * 100).toStringAsFixed(1)}% - '
            'new interval: ${newInterval.inMinutes} min '
            '(was ${currentInterval.inMinutes} min)');

        // Restart timer with new interval
        stopEpochMonitoring();
        _epochMonitoringTimer = Timer.periodic(newInterval, (_) async {
          await _checkForEpochTransition();
        });
      }
    }
  }

  /// Check if epoch has transitioned and handle accordingly
  Future<void> _checkForEpochTransition() async {
    try {
      _logger.d('Checking for epoch transition...');
      _lastEpochCheck = DateTime.now();

      // Query current epoch from Rust backend
      final rpc = RustBackendService.instance.rpc;
      if (rpc == null) {
        _logger.w('RPC service not available for epoch check');
        return;
      }

      // Query without epoch parameter to get current epoch info
      final epochData = await rpc.epochRewards(
        includeWonSlots: false, // Just need epoch number
      );

      if (epochData == null) {
        _logger.w('Failed to get epoch data from backend');
        return;
      }

      final newEpoch = epochData.epoch;
      _logger
          .d('Backend reports epoch: $newEpoch, tracked epoch: $_currentEpoch');

      // Check if epoch has changed
      if (_currentEpoch == null || newEpoch != _currentEpoch) {
        _logger.i('Epoch transition detected: $_currentEpoch → $newEpoch');
        await _handleEpochTransition(newEpoch);
      } else {
        _logger.d('No epoch change detected (still epoch $newEpoch)');
      }

      // Adjust monitoring frequency based on epoch progress
      await _adjustEpochMonitoringFrequency();

      // Persist last check time
      await _persistState();
    } catch (e) {
      _logger.e('Error checking for epoch transition: $e');
    }
  }

  /// Handle epoch transition event
  Future<void> _handleEpochTransition(int newEpoch) async {
    try {
      _logger.i('Handling epoch transition to epoch $newEpoch');

      final oldEpoch = _currentEpoch;
      _currentEpoch = newEpoch;

      // Cancel all old epoch alarms
      if (_scheduledSlots.isNotEmpty) {
        _logger.i('Cancelling ${_scheduledSlots.length} alarms from old epoch');
        await cancelAllSlots();
      }

      // Send notification to user about epoch transition
      await _notifyEpochTransition(oldEpoch, newEpoch);

      // Auto-reschedule slots for new epoch
      _logger.i('Auto-rescheduling slots for new epoch $newEpoch');
      final result = await scheduleEpochSlots(epoch: newEpoch);

      if (result.success) {
        _logger.i(
            'Successfully rescheduled ${result.slotsScheduled} slots for epoch $newEpoch');
      } else {
        _logger.e(
            'Failed to reschedule slots for epoch $newEpoch: ${result.error}');
      }

      // Persist updated epoch
      await _persistState();
    } catch (e) {
      _logger.e('Error handling epoch transition: $e');
    }
  }

  /// Send notification about epoch transition
  Future<void> _notifyEpochTransition(int? oldEpoch, int newEpoch) async {
    try {
      final title = 'New Epoch Started';
      final message = oldEpoch != null
          ? 'Epoch $oldEpoch → $newEpoch. Rescheduling won slots...'
          : 'Now tracking epoch $newEpoch. Scheduling won slots...';

      // Use local notification service to show notification
      await LocalNotificationService.instance.showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
        title: title,
        body: message,
        isSlotNotification: false, // General notification
      );

      _logger.i('Sent epoch transition notification');
    } catch (e) {
      _logger.w('Failed to send epoch transition notification: $e');
    }
  }

  /// Schedule alarms for all won slots in the specified epoch
  ///
  /// This queries the Rust backend for won slots and schedules
  /// platform-specific alarms for each slot.
  Future<SchedulingResult> scheduleEpochSlots({
    int? epoch,
    Duration? advanceTime,
  }) async {
    advanceTime ??= BlockchainTiming.alarmAdvanceTime;
    if (!_initialized) {
      _logger.w('Cannot schedule slots: service not initialized');
      return SchedulingResult(
        success: false,
        error: 'Service not initialized',
      );
    }

    try {
      _logger.i('Querying won slots for epoch ${epoch ?? "current"}...');

      // Query Rust backend for won slots
      final rpc = RustBackendService.instance.rpc;
      if (rpc == null) {
        _logger.w('RPC service not available');
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
        _logger.i('No won slots found for epoch ${epochData?.epoch ?? epoch}');

        // Update current epoch even if no slots won
        if (epochData != null) {
          _currentEpoch = epochData.epoch;
          await _persistState();
        }

        return SchedulingResult(
          success: true,
          slotsScheduled: 0,
          message: 'No won slots in this epoch',
        );
      }

      _logger.i(
          'Found ${epochData.wonSlots!.length} won slots for epoch ${epochData.epoch}');

      // Update current epoch
      _currentEpoch = epochData.epoch;

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
          _logger.d('Skipping past slot ${wonSlot.globalSlot}');
        }
      }

      _scheduledSlots = newSlots;
      await _persistState();

      _logger.i(
        'Scheduled $successCount slots successfully, $failureCount failures for epoch ${epochData.epoch}',
      );

      return SchedulingResult(
        success: true,
        slotsScheduled: successCount,
        slotsFailed: failureCount,
        message: 'Scheduled $successCount slots for epoch ${epochData.epoch}',
      );
    } catch (e) {
      _logger.e('Error scheduling epoch slots: $e');
      return SchedulingResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Schedule alarm for a specific slot
  Future<bool> _scheduleSlotAlarm(ScheduledSlot slot) async {
    try {
      _logger.d(
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
        _logger.i('Successfully scheduled alarm for slot ${slot.slotNumber}');
      } else {
        _logger.w('Failed to schedule alarm for slot ${slot.slotNumber}');
      }

      return success;
    } catch (e) {
      _logger.e('Error scheduling slot alarm: $e');
      return false;
    }
  }

  /// Cancel all scheduled slot alarms
  Future<void> cancelAllSlots() async {
    try {
      _logger.i('Cancelling ${_scheduledSlots.length} scheduled slots');

      for (final slot in _scheduledSlots) {
        await _cancelSlotAlarm(slot);
      }

      _scheduledSlots.clear();
      await _persistState();

      _logger.i('All slots cancelled');
    } catch (e) {
      _logger.e('Error cancelling all slots: $e');
    }
  }

  /// Cancel alarm for a specific slot
  Future<void> _cancelSlotAlarm(ScheduledSlot slot) async {
    try {
      final alarmId = 'slot_${slot.slotNumber}';
      await PlatformAlarmService.instance.cancelAlarm(alarmId);
      _logger.d('Cancelled alarm for slot ${slot.slotNumber}');
    } catch (e) {
      _logger.e('Error cancelling slot alarm: $e');
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

  /// Load persisted state from storage
  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load current epoch
      _currentEpoch = prefs.getInt(_prefKeyCurrentEpoch);
      _logger.d('Loaded persisted epoch: $_currentEpoch');

      // Load scheduled slots
      final slotsJson = prefs.getString(_prefKeyScheduledSlots);
      if (slotsJson != null) {
        final List<dynamic> slotsList = jsonDecode(slotsJson);
        _scheduledSlots = slotsList
            .map((json) => ScheduledSlot.fromJson(json as Map<String, dynamic>))
            .toList();
        _logger.d('Loaded ${_scheduledSlots.length} persisted slots');
      }

      // Load last check time
      final lastCheckMs = prefs.getInt(_prefKeyLastCheck);
      if (lastCheckMs != null) {
        _lastEpochCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckMs);
        _logger.d('Last epoch check was at: $_lastEpochCheck');
      }
    } catch (e) {
      _logger.e('Error loading persisted state: $e');
    }
  }

  /// Persist current state to storage
  Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save current epoch
      if (_currentEpoch != null) {
        await prefs.setInt(_prefKeyCurrentEpoch, _currentEpoch!);
      }

      // Save scheduled slots
      final slotsJson = jsonEncode(
        _scheduledSlots.map((slot) => slot.toJson()).toList(),
      );
      await prefs.setString(_prefKeyScheduledSlots, slotsJson);

      // Save last check time
      if (_lastEpochCheck != null) {
        await prefs.setInt(
          _prefKeyLastCheck,
          _lastEpochCheck!.millisecondsSinceEpoch,
        );
      }

      _logger.d(
          'Persisted state: epoch $_currentEpoch, ${_scheduledSlots.length} slots');
    } catch (e) {
      _logger.e('Error persisting state: $e');
    }
  }

  /// Calculate when the current epoch ends
  ///
  /// Returns null if current epoch is unknown or backend is unavailable.
  Future<DateTime?> getEpochEndTime() async {
    if (_currentEpoch == null) {
      _logger.d('Cannot calculate epoch end time: current epoch unknown');
      return null;
    }

    try {
      final status = await RustBackendService.instance.getStatus();
      if (status?.blockchain == null) {
        _logger.w(
            'Cannot calculate epoch end time: blockchain status unavailable');
        return null;
      }

      final currentGlobalSlot = status!.blockchain.bestTip.globalSlot;

      // Calculate epoch boundaries
      final epochStartSlot = _currentEpoch! * BlockchainTiming.slotsPerEpoch;
      final epochEndSlot = epochStartSlot + BlockchainTiming.slotsPerEpoch;
      final slotsUntilEnd = epochEndSlot - currentGlobalSlot;

      // Calculate time until epoch ends
      final msUntilEnd = slotsUntilEnd * BlockchainTiming.slotDurationMs;
      final epochEndTime =
          DateTime.now().add(Duration(milliseconds: msUntilEnd));

      return epochEndTime;
    } catch (e) {
      _logger.e('Error calculating epoch end time: $e');
      return null;
    }
  }

  /// Calculate progress through the current epoch (0.0 to 1.0)
  ///
  /// Returns null if current epoch is unknown or backend is unavailable.
  Future<double?> getEpochProgress() async {
    if (_currentEpoch == null) {
      _logger.d('Cannot calculate epoch progress: current epoch unknown');
      return null;
    }

    try {
      final status = await RustBackendService.instance.getStatus();
      if (status?.blockchain == null) {
        _logger.w(
            'Cannot calculate epoch progress: blockchain status unavailable');
        return null;
      }

      final currentGlobalSlot = status!.blockchain.bestTip.globalSlot;

      // Calculate slot position within epoch
      final slotInEpoch = currentGlobalSlot % BlockchainTiming.slotsPerEpoch;
      final progress = slotInEpoch / BlockchainTiming.slotsPerEpoch;

      return progress.clamp(0.0, 1.0);
    } catch (e) {
      _logger.e('Error calculating epoch progress: $e');
      return null;
    }
  }

  /// Calculate time remaining until the current epoch ends
  ///
  /// Returns null if current epoch is unknown or backend is unavailable.
  Future<Duration?> getTimeUntilEpochEnd() async {
    final epochEndTime = await getEpochEndTime();
    if (epochEndTime == null) return null;

    final now = DateTime.now();
    final timeRemaining = epochEndTime.difference(now);

    // Ensure we don't return negative durations
    return timeRemaining.isNegative ? Duration.zero : timeRemaining;
  }

  /// Get epoch duration based on blockchain constants
  Duration getEpochDuration() {
    return BlockchainTiming.epochDuration;
  }

  /// Dispose the service (cleanup)
  void dispose() {
    stopEpochMonitoring();
    _initialized = false;
  }
}

/// Represents a scheduled slot with alarm time and epoch
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
