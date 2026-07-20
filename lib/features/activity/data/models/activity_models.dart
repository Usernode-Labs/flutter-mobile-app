import 'dart:collection';

const _maxSignedInt64 = '9223372036854775807';
final _consumerTokenPattern = RegExp(r'^act1_[A-Za-z0-9_-]{43}$');
final _positiveDecimalPattern = RegExp(r'^[1-9][0-9]{0,18}$');
final _boundedTokenPattern = RegExp(r'^[a-z][a-z0-9_]*(?:[.-][a-z0-9_]+)*$');
final _contractIdPattern = RegExp(
  r'^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+\.v[1-9][0-9]*$',
);
final _opaqueIdPattern = RegExp(r'^[^\u0000-\u0020\u007F]+$');
final _rfc3339Pattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|[+-](\d{2}):(\d{2}))$',
);

enum ActivityAttention {
  receipt('receipt'),
  unread('unread');

  const ActivityAttention(this.wireValue);

  final String wireValue;

  static ActivityAttention parse(Object? value, String field) {
    for (final attention in values) {
      if (attention.wireValue == value) return attention;
    }
    throw FormatException('Invalid $field');
  }
}

class ActivitySession {
  const ActivitySession._({
    required this.accessToken,
    required this.expiresAt,
  });

  final String accessToken;
  final DateTime expiresAt;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now.toUtc());

  factory ActivitySession.fromJson(Map<String, dynamic> json) {
    expectActivityJsonKeys(
      json,
      const {'accessToken', 'tokenType', 'expiresAt'},
    );
    final token = requiredActivityString(json, 'accessToken');
    if (!_consumerTokenPattern.hasMatch(token)) {
      throw const FormatException('Invalid accessToken');
    }
    if (json['tokenType'] != 'Bearer') {
      throw const FormatException('Invalid tokenType');
    }
    return ActivitySession._(
      accessToken: token,
      expiresAt: requiredActivityTimestamp(json, 'expiresAt'),
    );
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'tokenType': 'Bearer',
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      };
}

class ActivityFeedPage {
  const ActivityFeedPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<ActivityItem> items;
  final String? nextCursor;
  final bool hasMore;

  factory ActivityFeedPage.fromJson(Map<String, dynamic> json) {
    expectActivityJsonKeys(json, const {'items', 'nextCursor', 'hasMore'});
    final hasMore = requiredActivityBool(json, 'hasMore');
    final cursor = nullableActivityCursor(json['nextCursor'], 'nextCursor');
    if (hasMore && cursor == null) {
      throw const FormatException(
          'nextCursor is required when hasMore is true');
    }
    if (!hasMore && cursor != null) {
      throw const FormatException(
          'nextCursor must be null when hasMore is false');
    }
    return ActivityFeedPage(
      items: _activityItems(json['items']),
      nextCursor: cursor,
      hasMore: hasMore,
    );
  }
}

class ActivitySyncPage {
  const ActivitySyncPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<ActivityItem> items;
  final String nextCursor;
  final bool hasMore;

  factory ActivitySyncPage.fromJson(Map<String, dynamic> json) {
    expectActivityJsonKeys(json, const {'items', 'nextCursor', 'hasMore'});
    return ActivitySyncPage(
      items: _activityItems(json['items']),
      nextCursor: requiredActivityCursor(json, 'nextCursor'),
      hasMore: requiredActivityBool(json, 'hasMore'),
    );
  }
}

class ActivityUnreadCount {
  const ActivityUnreadCount(this.value);

  final int value;

  factory ActivityUnreadCount.fromJson(Map<String, dynamic> json) {
    expectActivityJsonKeys(json, const {'unreadCount'});
    return ActivityUnreadCount(
      requiredActivityInteger(json, 'unreadCount', minimum: 0),
    );
  }
}

class ActivityItem {
  const ActivityItem({
    required this.inboxSequence,
    required this.syncSequence,
    required this.defaultAttention,
    required this.readAt,
    required this.activityEvent,
  });

  final String inboxSequence;
  final String syncSequence;
  final ActivityAttention defaultAttention;
  final DateTime? readAt;
  final ActivityEvent activityEvent;

  bool get isUnread =>
      defaultAttention == ActivityAttention.unread && readAt == null;

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    expectActivityJsonKeys(
      json,
      const {
        'inboxSequence',
        'syncSequence',
        'defaultAttention',
        'readAt',
        'activityEvent',
      },
    );
    return ActivityItem(
      inboxSequence: requiredActivitySequence(json, 'inboxSequence'),
      syncSequence: requiredActivitySequence(json, 'syncSequence'),
      defaultAttention:
          ActivityAttention.parse(json['defaultAttention'], 'defaultAttention'),
      readAt: nullableActivityTimestamp(json['readAt'], 'readAt'),
      activityEvent: ActivityEvent.fromJson(
        requiredActivityObject(json, 'activityEvent'),
      ),
    );
  }
}

class ActivityEvent {
  const ActivityEvent({
    required this.envelopeVersion,
    required this.ledgerId,
    required this.activityEventId,
    required this.source,
    required this.recipientResolution,
    required this.contractId,
    required this.appliedPolicyId,
    required this.ingestedAt,
    required this.privacy,
    required this.retentionClass,
    required this.sourceEvent,
  });

  final int envelopeVersion;
  final String ledgerId;
  final String activityEventId;
  final ActivitySource source;
  final ActivityRecipientResolution recipientResolution;
  final String contractId;
  final String appliedPolicyId;
  final DateTime ingestedAt;
  final String privacy;
  final String retentionClass;
  final ActivitySourceEvent sourceEvent;

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    expectActivityJsonKeys(
      json,
      const {
        'envelopeVersion',
        'ledgerId',
        'activityEventId',
        'source',
        'recipientResolution',
        'contractId',
        'appliedPolicyId',
        'ingestedAt',
        'privacy',
        'retentionClass',
        'sourceEvent',
      },
    );
    final envelopeVersion = requiredActivityInteger(json, 'envelopeVersion');
    if (envelopeVersion != 1) {
      throw const FormatException('Unsupported activity envelopeVersion');
    }
    return ActivityEvent(
      envelopeVersion: envelopeVersion,
      ledgerId: _requiredOpaqueId(
        json,
        'ledgerId',
        minimumLength: 1,
        maximumLength: 256,
      ),
      activityEventId: _requiredOpaqueId(
        json,
        'activityEventId',
        minimumLength: 16,
        maximumLength: 64,
      ),
      source: ActivitySource.fromJson(requiredActivityObject(json, 'source')),
      recipientResolution: ActivityRecipientResolution.fromJson(
        requiredActivityObject(json, 'recipientResolution'),
      ),
      contractId: _requiredContractId(json, 'contractId'),
      appliedPolicyId: _requiredContractId(json, 'appliedPolicyId'),
      ingestedAt: requiredActivityTimestamp(json, 'ingestedAt'),
      privacy: _requiredEnumString(
        json,
        'privacy',
        const {'public_preview', 'private_preview', 'hidden_preview'},
      ),
      retentionClass: _requiredBoundedToken(json, 'retentionClass'),
      sourceEvent: ActivitySourceEvent.fromJson(
        requiredActivityObject(json, 'sourceEvent'),
      ),
    );
  }
}

class ActivitySource {
  const ActivitySource({
    required this.system,
    required this.producerId,
    required this.trustClass,
  });

  final String system;
  final String producerId;
  final String trustClass;

  factory ActivitySource.fromJson(Map<String, dynamic> json) {
    expectActivityJsonKeys(json, const {'system', 'producerId', 'trustClass'});
    return ActivitySource(
      system: _requiredBoundedToken(json, 'system'),
      producerId: _requiredBoundedToken(json, 'producerId'),
      trustClass: _requiredEnumString(
        json,
        'trustClass',
        const {
          'node_chain',
          'first_party_server',
          'native_local',
          'dapp_proposed',
        },
      ),
    );
  }
}

class ActivityRecipientResolution {
  const ActivityRecipientResolution({
    required this.authority,
    required this.reference,
    required this.subject,
  });

  final String authority;
  final String reference;
  final String subject;

  factory ActivityRecipientResolution.fromJson(Map<String, dynamic> json) {
    expectActivityJsonKeys(json, const {'authority', 'reference', 'subject'});
    return ActivityRecipientResolution(
      authority: _requiredEnumString(
        json,
        'authority',
        const {
          'source_binding',
          'local_ledger',
          'resource_derived',
          'audience_policy',
        },
      ),
      reference: _requiredOpaqueId(json, 'reference'),
      subject: _requiredOpaqueId(json, 'subject'),
    );
  }
}

class ActivitySourceEvent {
  const ActivitySourceEvent({
    required this.envelopeVersion,
    required this.sourceEventId,
    required this.kind,
    required this.schemaVersion,
    required this.recipient,
    required this.resource,
    required this.occurredAt,
    required this.status,
    required this.canonicality,
    required this.facts,
    required this.aggregateKey,
    required this.route,
  });

  final int envelopeVersion;
  final String sourceEventId;
  final String kind;
  final int schemaVersion;
  final ActivityRecipient recipient;
  final ActivityResource resource;
  final DateTime occurredAt;
  final String status;
  final String canonicality;
  final Map<String, Object?> facts;
  final String aggregateKey;
  final ActivityRoute route;

  factory ActivitySourceEvent.fromJson(Map<String, dynamic> json) {
    expectActivityJsonKeys(
      json,
      const {
        'envelopeVersion',
        'sourceEventId',
        'kind',
        'schemaVersion',
        'recipient',
        'resource',
        'occurredAt',
        'status',
        'canonicality',
        'facts',
        'aggregateKey',
        'route',
      },
    );
    final envelopeVersion = requiredActivityInteger(json, 'envelopeVersion');
    if (envelopeVersion != 1) {
      throw const FormatException('Unsupported source envelopeVersion');
    }
    return ActivitySourceEvent(
      envelopeVersion: envelopeVersion,
      sourceEventId: _requiredOpaqueId(json, 'sourceEventId'),
      kind: _requiredNamespacedName(json, 'kind'),
      schemaVersion: requiredActivityInteger(
        json,
        'schemaVersion',
        minimum: 1,
        maximum: 2147483647,
      ),
      recipient: ActivityRecipient.fromJson(
        requiredActivityObject(json, 'recipient'),
      ),
      resource: ActivityResource.fromJson(
        requiredActivityObject(json, 'resource'),
      ),
      occurredAt: requiredActivityTimestamp(json, 'occurredAt'),
      status: _requiredBoundedToken(json, 'status'),
      canonicality: _requiredBoundedToken(json, 'canonicality'),
      facts: UnmodifiableMapView(
        Map<String, Object?>.from(requiredActivityObject(json, 'facts')),
      ),
      aggregateKey: _requiredOpaqueId(json, 'aggregateKey'),
      route: ActivityRoute.fromJson(requiredActivityObject(json, 'route')),
    );
  }
}

class ActivityRecipient {
  const ActivityRecipient({
    required this.relation,
    required this.subject,
    required this.scope,
  });

  final String relation;
  final String subject;
  final String scope;

  factory ActivityRecipient.fromJson(Map<String, dynamic> json) {
    expectActivityJsonKeys(json, const {'relation', 'subject', 'scope'});
    return ActivityRecipient(
      relation: _requiredNamespacedName(json, 'relation'),
      subject: _requiredOpaqueId(json, 'subject'),
      scope: _requiredEnumString(
        json,
        'scope',
        const {
          'installation',
          'node',
          'wallet',
          'account',
          'identity',
          'app',
          'operator',
          'broadcast',
        },
      ),
    );
  }
}

class ActivityResource {
  const ActivityResource({
    required this.type,
    required this.id,
    required this.version,
  });

  final String type;
  final String id;
  final int version;

  factory ActivityResource.fromJson(Map<String, dynamic> json) {
    expectActivityJsonKeys(json, const {'type', 'id', 'version'});
    return ActivityResource(
      type: _requiredBoundedToken(json, 'type'),
      id: _requiredOpaqueId(json, 'id'),
      version: requiredActivityInteger(
        json,
        'version',
        minimum: 1,
        maximum: 9007199254740991,
      ),
    );
  }
}

class ActivityRoute {
  const ActivityRoute({
    required this.kind,
    required this.schemaVersion,
    required this.parameters,
  });

  final String kind;
  final int schemaVersion;
  final Map<String, Object?> parameters;

  factory ActivityRoute.fromJson(Map<String, dynamic> json) {
    expectActivityJsonKeys(json, const {'kind', 'schemaVersion', 'parameters'});
    return ActivityRoute(
      kind: _requiredNamespacedName(json, 'kind'),
      schemaVersion: requiredActivityInteger(
        json,
        'schemaVersion',
        minimum: 1,
        maximum: 2147483647,
      ),
      parameters: UnmodifiableMapView(
        Map<String, Object?>.from(
          requiredActivityObject(json, 'parameters'),
        ),
      ),
    );
  }
}

List<ActivityItem> _activityItems(Object? value) {
  if (value is! List<dynamic>) {
    throw const FormatException('Invalid items');
  }
  return List.unmodifiable(
    value.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid activity item');
      }
      return ActivityItem.fromJson(item);
    }),
  );
}

void expectActivityJsonKeys(
  Map<String, dynamic> json,
  Set<String> expected,
) {
  if (json.length != expected.length ||
      !json.keys.toSet().containsAll(expected)) {
    throw const FormatException('Unexpected JSON fields');
  }
}

Map<String, dynamic> requiredActivityObject(
  Map<String, dynamic> json,
  String field,
) {
  final value = json[field];
  if (value is! Map<String, dynamic>) {
    throw FormatException('Invalid $field');
  }
  return value;
}

String requiredActivityString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid $field');
  }
  return value;
}

bool requiredActivityBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! bool) throw FormatException('Invalid $field');
  return value;
}

int requiredActivityInteger(
  Map<String, dynamic> json,
  String field, {
  int? minimum,
  int? maximum,
}) {
  final value = json[field];
  final int result;
  if (value is int) {
    result = value;
  } else if (value is double &&
      value.isFinite &&
      value == value.truncateToDouble() &&
      value.abs() <= 9007199254740991) {
    result = value.toInt();
  } else {
    throw FormatException('Invalid $field');
  }
  if (minimum != null && result < minimum) {
    throw FormatException('Invalid $field');
  }
  if (maximum != null && result > maximum) {
    throw FormatException('Invalid $field');
  }
  return result;
}

DateTime requiredActivityTimestamp(
  Map<String, dynamic> json,
  String field,
) {
  final value = json[field];
  if (value is! String) throw FormatException('Invalid $field');
  final match = _rfc3339Pattern.firstMatch(value);
  if (match == null || !_hasValidCalendarFields(match)) {
    throw FormatException('Invalid $field');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Invalid $field');
  return parsed.toUtc();
}

bool _hasValidCalendarFields(RegExpMatch match) {
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  final offsetHour = int.tryParse(match.group(8) ?? '0') ?? 0;
  final offsetMinute = int.tryParse(match.group(9) ?? '0') ?? 0;
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      hour > 23 ||
      minute > 59 ||
      second > 59 ||
      offsetHour > 23 ||
      offsetMinute > 59) {
    return false;
  }
  const monthLengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  var maximumDay = monthLengths[month - 1];
  final leapYear = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
  if (month == 2 && leapYear) maximumDay = 29;
  return day <= maximumDay;
}

String _requiredBoundedToken(Map<String, dynamic> json, String field) {
  final value = requiredActivityString(json, field);
  if (value.length > 128 || !_boundedTokenPattern.hasMatch(value)) {
    throw FormatException('Invalid $field');
  }
  return value;
}

String _requiredContractId(Map<String, dynamic> json, String field) {
  final value = requiredActivityString(json, field);
  if (value.length < 6 ||
      value.length > 180 ||
      !_contractIdPattern.hasMatch(value)) {
    throw FormatException('Invalid $field');
  }
  return value;
}

String _requiredNamespacedName(Map<String, dynamic> json, String field) {
  final value = requiredActivityString(json, field);
  final pattern = RegExp(r'^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$');
  if (value.length < 3 || value.length > 160 || !pattern.hasMatch(value)) {
    throw FormatException('Invalid $field');
  }
  return value;
}

String _requiredOpaqueId(
  Map<String, dynamic> json,
  String field, {
  int minimumLength = 1,
  int maximumLength = 256,
}) {
  final value = requiredActivityString(json, field);
  if (value.length < minimumLength ||
      value.length > maximumLength ||
      !_opaqueIdPattern.hasMatch(value)) {
    throw FormatException('Invalid $field');
  }
  return value;
}

String _requiredEnumString(
  Map<String, dynamic> json,
  String field,
  Set<String> allowed,
) {
  final value = requiredActivityString(json, field);
  if (!allowed.contains(value)) throw FormatException('Invalid $field');
  return value;
}

DateTime? nullableActivityTimestamp(Object? value, String field) {
  if (value == null) return null;
  return requiredActivityTimestamp({field: value}, field);
}

String requiredActivitySequence(Map<String, dynamic> json, String field) {
  final value = requiredActivityString(json, field);
  if (!_positiveDecimalPattern.hasMatch(value) ||
      (value.length == _maxSignedInt64.length &&
          value.compareTo(_maxSignedInt64) > 0)) {
    throw FormatException('Invalid $field');
  }
  return value;
}

String requiredActivityCursor(Map<String, dynamic> json, String field) {
  final value = requiredActivityString(json, field);
  if (value.trim().isEmpty) throw FormatException('Invalid $field');
  return value;
}

String? nullableActivityCursor(Object? value, String field) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $field');
  }
  return value;
}
