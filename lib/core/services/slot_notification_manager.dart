import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import '../config/notification_config.dart';
import '../data/notification_state_repository.dart';
import 'local_notification_service.dart';
import '../../src/rust/rpc/rpcs_generated/epoch_rewards.dart';

/// Manager for scheduling and handling slot-related notifications
class SlotNotificationManager {
  static final SlotNotificationManager instance = SlotNotificationManager._();
  SlotNotificationManager._();

  final Logger _logger = Logger();
  final _notificationService = LocalNotificationService.instance;
  final _stateRepo = NotificationStateRepository.instance;

  // Track last notification time for rate limiting
  final Map<SlotNotificationType, DateTime> _lastNotificationTime = {};

  /// Schedule notifications for a list of won slots
  Future<void> scheduleNotificationsForSlots({
    required List<RpcEpochWonSlot> wonSlots,
    required Set<int> producedSlots,
    required int epoch,
  }) async {
    if (!_stateRepo.notificationsEnabled) {
      _logger.d('Notifications disabled, skipping scheduling');
      return;
    }

    _logger.i('Scheduling notifications for ${wonSlots.length} slots');

    // Clean up old notifications first
    await _stateRepo.cleanupOldNotifications();

    final now = DateTime.now();
    final advanceMinutes = _stateRepo.advanceWarningMinutes;

    // Filter slots within look-ahead window
    final upcomingSlots = wonSlots.where((slot) {
      final slotTime = DateTime.fromMillisecondsSinceEpoch(
        slot.expectedTimeMs.toInt(),
        isUtc: true,
      ).toLocal();
      return slotTime.isAfter(now) &&
          slotTime.isBefore(now.add(NotificationConfig.lookAheadWindow));
    }).toList();

    if (upcomingSlots.isEmpty) {
      _logger.d('No upcoming slots to schedule');
      return;
    }

    // Apply smart batching if enabled
    if (_stateRepo.smartBatchingEnabled) {
      await _scheduleWithSmartBatching(
        upcomingSlots: upcomingSlots,
        producedSlots: producedSlots,
        advanceMinutes: advanceMinutes,
        epoch: epoch,
      );
    } else {
      await _scheduleAllSlots(
        upcomingSlots: upcomingSlots,
        producedSlots: producedSlots,
        advanceMinutes: advanceMinutes,
        epoch: epoch,
      );
    }
  }

  /// Schedule notifications with smart batching algorithm
  Future<void> _scheduleWithSmartBatching({
    required List<RpcEpochWonSlot> upcomingSlots,
    required Set<int> producedSlots,
    required int advanceMinutes,
    required int epoch,
  }) async {
    // Sort slots by time
    final sortedSlots = List<RpcEpochWonSlot>.from(upcomingSlots)
      ..sort((a, b) => a.expectedTimeMs.compareTo(b.expectedTimeMs));

    final now = DateTime.now();
    final groupedClusters = <GroupedSlots>[];
    final individualSlots = <RpcEpochWonSlot>[];

    // Group nearby slots
    List<RpcEpochWonSlot> currentCluster = [];
    DateTime? clusterStart;

    for (final slot in sortedSlots) {
      final slotTime = DateTime.fromMillisecondsSinceEpoch(
        slot.expectedTimeMs.toInt(),
        isUtc: true,
      ).toLocal();

      // Skip already produced or past slots
      if (producedSlots.contains(slot.globalSlot) || slotTime.isBefore(now)) {
        continue;
      }

      // Start new cluster if needed
      if (currentCluster.isEmpty) {
        currentCluster.add(slot);
        clusterStart = slotTime;
        continue;
      }

      // Check if slot should be added to current cluster
      final timeSinceClusterStart = slotTime.difference(clusterStart!);
      if (timeSinceClusterStart <= NotificationConfig.groupingWindow) {
        currentCluster.add(slot);
      } else {
        // Finalize current cluster
        if (currentCluster.length >= 3) {
          // Group clusters of 3+ slots
          groupedClusters.add(GroupedSlots(
            globalSlots: currentCluster.map((s) => s.globalSlot).toList(),
            startTime: clusterStart,
            endTime: DateTime.fromMillisecondsSinceEpoch(
              currentCluster.last.expectedTimeMs.toInt(),
              isUtc: true,
            ).toLocal(),
          ));
        } else {
          // Keep small clusters as individual notifications
          individualSlots.addAll(currentCluster);
        }

        // Start new cluster
        currentCluster = [slot];
        clusterStart = slotTime;
      }
    }

    // Finalize last cluster
    if (currentCluster.isNotEmpty) {
      if (currentCluster.length >= 3) {
        groupedClusters.add(GroupedSlots(
          globalSlots: currentCluster.map((s) => s.globalSlot).toList(),
          startTime: clusterStart!,
          endTime: DateTime.fromMillisecondsSinceEpoch(
            currentCluster.last.expectedTimeMs.toInt(),
            isUtc: true,
          ).toLocal(),
        ));
      } else {
        individualSlots.addAll(currentCluster);
      }
    }

    _logger.d(
        'Smart batching: ${groupedClusters.length} groups, ${individualSlots.length} individual');

    // Schedule grouped notifications
    for (final cluster in groupedClusters) {
      await _scheduleGroupedNotification(
        cluster: cluster,
        advanceMinutes: advanceMinutes,
        epoch: epoch,
      );
    }

    // Schedule individual slot notifications (with rate limiting)
    int scheduledCount = 0;
    for (final slot in individualSlots) {
      if (scheduledCount >= NotificationConfig.maxNotificationsPerHour) {
        _logger.d('Rate limit reached, skipping remaining individual slots');
        break;
      }

      await _scheduleUpcomingSlotNotification(
        slot: slot,
        advanceMinutes: advanceMinutes,
        epoch: epoch,
      );
      scheduledCount++;
    }
  }

  /// Schedule all slots without batching
  Future<void> _scheduleAllSlots({
    required List<RpcEpochWonSlot> upcomingSlots,
    required Set<int> producedSlots,
    required int advanceMinutes,
    required int epoch,
  }) async {
    final now = DateTime.now();

    for (final slot in upcomingSlots) {
      final slotTime = DateTime.fromMillisecondsSinceEpoch(
        slot.expectedTimeMs.toInt(),
        isUtc: true,
      ).toLocal();

      // Skip already produced or past slots
      if (producedSlots.contains(slot.globalSlot) || slotTime.isBefore(now)) {
        continue;
      }

      await _scheduleUpcomingSlotNotification(
        slot: slot,
        advanceMinutes: advanceMinutes,
        epoch: epoch,
      );
    }
  }

  /// Schedule a notification for an upcoming slot
  Future<void> _scheduleUpcomingSlotNotification({
    required RpcEpochWonSlot slot,
    required int advanceMinutes,
    required int epoch,
  }) async {
    if (!_stateRepo.upcomingNotificationsEnabled) return;

    // Check if already scheduled
    if (_stateRepo.isNotificationScheduled(
      globalSlot: slot.globalSlot,
      type: SlotNotificationType.upcoming,
    )) {
      _logger.d('Notification already scheduled for slot ${slot.globalSlot}');
      return;
    }

    final slotTime = DateTime.fromMillisecondsSinceEpoch(
      slot.expectedTimeMs.toInt(),
      isUtc: true,
    ).toLocal();

    final notificationTime =
        slotTime.subtract(Duration(minutes: advanceMinutes));

    // Don't schedule if notification time is in the past
    if (notificationTime.isBefore(DateTime.now())) {
      _logger.d('Notification time in past for slot ${slot.globalSlot}');
      return;
    }

    final notificationId =
        NotificationConfig.upcomingSlotNotificationIdBase + slot.globalSlot;
    final timeFormatter = DateFormat('h:mm a');

    await _notificationService.scheduleNotification(
      id: notificationId,
      title: 'Slot in $advanceMinutes minutes',
      body: 'Slot #${slot.globalSlot} at ${timeFormatter.format(slotTime)}',
      scheduledTime: notificationTime,
      payload: 'slot:${slot.globalSlot}:upcoming',
      isSlotNotification: true,
    );

    await _stateRepo.addScheduledNotification(ScheduledNotification(
      notificationId: notificationId,
      globalSlot: slot.globalSlot,
      type: SlotNotificationType.upcoming,
      scheduledTime: notificationTime,
      slotTime: slotTime,
    ));

    _logger.d(
        'Scheduled upcoming notification for slot ${slot.globalSlot} at $notificationTime');
  }

  /// Schedule a grouped notification
  Future<void> _scheduleGroupedNotification({
    required GroupedSlots cluster,
    required int advanceMinutes,
    required int epoch,
  }) async {
    if (!_stateRepo.upcomingNotificationsEnabled) return;

    final notificationTime =
        cluster.startTime.subtract(Duration(minutes: advanceMinutes));

    // Don't schedule if notification time is in the past
    if (notificationTime.isBefore(DateTime.now())) {
      return;
    }

    final notificationId = NotificationConfig.groupedSlotNotificationIdBase +
        cluster.globalSlots.first;
    final timeFormatter = DateFormat('h:mm a');

    final startTimeStr = timeFormatter.format(cluster.startTime);
    final endTimeStr = timeFormatter.format(cluster.endTime);

    await _notificationService.scheduleNotification(
      id: notificationId,
      title: '${cluster.count} slots in next ${advanceMinutes} min',
      body: 'Slots from $startTimeStr to $endTimeStr',
      scheduledTime: notificationTime,
      payload: 'slots:grouped:${cluster.globalSlots.join(",")}',
      isSlotNotification: true,
    );

    // Track the grouped notification
    await _stateRepo.addScheduledNotification(ScheduledNotification(
      notificationId: notificationId,
      globalSlot: cluster.globalSlots.first,
      type: SlotNotificationType.grouped,
      scheduledTime: notificationTime,
      slotTime: cluster.startTime,
    ));

    _logger.d(
        'Scheduled grouped notification for ${cluster.count} slots at $notificationTime');
  }

  /// Notify when a block is successfully produced
  Future<void> notifyBlockProduced({
    required int globalSlot,
    required int epoch,
  }) async {
    if (!_stateRepo.notificationsEnabled ||
        !_stateRepo.producedNotificationsEnabled) {
      return;
    }

    // Rate limiting: don't spam if many blocks produced quickly
    if (_shouldRateLimit(SlotNotificationType.produced)) {
      _logger.d('Rate limiting produced notification for slot $globalSlot');
      return;
    }

    final notificationId =
        NotificationConfig.producedBlockNotificationIdBase + globalSlot;

    await _notificationService.showNotification(
      id: notificationId,
      title: 'Block produced!',
      body: 'Successfully produced block for slot #$globalSlot',
      payload: 'slot:$globalSlot:produced',
      isSlotNotification: true,
    );

    _lastNotificationTime[SlotNotificationType.produced] = DateTime.now();
    _logger.i('Notified block produced for slot $globalSlot');

    // Remove scheduled upcoming notification for this slot if it exists
    await _stateRepo.removeScheduledNotificationsForSlot(globalSlot);
  }

  /// Notify when a slot is missed
  Future<void> notifySlotMissed({
    required int globalSlot,
    required DateTime slotTime,
    required int epoch,
  }) async {
    if (!_stateRepo.notificationsEnabled ||
        !_stateRepo.missedNotificationsEnabled) {
      return;
    }

    // Rate limiting
    if (_shouldRateLimit(SlotNotificationType.missed)) {
      _logger.d('Rate limiting missed notification for slot $globalSlot');
      return;
    }

    final notificationId =
        NotificationConfig.missedSlotNotificationIdBase + globalSlot;
    final timeFormatter = DateFormat('h:mm a');

    await _notificationService.showNotification(
      id: notificationId,
      title: 'Slot missed',
      body: 'Slot #$globalSlot at ${timeFormatter.format(slotTime)} was not produced',
      payload: 'slot:$globalSlot:missed',
      isSlotNotification: true,
    );

    _lastNotificationTime[SlotNotificationType.missed] = DateTime.now();
    _logger.i('Notified slot missed for slot $globalSlot');

    // Remove scheduled upcoming notification for this slot if it exists
    await _stateRepo.removeScheduledNotificationsForSlot(globalSlot);
  }

  /// Check if we should rate limit notifications
  bool _shouldRateLimit(SlotNotificationType type) {
    final lastTime = _lastNotificationTime[type];
    if (lastTime == null) return false;

    final timeSinceLast = DateTime.now().difference(lastTime);
    // Don't send more than one notification of this type per minute
    return timeSinceLast.inSeconds < 60;
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllScheduledNotifications() async {
    await _notificationService.cancelAllNotifications();
    await _stateRepo.clearScheduledNotifications();
    _logger.i('Cancelled all scheduled notifications');
  }

  /// Re-schedule notifications (useful after settings change)
  Future<void> rescheduleNotifications({
    required List<RpcEpochWonSlot> wonSlots,
    required Set<int> producedSlots,
    required int epoch,
  }) async {
    _logger.i('Re-scheduling notifications');
    await cancelAllScheduledNotifications();
    await scheduleNotificationsForSlots(
      wonSlots: wonSlots,
      producedSlots: producedSlots,
      epoch: epoch,
    );
  }

  /// Get notification statistics
  Map<String, dynamic> getStats() {
    final pending = _stateRepo.getScheduledNotifications();
    final byType = _stateRepo.getNotificationStats();

    return {
      'total_scheduled': pending.length,
      'upcoming': byType[SlotNotificationType.upcoming] ?? 0,
      'grouped': byType[SlotNotificationType.grouped] ?? 0,
      'settings': {
        'enabled': _stateRepo.notificationsEnabled,
        'advance_minutes': _stateRepo.advanceWarningMinutes,
        'smart_batching': _stateRepo.smartBatchingEnabled,
      },
    };
  }
}
