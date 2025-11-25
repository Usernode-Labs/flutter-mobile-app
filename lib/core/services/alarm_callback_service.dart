import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/log_tag.dart';
import '../config/blockchain_timing.dart';
import '../data/slot_production_repository.dart';
import 'epoch_slot_scheduler_service.dart';
import 'slot_monitor_service.dart';
import 'platform_alarm_service.dart';

final _log = LoggingService.instance.withTag(LogTag.node);

/// Service that handles callbacks when platform alarms fire
///
/// This service is triggered when exact alarms (Android) or BGTasks (iOS)
/// execute, and coordinates the slot monitoring process.
class AlarmCallbackService {
  static final AlarmCallbackService instance = AlarmCallbackService._();
  AlarmCallbackService._();

  /// Handle alarm callback for a specific slot
  ///
  /// This is called when a platform alarm fires, either from:
  /// - Android: AlarmReceiver + SlotMonitoringService
  /// - iOS: BGProcessingTask handler
  Future<void> handleAlarmCallback(int slotNumber) async {
    _log.info('Alarm callback received for slot $slotNumber');

    try {
      // Start foreground service on Android to keep app alive
      await _startForegroundServiceIfNeeded(slotNumber);

      // Start monitoring this slot
      final scheduledSlots =
          EpochSlotSchedulerService.instance.getScheduledSlots();
      final targetSlot = scheduledSlots.firstWhere(
        (slot) => slot.slotNumber == slotNumber,
        orElse: () =>
            throw StateError('Slot $slotNumber not found in schedule'),
      );

      _log.info('Starting monitoring for slot ${targetSlot.slotNumber}');
      await SlotMonitorService.instance.startMonitoringSlot(targetSlot);

      // Record production attempt to statistics repository
      try {
        await SlotProductionRepository.instance.recordProductionAttempt(
          slotNumber: slotNumber,
          attemptTime: DateTime.now(),
        );
        _log.debug('Recorded production attempt for slot $slotNumber');
      } catch (e) {
        LoggingService.instance.warn(
            'Failed to record production attempt for slot $slotNumber: $e');
      }

      // Listen for monitoring completion
      _setupMonitoringCompletionListener(slotNumber);
    } catch (e) {
      _log.error('Error handling alarm callback: $e');
    }
  }

  /// Start foreground service if on Android
  Future<void> _startForegroundServiceIfNeeded(int slotNumber) async {
    try {
      final success =
          await PlatformAlarmService.instance.startForegroundService(
        title: 'Block Production Active',
        message: 'Monitoring slot $slotNumber for block production',
        slotNumber: slotNumber,
      );

      if (success) {
        _log.info('Foreground service started for slot $slotNumber');
      }
    } catch (e) {
      _log.warn('Could not start foreground service: $e');
    }
  }

  /// Setup listener to stop foreground service when monitoring completes
  void _setupMonitoringCompletionListener(int slotNumber) {
    final subscription =
        SlotMonitorService.instance.monitoringEvents.listen((event) {
      if (event.slotNumber != slotNumber) return;

      // Stop foreground service when monitoring stops
      if (event.type == MonitoringEventType.stopped ||
          event.type == MonitoringEventType.slotProduced ||
          event.type == MonitoringEventType.timeout) {
        _stopForegroundService();
      }
    });

    // Auto-cancel subscription after monitoring window
    Future.delayed(BlockchainTiming.listenerAutoCancel, () {
      subscription.cancel();
    });
  }

  /// Stop foreground service
  Future<void> _stopForegroundService() async {
    try {
      await PlatformAlarmService.instance.stopForegroundService();
      _log.info('Foreground service stopped');
    } catch (e) {
      _log.warn('Error stopping foreground service: $e');
    }
  }

  /// Initialize the alarm callback service
  ///
  /// This should be called during app startup to ensure callbacks
  /// are ready to handle alarm events.
  Future<bool> initialize() async {
    _log.info('AlarmCallbackService initialized');
    return true;
  }
}
