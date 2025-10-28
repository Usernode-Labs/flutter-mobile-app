/// Configuration for notification system
class NotificationConfig {
  // Android notification channels
  static const String slotChannelId = 'slot_notifications';
  static const String slotChannelName = 'Slot Notifications';
  static const String slotChannelDescription =
      'Notifications for won slots, produced blocks, and missed slots';

  static const String generalChannelId = 'general_notifications';
  static const String generalChannelName = 'General Notifications';
  static const String generalChannelDescription =
      'General app notifications for rewards, transactions, etc.';

  // Background task configuration
  static const String backgroundTaskName = 'slot_monitoring_task';
  static const Duration backgroundTaskFrequency = Duration(minutes: 15);

  // Smart batching parameters
  static const int maxNotificationsPerHour = 5;
  static const Duration groupingWindow = Duration(minutes: 30);
  static const Duration lookAheadWindow = Duration(hours: 24);

  // Advance warning times (in minutes)
  static const List<int> advanceWarningOptions = [5, 10, 15, 30];
  static const int defaultAdvanceWarningMinutes = 10;

  // Notification priorities
  static const int priorityUpcoming = 3;
  static const int priorityMissed = 2;
  static const int priorityProduced = 1;

  // Notification IDs (base values, actual IDs will be slot-specific)
  static const int upcomingSlotNotificationIdBase = 1000;
  static const int producedBlockNotificationIdBase = 2000;
  static const int missedSlotNotificationIdBase = 3000;
  static const int groupedSlotNotificationIdBase = 4000;

  // Notification settings keys (for SharedPreferences)
  static const String prefKeyNotificationsEnabled = 'notifications_enabled';
  static const String prefKeyUpcomingEnabled = 'upcoming_notifications_enabled';
  static const String prefKeyProducedEnabled = 'produced_notifications_enabled';
  static const String prefKeyMissedEnabled = 'missed_notifications_enabled';
  static const String prefKeyAdvanceWarningMinutes = 'advance_warning_minutes';
  static const String prefKeySmartBatchingEnabled = 'smart_batching_enabled';
  static const String prefKeyScheduledNotifications = 'scheduled_notifications';

  // Default settings
  static const bool defaultNotificationsEnabled = true;
  static const bool defaultUpcomingEnabled = true;
  static const bool defaultProducedEnabled = true;
  static const bool defaultMissedEnabled = true;
  static const bool defaultSmartBatchingEnabled = true;
}

/// Types of slot notifications
enum SlotNotificationType {
  upcoming,
  produced,
  missed,
  grouped,
}

/// Scheduled notification metadata
class ScheduledNotification {
  final int notificationId;
  final int globalSlot;
  final SlotNotificationType type;
  final DateTime scheduledTime;
  final DateTime slotTime;

  ScheduledNotification({
    required this.notificationId,
    required this.globalSlot,
    required this.type,
    required this.scheduledTime,
    required this.slotTime,
  });

  Map<String, dynamic> toJson() => {
        'notificationId': notificationId,
        'globalSlot': globalSlot,
        'type': type.name,
        'scheduledTime': scheduledTime.toIso8601String(),
        'slotTime': slotTime.toIso8601String(),
      };

  factory ScheduledNotification.fromJson(Map<String, dynamic> json) {
    return ScheduledNotification(
      notificationId: json['notificationId'] as int,
      globalSlot: json['globalSlot'] as int,
      type: SlotNotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SlotNotificationType.upcoming,
      ),
      scheduledTime: DateTime.parse(json['scheduledTime'] as String),
      slotTime: DateTime.parse(json['slotTime'] as String),
    );
  }

  @override
  String toString() =>
      'ScheduledNotification(id: $notificationId, slot: $globalSlot, type: ${type.name})';
}

/// Grouped slot information for batched notifications
class GroupedSlots {
  final List<int> globalSlots;
  final DateTime startTime;
  final DateTime endTime;

  GroupedSlots({
    required this.globalSlots,
    required this.startTime,
    required this.endTime,
  });

  int get count => globalSlots.length;

  @override
  String toString() => 'GroupedSlots(count: $count, $startTime - $endTime)';
}
