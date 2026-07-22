import 'dart:async';
import 'dart:convert';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import '../../features/node/node_service.dart';
import '../data/slot_production_repository.dart';
import 'platform_alarm_service.dart';

final _log = LoggingService.instance.withTag('usernode/EpochSlotScheduler');

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

  bool _initialized = false;
  int? _currentEpoch;
  List<ScheduledSlot> _scheduledSlots = [];
  Timer? _epochMonitoringTimer;
  DateTime? _lastEpochCheck;

  // Configuration
  static Duration get _epochCheckInterval =>
      NodeStatusState.epochCheckIntervalDefault;
  static const String _prefKeyCurrentEpochBase =
      'epoch_scheduler_current_epoch';
  static const String _prefKeyScheduledSlotsBase =
      'epoch_scheduler_scheduled_slots';
  static const String _prefKeyLastCheckBase = 'epoch_scheduler_last_check';

  // Network-prefixed keys
  static String get _prefKeyCurrentEpoch =>
      NetworkPrefs.prefixAccountKey(_prefKeyCurrentEpochBase);
  static String get _prefKeyScheduledSlots =>
      NetworkPrefs.prefixAccountKey(_prefKeyScheduledSlotsBase);
  static String get _prefKeyLastCheck =>
      NetworkPrefs.prefixAccountKey(_prefKeyLastCheckBase);

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
      _log.info('EpochSlotSchedulerService initializing...');

      // Load persisted state
      await _loadPersistedState();

      // Register boot reschedule callback with PlatformAlarmService
      PlatformAlarmService.instance.setBootRescheduleCallback(() async {
        _log.info(
            'Boot reschedule callback invoked - checking epoch and rescheduling');
        await _checkForEpochTransition();
      });

      // Start epoch monitoring
      startEpochMonitoring();

      // Perform initial epoch check
      await _checkForEpochTransition();

      _initialized = true;
      _log.info(
          'EpochSlotSchedulerService initialized with ${_scheduledSlots.length} persisted slots, current epoch: $_currentEpoch');
      return true;
    } catch (e) {
      _log.error('Error initializing EpochSlotSchedulerService: $e');
      return false;
    }
  }

  /// Start periodic monitoring for epoch transitions
  void startEpochMonitoring() {
    if (_epochMonitoringTimer != null && _epochMonitoringTimer!.isActive) {
      _log.debug('Epoch monitoring already active');
      return;
    }

    _log.info('Starting epoch monitoring (interval: $_epochCheckInterval)');
    _epochMonitoringTimer = Timer.periodic(_epochCheckInterval, (_) {
      _checkForEpochTransition();
    });
  }

  /// Stop periodic epoch monitoring
  void stopEpochMonitoring() {
    if (_epochMonitoringTimer != null) {
      _log.info('Stopping epoch monitoring');
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
      _log.debug('Cannot adjust epoch monitoring: progress unknown');
      return;
    }

    final newInterval = NodeStatusState.getEpochCheckInterval(progress);

    // Check if timer is running and if interval needs changing
    if (_epochMonitoringTimer != null && _epochMonitoringTimer!.isActive) {
      // Only restart timer if interval changed significantly (more than 1 minute difference)
      final currentInterval = _epochCheckInterval;
      final diff =
          (newInterval.inMilliseconds - currentInterval.inMilliseconds).abs();

      if (diff > 60000) {
        // More than 1 minute difference
        _log.info('Adjusting epoch check interval based on progress: '
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
      _log.debug('Checking for epoch transition...');
      _lastEpochCheck = DateTime.now();

      // Query current epoch from Rust backend
      final rpc = RustBackendService.instance.rpc;
      if (rpc == null) {
        _log.warn('RPC service not available for epoch check');
        return;
      }

      // Query without epoch parameter to get current epoch info
      final epochData = await rpc.epochRewards(
        includeWonSlots: false, // Just need epoch number
      );

      if (epochData == null) {
        _log.warn('Failed to get epoch data from backend');
        return;
      }

      final newEpoch = epochData.epoch;
      _log.debug(
          'Backend reports epoch: $newEpoch, tracked epoch: $_currentEpoch');

      // Check if epoch has changed
      if (_currentEpoch == null || newEpoch != _currentEpoch) {
        _log.info('Epoch transition detected: $_currentEpoch → $newEpoch');
        await _handleEpochTransition(newEpoch);
      } else {
        _log.debug('No epoch change detected (still epoch $newEpoch)');
      }

      // Adjust monitoring frequency based on epoch progress
      await _adjustEpochMonitoringFrequency();

      // Persist last check time
      await _persistState();
    } catch (e) {
      _log.error('Error checking for epoch transition: $e');
    }
  }

  /// Handle epoch transition event
  Future<void> _handleEpochTransition(int newEpoch) async {
    try {
      _log.info('Handling epoch transition to epoch $newEpoch');

      final oldEpoch = _currentEpoch;
      _currentEpoch = newEpoch;

      // Cancel all old epoch alarms
      if (_scheduledSlots.isNotEmpty) {
        _log.info('Cancelling ${_scheduledSlots.length} alarms from old epoch');
        await cancelAllSlots();
      }

      // Send notification to user about epoch transition
      await _notifyEpochTransition(oldEpoch, newEpoch);

      // Auto-reschedule slots for new epoch
      _log.info('Auto-rescheduling slots for new epoch $newEpoch');
      final result = await scheduleEpochSlots(epoch: newEpoch);

      if (result.success) {
        _log.info(
            'Successfully rescheduled ${result.slotsScheduled} slots for epoch $newEpoch');
      } else {
        _log.error(
            'Failed to reschedule slots for epoch $newEpoch: ${result.error}');
      }

      // Persist updated epoch
      await _persistState();
    } catch (e) {
      _log.error('Error handling epoch transition: $e');
    }
  }

  /// Log epoch transition
  Future<void> _notifyEpochTransition(int? oldEpoch, int newEpoch) async {
    final message = oldEpoch != null
        ? 'Epoch $oldEpoch → $newEpoch. Rescheduling won slots...'
        : 'Now tracking epoch $newEpoch. Scheduling won slots...';
    _log.info('Epoch transition: $message');
  }

  /// Schedule alarms for all won slots in the specified epoch
  ///
  /// This now records won slots and clears legacy per-slot alarms. Precise
  /// Android wake scheduling is owned by the rolling `fg_resume` alarm plus the
  /// WorkManager watchdog.
  Future<SchedulingResult> scheduleEpochSlots({
    int? epoch,
    Duration? advanceTime,
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
      final clockDriftMs =
          await RustBackendService.instance.resolveNodeClockDriftMs();
      if (clockDriftMs == null) {
        _log.warn('Cannot schedule slots: node clock drift unavailable');
        return SchedulingResult(
          success: false,
          error: 'Node clock drift unavailable',
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

      _log.info(
          'Found ${epochData.wonSlots!.length} won slots for epoch ${epochData.epoch}');

      // Update current epoch
      _currentEpoch = epochData.epoch;

      // Clear old scheduled slots
      await cancelAllSlots();

      for (final wonSlot in epochData.wonSlots!) {
        final rustSlotTimeMs = wonSlot.expectedTimeMs.toInt();
        final localSlotTimeMs =
            RustBackendService.instance.localTimeMsFromRustTimeMs(
          rustSlotTimeMs,
          clockDriftMs: clockDriftMs,
        );
        final slotTime = DateTime.fromMillisecondsSinceEpoch(localSlotTimeMs);

        // Record won slot to statistics repository
        try {
          await SlotProductionRepository.instance.recordWonSlot(
            slotNumber: wonSlot.globalSlot,
            epoch: epochData.epoch,
            slotTime: slotTime,
          );
          _log.debug('Recorded won slot ${wonSlot.globalSlot} to statistics');
        } catch (e) {
          _log.warn('Failed to record won slot ${wonSlot.globalSlot}: $e');
        }
      }

      _scheduledSlots = [];
      await _persistState();

      _log.info(
        'Recorded ${epochData.wonSlots!.length} won slots for epoch ${epochData.epoch}; per-slot alarms are disabled',
      );

      return SchedulingResult(
        success: true,
        slotsScheduled: 0,
        slotsFailed: 0,
        message:
            'per-slot alarms disabled; fg_resume watchdog owns wake scheduling',
      );
    } catch (e) {
      _log.error('Error scheduling epoch slots: $e');
      return SchedulingResult(
        success: false,
        error: e.toString(),
      );
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
      await _persistState();

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

  /// Load persisted state from storage
  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load current epoch
      _currentEpoch = prefs.getInt(_prefKeyCurrentEpoch);
      _log.debug('Loaded persisted epoch: $_currentEpoch');

      // Load scheduled slots
      final slotsJson = prefs.getString(_prefKeyScheduledSlots);
      if (slotsJson != null) {
        final List<dynamic> slotsList = jsonDecode(slotsJson);
        _scheduledSlots = slotsList
            .map((json) => ScheduledSlot.fromJson(json as Map<String, dynamic>))
            .toList();
        _log.debug('Loaded ${_scheduledSlots.length} persisted slots');
      }

      // Load last check time
      final lastCheckMs = prefs.getInt(_prefKeyLastCheck);
      if (lastCheckMs != null) {
        _lastEpochCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckMs);
        _log.debug('Last epoch check was at: $_lastEpochCheck');
      }
    } catch (e) {
      _log.error('Error loading persisted state: $e');
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

      _log.debug(
          'Persisted state: epoch $_currentEpoch, ${_scheduledSlots.length} slots');
    } catch (e) {
      _log.error('Error persisting state: $e');
    }
  }

  /// Calculate when the current epoch ends
  ///
  /// Returns null if current epoch is unknown or backend is unavailable.
  Future<DateTime?> getEpochEndTime() async {
    if (_currentEpoch == null) {
      _log.debug('Cannot calculate epoch end time: current epoch unknown');
      return null;
    }

    try {
      final status = await RustBackendService.instance.getStatus();
      if (status?.blockchain == null) {
        _log.warn(
            'Cannot calculate epoch end time: blockchain status unavailable');
        return null;
      }

      // Use backend-provided current global slot
      final currentGlobalSlot = status!.node.curGlobalSlot;
      if (currentGlobalSlot == null) {
        _log.warn('curGlobalSlot unavailable from backend');
        return null;
      }

      // Get VRF evaluator from block producer status
      final bpStatus =
          await RustBackendService.instance.getBlockProducerStatus();

      // Use backend-provided epoch upper bound
      final epochEndSlot = bpStatus?.vrfEvaluator?.details?.status.whenOrNull(
        readyToEvaluate: (_, __, ___, upperBound, ____, _____) => upperBound,
      );
      if (epochEndSlot == null) {
        _log.warn('epochUpperBound unavailable from VRF evaluator');
        return null;
      }

      final slotsUntilEnd = epochEndSlot - currentGlobalSlot;

      // Calculate time until epoch ends using blockInterval from status
      final msUntilEnd = slotsUntilEnd * status.node.blockInterval;
      final epochEndTime =
          DateTime.now().add(Duration(milliseconds: msUntilEnd));

      return epochEndTime;
    } catch (e) {
      _log.error('Error calculating epoch end time: $e');
      return null;
    }
  }

  /// Calculate progress through the current epoch (0.0 to 1.0)
  ///
  /// Returns null if current epoch is unknown or backend is unavailable.
  Future<double?> getEpochProgress() async {
    if (_currentEpoch == null) {
      _log.debug('Cannot calculate epoch progress: current epoch unknown');
      return null;
    }

    try {
      final status = await RustBackendService.instance.getStatus();
      if (status?.blockchain == null) {
        _log.warn(
            'Cannot calculate epoch progress: blockchain status unavailable');
        return null;
      }

      // Use backend-provided current global slot
      final currentGlobalSlot = status!.node.curGlobalSlot;
      if (currentGlobalSlot == null) {
        _log.warn('curGlobalSlot unavailable from backend');
        return null;
      }

      // Get VRF evaluator from block producer status
      final bpStatus =
          await RustBackendService.instance.getBlockProducerStatus();

      // Use backend-provided epoch boundaries
      final epochUpperBound =
          bpStatus?.vrfEvaluator?.details?.status.whenOrNull(
        readyToEvaluate: (_, __, ___, upperBound, ____, _____) => upperBound,
      );
      if (epochUpperBound == null) {
        _log.warn('epochUpperBound unavailable from VRF evaluator');
        return null;
      }

      // Calculate epoch start from upper bound using slotsInEpoch from status
      final slotsInEpoch = status.node.slotsInEpoch;
      final epochStartSlot = epochUpperBound - slotsInEpoch + 1;

      // Calculate slot position within epoch
      final slotInEpoch = currentGlobalSlot - epochStartSlot;
      final progress = slotInEpoch / slotsInEpoch;

      return progress.clamp(0.0, 1.0);
    } catch (e) {
      _log.error('Error calculating epoch progress: $e');
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
  ///
  /// Returns null if backend is unavailable.
  Future<Duration?> getEpochDuration() async {
    try {
      final status = await RustBackendService.instance.getStatus();
      if (status == null) return null;
      return Duration(
          milliseconds: status.node.blockInterval * status.node.slotsInEpoch);
    } catch (e) {
      _log.error('Error getting epoch duration: $e');
      return null;
    }
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
  final int? rustSlotTimeMs;
  final int? clockDriftMs;

  ScheduledSlot({
    required this.slotNumber,
    required this.slotTime,
    required this.alarmTime,
    required this.epoch,
    this.rustSlotTimeMs,
    this.clockDriftMs,
  });

  Map<String, dynamic> toJson() => {
        'slotNumber': slotNumber,
        'slotTime': slotTime.toIso8601String(),
        'alarmTime': alarmTime.toIso8601String(),
        'epoch': epoch,
        if (rustSlotTimeMs != null) 'rustSlotTimeMs': rustSlotTimeMs,
        if (clockDriftMs != null) 'clockDriftMs': clockDriftMs,
      };

  factory ScheduledSlot.fromJson(Map<String, dynamic> json) => ScheduledSlot(
        slotNumber: json['slotNumber'] as int,
        slotTime: DateTime.parse(json['slotTime'] as String),
        alarmTime: DateTime.parse(json['alarmTime'] as String),
        epoch: json['epoch'] as int,
        rustSlotTimeMs: json['rustSlotTimeMs'] as int?,
        clockDriftMs: json['clockDriftMs'] as int?,
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
