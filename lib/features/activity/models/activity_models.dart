import 'dart:convert';

enum ActivitySource { challenge, dapp, node, reward, system, mock }

enum ActivityCategory {
  challengePromotion,
  challengeDeadline,
  dappTransaction,
  dappGame,
  dappMarket,
  dappCanvas,
  dappFeedback,
  dappIdentity,
  rewardActivity,
  productionSetup,
  productionStatus,
  productionResult,
}

enum ActivityPriority { passive, standard, attention, persistent }

class ActivityEvent {
  const ActivityEvent({
    required this.source,
    required this.category,
    required this.eventType,
    required this.title,
    required this.body,
    this.targetRoute,
    this.createdAt,
    this.priority = ActivityPriority.standard,
    this.pinned = false,
    this.dedupeKey,
    this.expiresAt,
    this.payload = const {},
  });

  final ActivitySource source;
  final ActivityCategory category;
  final String eventType;
  final String title;
  final String body;
  final DateTime? createdAt;
  final ActivityPriority priority;
  final bool pinned;
  final String? dedupeKey;
  final DateTime? expiresAt;
  final String? targetRoute;
  final Map<String, Object?> payload;
}

class ActivityRecord {
  const ActivityRecord({
    required this.id,
    required this.source,
    required this.category,
    required this.eventType,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.priority,
    required this.pinned,
    this.targetRoute,
    this.readAt,
    this.archivedAt,
    this.dedupeKey,
    this.expiresAt,
    this.payloadJson = const {},
    this.systemNotificationId,
  });

  final String id;
  final ActivitySource source;
  final ActivityCategory category;
  final String eventType;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? archivedAt;
  final ActivityPriority priority;
  final bool pinned;
  final String? dedupeKey;
  final DateTime? expiresAt;
  final String? targetRoute;
  final Map<String, Object?> payloadJson;
  final int? systemNotificationId;

  bool get unread => readAt == null;
  bool get archived => archivedAt != null;
  bool get expired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get hasDestination =>
      targetRoute != null &&
      targetRoute!.isNotEmpty &&
      targetRoute != '/activity';
  String get notificationRoute => hasDestination ? targetRoute! : '/activity';

  ActivityRecord copyWith({
    String? id,
    ActivitySource? source,
    ActivityCategory? category,
    String? eventType,
    String? title,
    String? body,
    DateTime? createdAt,
    DateTime? readAt,
    bool clearReadAt = false,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    ActivityPriority? priority,
    bool? pinned,
    String? dedupeKey,
    DateTime? expiresAt,
    String? targetRoute,
    Map<String, Object?>? payloadJson,
    int? systemNotificationId,
  }) {
    return ActivityRecord(
      id: id ?? this.id,
      source: source ?? this.source,
      category: category ?? this.category,
      eventType: eventType ?? this.eventType,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      readAt: clearReadAt ? null : readAt ?? this.readAt,
      archivedAt: clearArchivedAt ? null : archivedAt ?? this.archivedAt,
      priority: priority ?? this.priority,
      pinned: pinned ?? this.pinned,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      expiresAt: expiresAt ?? this.expiresAt,
      targetRoute: targetRoute ?? this.targetRoute,
      payloadJson: payloadJson ?? this.payloadJson,
      systemNotificationId: systemNotificationId ?? this.systemNotificationId,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'source': source.name,
    'category': category.name,
    'eventType': eventType,
    'title': title,
    'body': body,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (readAt != null) 'readAt': readAt!.toUtc().toIso8601String(),
    if (archivedAt != null) 'archivedAt': archivedAt!.toUtc().toIso8601String(),
    'priority': priority.name,
    'pinned': pinned,
    if (dedupeKey != null) 'dedupeKey': dedupeKey,
    if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
    if (targetRoute != null) 'targetRoute': targetRoute,
    'payloadJson': payloadJson,
    if (systemNotificationId != null)
      'systemNotificationId': systemNotificationId,
  };

  factory ActivityRecord.fromJson(Map<String, Object?> json) {
    return ActivityRecord(
      id: json['id'] as String,
      source: _enumByName(
        ActivitySource.values,
        json['source'] as String?,
        ActivitySource.system,
      ),
      category: _enumByName(
        ActivityCategory.values,
        json['category'] as String?,
        ActivityCategory.productionStatus,
      ),
      eventType: json['eventType'] as String? ?? 'unknown',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt:
          _date(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      readAt: _date(json['readAt']),
      archivedAt: _date(json['archivedAt']),
      priority: _enumByName(
        ActivityPriority.values,
        json['priority'] as String?,
        ActivityPriority.standard,
      ),
      pinned: json['pinned'] as bool? ?? false,
      dedupeKey: json['dedupeKey'] as String?,
      expiresAt: _date(json['expiresAt']),
      targetRoute: json['targetRoute'] as String?,
      payloadJson: _map(json['payloadJson']),
      systemNotificationId: (json['systemNotificationId'] as num?)?.toInt(),
    );
  }

  static ActivityRecord decode(String value) {
    return ActivityRecord.fromJson(jsonDecode(value) as Map<String, Object?>);
  }

  String encode() => jsonEncode(toJson());
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

Map<String, Object?> _map(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry('$key', value as Object?));
  }
  return const {};
}

extension ActivityCategoryLabel on ActivityCategory {
  String get routeHint {
    return switch (this) {
      ActivityCategory.challengePromotion => 'Challenges',
      ActivityCategory.challengeDeadline => 'Challenges',
      ActivityCategory.dappTransaction => 'dApps',
      ActivityCategory.dappGame => 'dApps',
      ActivityCategory.dappMarket => 'dApps',
      ActivityCategory.dappCanvas => 'dApps',
      ActivityCategory.dappFeedback => 'dApps',
      ActivityCategory.dappIdentity => 'dApps',
      ActivityCategory.rewardActivity => 'Rewards',
      ActivityCategory.productionSetup => 'Block production settings',
      ActivityCategory.productionStatus => 'Node status',
      ActivityCategory.productionResult => 'Node status',
    };
  }

  String get channelId {
    return switch (this) {
      ActivityCategory.challengePromotion ||
      ActivityCategory.challengeDeadline => 'activity_challenges',
      ActivityCategory.dappTransaction ||
      ActivityCategory.dappGame ||
      ActivityCategory.dappMarket ||
      ActivityCategory.dappCanvas ||
      ActivityCategory.dappFeedback ||
      ActivityCategory.dappIdentity => 'activity_dapps',
      ActivityCategory.rewardActivity => 'activity_rewards',
      ActivityCategory.productionSetup ||
      ActivityCategory.productionStatus ||
      ActivityCategory.productionResult => 'activity_production',
    };
  }

  String get channelName {
    return switch (this) {
      ActivityCategory.challengePromotion ||
      ActivityCategory.challengeDeadline => 'Challenge activity',
      ActivityCategory.dappTransaction ||
      ActivityCategory.dappGame ||
      ActivityCategory.dappMarket ||
      ActivityCategory.dappCanvas ||
      ActivityCategory.dappFeedback ||
      ActivityCategory.dappIdentity => 'dApp activity',
      ActivityCategory.rewardActivity => 'Reward activity',
      ActivityCategory.productionSetup ||
      ActivityCategory.productionStatus ||
      ActivityCategory.productionResult => 'Block production activity',
    };
  }
}
