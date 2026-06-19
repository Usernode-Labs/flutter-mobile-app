import 'dart:math';

import 'package:crypto_mobile_app/features/activity/models/activity_models.dart';

class ActivityAttentionPolicy {
  const ActivityAttentionPolicy();

  ActivityRecord recordFor(ActivityEvent event) {
    final now = DateTime.now();
    final createdAt = event.createdAt ?? now;
    final id = _stableId(event, createdAt);
    final priority = _priorityFor(event);

    return ActivityRecord(
      id: id,
      source: event.source,
      category: event.category,
      eventType: event.eventType,
      title: event.title,
      body: event.body,
      createdAt: createdAt,
      priority: priority,
      pinned: event.pinned || priority == ActivityPriority.persistent,
      dedupeKey: event.dedupeKey,
      expiresAt: event.expiresAt,
      targetRoute: event.targetRoute,
      payloadJson: event.payload,
      systemNotificationId: _notificationIdFor(id),
    );
  }

  bool shouldPresentSystemNotification(ActivityRecord record) {
    if (record.archived || record.expired) return false;
    return switch (record.priority) {
      ActivityPriority.passive => false,
      ActivityPriority.standard => false,
      ActivityPriority.attention => true,
      ActivityPriority.persistent => true,
    };
  }

  ActivityPriority _priorityFor(ActivityEvent event) {
    if (event.priority != ActivityPriority.standard) return event.priority;
    return switch (event.category) {
      ActivityCategory.challengeDeadline => ActivityPriority.attention,
      ActivityCategory.dappTransaction => ActivityPriority.standard,
      ActivityCategory.dappGame => ActivityPriority.standard,
      ActivityCategory.dappMarket => ActivityPriority.attention,
      ActivityCategory.dappCanvas => ActivityPriority.passive,
      ActivityCategory.dappFeedback => ActivityPriority.attention,
      ActivityCategory.dappIdentity => ActivityPriority.attention,
      ActivityCategory.rewardActivity => ActivityPriority.standard,
      ActivityCategory.productionSetup => ActivityPriority.persistent,
      ActivityCategory.productionStatus => ActivityPriority.passive,
      ActivityCategory.productionResult => ActivityPriority.standard,
      ActivityCategory.challengePromotion => ActivityPriority.standard,
    };
  }

  static String _stableId(ActivityEvent event, DateTime createdAt) {
    final source = event.dedupeKey ?? event.eventType;
    return '${event.category.name}:$source:${createdAt.millisecondsSinceEpoch}';
  }

  static int _notificationIdFor(String id) {
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = 0x1fffffff & (hash + unit);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash = hash ^ (hash >> 6);
    }
    return max(1, hash);
  }
}
