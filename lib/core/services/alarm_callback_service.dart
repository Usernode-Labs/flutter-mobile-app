import 'package:logger/logger.dart';
import 'epoch_slot_scheduler_service.dart';
import 'slot_monitor_service.dart';
import 'platform_alarm_service.dart';

/// Service that handles callbacks when platform alarms fire
///
/// This service is triggered when exact alarms (Android) or BGTasks (iOS)
/// execute, and coordinates the slot monitoring process.
class AlarmCallbackService {
  static final AlarmCallbackService instance = AlarmCallbackService._();
  AlarmCallbackService._();

  final Logger _logger = Logger();

  /// Handle alarm callback for a specific slot
  ///
  /// This is called when a platform alarm fires, either from:
  /// - Android: AlarmReceiver + SlotMonitoringService
  /// - iOS: BGProcessingTask handler
  Future<void> handleAlarmCallback(int slotNumber) async {
    _logger.i('Alarm callback received for slot $slotNumber');

    try {
      // Start foreground service on Android to keep app alive
      await _startForegroundServiceIfNeeded(slotNumber);

      // Start monitoring this slot
      final scheduledSlots = EpochSlotSchedulerService.instance.getScheduledSlots();
      final targetSlot = scheduledSlots.firstWhere(
        (slot) => slot.slotNumber == slotNumber,
        orElse: () =>
            throw StateError('Slot $slotNumber not found in schedule'),
      );

      _logger.i('Starting monitoring for slot ${targetSlot.slotNumber}');
      await SlotMonitorService.instance.startMonitoringSlot(targetSlot);

      // Listen for monitoring completion
      _setupMonitoringCompletionListener(slotNumber);
    } catch (e) {
      _logger.e('Error handling alarm callback: $e');
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
        _logger.i('Foreground service started for slot $slotNumber');
      }
    } catch (e) {
      _logger.w('Could not start foreground service: $e');
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

    // Auto-cancel subscription after 10 minutes
    Future.delayed(const Duration(minutes: 10), () {
      subscription.cancel();
    });
  }

  /// Stop foreground service
  Future<void> _stopForegroundService() async {
    try {
      await PlatformAlarmService.instance.stopForegroundService();
      _logger.i('Foreground service stopped');
    } catch (e) {
      _logger.w('Error stopping foreground service: $e');
    }
  }

  /// Initialize the alarm callback service
  ///
  /// This should be called during app startup to ensure callbacks
  /// are ready to handle alarm events.
  Future<bool> initialize() async {
    _logger.i('AlarmCallbackService initialized');
    return true;
  }
}
