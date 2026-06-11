// DTOs and shared types for the Leaderboard v2 Mobile API.
//
// Base URL: https://leaderboard.usernodelabs.org/api/v2/mobile/

import 'package:crypto_mobile_app/core/utils/app_deep_link_allowlist.dart';

// ---------------------------------------------------------------------------
// Safe JSON number helpers
// ---------------------------------------------------------------------------

enum CtaType { url, app }

/// Coerces a JSON value that may be [int], [double], or numeric [String] → [int].
/// Returns [raw] only when it is safe for the requested CTA type, otherwise
/// null. Backend-provided links must not introduce unsafe schemes or internal
/// paths into UI surfaces that launch URLs or navigate in-app.
String? _sanitizeCtaLink(CtaType? type, dynamic raw) {
  if (raw is! String || raw.isEmpty) return null;
  switch (type ?? CtaType.url) {
    case CtaType.url:
      final uri = Uri.tryParse(raw);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        return null;
      }
      return raw;
    case CtaType.app:
      return isAllowedAppDeepLinkPath(raw) ? raw : null;
  }
}

CtaType? _parseCtaType(dynamic raw) {
  if (raw is! String) return null;
  return switch (raw.toLowerCase()) {
    'url' => CtaType.url,
    'app' => CtaType.app,
    _ => null,
  };
}

String? _nonEmptyString(dynamic raw) {
  if (raw is! String || raw.isEmpty) return null;
  return raw;
}

int _jsonInt(dynamic v) => v is num ? v.toInt() : int.parse(v as String);

/// Nullable variant.
int? _jsonIntN(dynamic v) => v == null ? null : _jsonInt(v);

/// Coerces to [double].
double _jsonDouble(dynamic v) =>
    v is num ? v.toDouble() : double.parse(v as String);

/// Nullable variant.
double? _jsonDoubleN(dynamic v) => v == null ? null : _jsonDouble(v);

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

class LeaderboardApiException implements Exception {
  LeaderboardApiException(this.statusCode, this.message, {this.body});
  final int statusCode;
  final String message;
  final Object? body;

  @override
  String toString() => 'LeaderboardApiException($statusCode, $message)';
}

// ---------------------------------------------------------------------------
// Registration v2
// ---------------------------------------------------------------------------

class RegistrationEventInfo {
  final int id;
  final String name;
  final String? endsAt;

  const RegistrationEventInfo(
      {required this.id, required this.name, this.endsAt});

  factory RegistrationEventInfo.fromJson(Map<String, dynamic> json) {
    return RegistrationEventInfo(
      id: _jsonInt(json['event_id'] ?? json['id']),
      name: json['name'] as String? ?? '',
      endsAt: json['ends_at'] as String?,
    );
  }
}

class RegistrationV2Result {
  final int participantId;
  final String identityUid;
  final String publicKey;
  final String secretKey;
  final String address;
  final String tier;
  final int? seasonId;
  final String? seasonName;
  final RegistrationEventInfo? event;

  const RegistrationV2Result({
    required this.participantId,
    required this.identityUid,
    required this.publicKey,
    required this.secretKey,
    required this.address,
    required this.tier,
    this.seasonId,
    this.seasonName,
    this.event,
  });

  factory RegistrationV2Result.fromJson(Map<String, dynamic> json) {
    final event = json['event'] ?? json['phase'];
    return RegistrationV2Result(
      participantId: _jsonInt(json['participant_id']),
      identityUid: json['identity_uid'] as String? ?? '',
      publicKey: json['public_key'] as String? ?? '',
      secretKey: json['secret_key'] as String? ?? '',
      address: json['address'] as String? ?? '',
      tier: json['tier'] as String? ?? '',
      seasonId: _jsonIntN(json['season_id']),
      seasonName: json['season_name'] as String?,
      event: event is Map<String, dynamic>
          ? RegistrationEventInfo.fromJson(event)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Ranking
// ---------------------------------------------------------------------------

class RankingResult {
  final String scope;
  final int rank;
  final int totalPoints;
  final int offchainPoints;
  final int totalParticipants;
  // Scope-specific (event)
  final int? eventId;
  final String? eventName;
  // Scope-specific (season / global)
  final int? seasonId;
  final String? seasonName;
  final int? eventsParticipated;
  final int? totalProducedBlocks;

  const RankingResult({
    required this.scope,
    required this.rank,
    required this.totalPoints,
    required this.offchainPoints,
    required this.totalParticipants,
    this.eventId,
    this.eventName,
    this.seasonId,
    this.seasonName,
    this.eventsParticipated,
    this.totalProducedBlocks,
  });

  factory RankingResult.fromJson(Map<String, dynamic> json) {
    return RankingResult(
      scope: json['scope'] as String? ?? 'event',
      rank: _jsonIntN(json['rank']) ?? 0,
      totalPoints: _jsonIntN(json['total_points']) ?? 0,
      offchainPoints: _jsonIntN(json['offchain_points']) ?? 0,
      totalParticipants: _jsonIntN(json['total_participants']) ?? 0,
      eventId: _jsonIntN(json['event_id']),
      eventName: json['event_name'] as String?,
      seasonId: _jsonIntN(json['season_id']),
      seasonName: json['season_name'] as String?,
      eventsParticipated:
          _jsonIntN(json['events_participated'] ?? json['phases_participated']),
      totalProducedBlocks: _jsonIntN(json['total_produced_blocks']),
    );
  }

  Map<String, dynamic> toJson() => {
        'scope': scope,
        'rank': rank,
        'total_points': totalPoints,
        'offchain_points': offchainPoints,
        'total_participants': totalParticipants,
        if (eventId != null) 'event_id': eventId,
        if (eventName != null) 'event_name': eventName,
        if (seasonId != null) 'season_id': seasonId,
        if (seasonName != null) 'season_name': seasonName,
        if (eventsParticipated != null)
          'events_participated': eventsParticipated,
        if (totalProducedBlocks != null)
          'total_produced_blocks': totalProducedBlocks,
      };
}

// ---------------------------------------------------------------------------
// Challenges
// ---------------------------------------------------------------------------

class ChallengeDto {
  final int id;
  final int? eventId;
  final String? eventName;
  final String? eventType;
  final String category;
  final String goal;
  final String task;
  final String reward;
  final String? description;
  final String? requirements;
  final String? rewardLogic;
  final String? ctaLabel;
  final CtaType? ctaType;
  final String? ctaLink;
  final String? scheduleStart;
  final String? scheduleEnd;
  final bool enabled;
  final bool completed;
  final String? subCategory;

  /// Participant's activities for this challenge, present only when the list
  /// was fetched with `participant_id`. Empty otherwise.
  final List<BreakdownActivity> activities;

  /// Sum of points across [activities] (server-provided `activities_total`).
  final int activitiesTotal;

  const ChallengeDto({
    required this.id,
    this.eventId,
    this.eventName,
    this.eventType,
    required this.category,
    required this.goal,
    required this.task,
    required this.reward,
    this.description,
    this.requirements,
    this.rewardLogic,
    this.ctaLabel,
    this.ctaType,
    this.ctaLink,
    this.scheduleStart,
    this.scheduleEnd,
    required this.enabled,
    required this.completed,
    this.subCategory,
    this.activities = const [],
    this.activitiesTotal = 0,
  });

  factory ChallengeDto.fromJson(Map<String, dynamic> json) {
    final baseCtaType = _parseCtaType(json['cta_type']);
    final baseCtaLabel = json['cta_label'] as String?;
    final baseCtaLink = _sanitizeCtaLink(baseCtaType, json['cta_link']);
    final mobileCtaType = _parseCtaType(json['mobile_cta_type']);
    final mobileCtaLabel = _nonEmptyString(json['mobile_cta_label']);
    final mobileCtaLink = _nonEmptyString(json['mobile_cta_link']);
    final hasMobileCtaOverride = mobileCtaType != null ||
        mobileCtaLabel != null ||
        mobileCtaLink != null;
    final effectiveMobileCtaType = mobileCtaType ?? baseCtaType;
    final canInheritBaseCtaLink =
        mobileCtaLink == null && mobileCtaType == null;
    String? sanitizedMobileCtaLink;
    if (hasMobileCtaOverride) {
      sanitizedMobileCtaLink = canInheritBaseCtaLink
          ? baseCtaLink
          : _sanitizeCtaLink(effectiveMobileCtaType, mobileCtaLink);
    }
    final useMobileCta = sanitizedMobileCtaLink != null;
    final ctaType = useMobileCta ? effectiveMobileCtaType : baseCtaType;
    final ctaLabel =
        useMobileCta ? mobileCtaLabel ?? baseCtaLabel : baseCtaLabel;
    final ctaLink = useMobileCta ? sanitizedMobileCtaLink : baseCtaLink;
    return ChallengeDto(
      id: _jsonInt(json['id']),
      eventId: _jsonIntN(json['event_id']),
      eventName: json['event_name'] as String?,
      eventType: json['event_type'] as String?,
      category: json['category'] as String? ?? 'technical',
      goal: json['goal'] as String? ?? '',
      task: json['task'] as String? ?? '',
      reward: json['reward'].toString(),
      description: json['description'] as String?,
      requirements: json['requirements'] as String?,
      rewardLogic: json['reward_logic'] as String?,
      ctaLabel: ctaLabel,
      ctaType: ctaType,
      ctaLink: ctaLink,
      scheduleStart: json['schedule_start'] as String?,
      scheduleEnd: json['schedule_end'] as String?,
      enabled: json['enabled'] as bool? ?? false,
      completed: json['completed'] as bool? ?? false,
      subCategory: json['sub_category'] as String?,
      activities: (json['activities'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(BreakdownActivity.fromJson)
              .toList() ??
          const [],
      activitiesTotal: _jsonIntN(json['activities_total']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (eventId != null) 'event_id': eventId,
        if (eventName != null) 'event_name': eventName,
        if (eventType != null) 'event_type': eventType,
        'category': category,
        'goal': goal,
        'task': task,
        'reward': reward,
        if (description != null) 'description': description,
        if (requirements != null) 'requirements': requirements,
        if (rewardLogic != null) 'reward_logic': rewardLogic,
        if (ctaLabel != null) 'cta_label': ctaLabel,
        if (ctaType != null) 'cta_type': ctaType!.name,
        if (ctaLink != null) 'cta_link': ctaLink,
        if (scheduleStart != null) 'schedule_start': scheduleStart,
        if (scheduleEnd != null) 'schedule_end': scheduleEnd,
        'enabled': enabled,
        'completed': completed,
        if (subCategory != null) 'sub_category': subCategory,
        'activities': activities.map((a) => a.toJson()).toList(),
        'activities_total': activitiesTotal,
      };
}

// ---------------------------------------------------------------------------
// Leaderboard
// ---------------------------------------------------------------------------

class LeaderboardSeason {
  final int id;
  final String name;

  const LeaderboardSeason({required this.id, required this.name});

  factory LeaderboardSeason.fromJson(Map<String, dynamic> json) {
    return LeaderboardSeason(
      id: _jsonInt(json['id']),
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };
}

class LeaderboardEvent {
  final int id;
  final String name;
  final String? type;
  final String? startsAt;
  final String? endsAt;
  final bool isActive;

  const LeaderboardEvent({
    required this.id,
    required this.name,
    this.type,
    this.startsAt,
    this.endsAt,
    required this.isActive,
  });

  factory LeaderboardEvent.fromJson(Map<String, dynamic> json) {
    return LeaderboardEvent(
      id: _jsonInt(json['id']),
      name: json['name'] as String? ?? '',
      type: json['type'] as String?,
      startsAt: json['starts_at'] as String?,
      endsAt: json['ends_at'] as String?,
      isActive: json['is_active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (type != null) 'type': type,
        if (startsAt != null) 'starts_at': startsAt,
        if (endsAt != null) 'ends_at': endsAt,
        'is_active': isActive,
      };
}

// ---------------------------------------------------------------------------
// Seasons (from /seasons endpoint)
// ---------------------------------------------------------------------------

class SeasonEventDto {
  final int id;
  final String name;
  final String? type;
  final String? description;
  final String? startsAt;
  final String? endsAt;
  final bool isActive;

  const SeasonEventDto({
    required this.id,
    required this.name,
    this.type,
    this.description,
    this.startsAt,
    this.endsAt,
    required this.isActive,
  });

  factory SeasonEventDto.fromJson(Map<String, dynamic> json) {
    final id = _jsonInt(json['event_id'] ?? json['id']);
    return SeasonEventDto(
      id: id,
      name: json['name'] as String? ?? 'Event $id',
      type: json['type'] as String?,
      description: json['description'] as String?,
      startsAt: json['starts_at'] as String?,
      endsAt: json['ends_at'] as String?,
      isActive: json['is_active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'event_id': id,
        'id': id, // cache compat alias
        'name': name,
        if (type != null) 'type': type,
        if (description != null) 'description': description,
        if (startsAt != null) 'starts_at': startsAt,
        if (endsAt != null) 'ends_at': endsAt,
        'is_active': isActive,
      };
}

class SeasonDto {
  final int id;
  final String name;
  final String? description;
  final String? startsAt;
  final String? endsAt;
  final bool isActive;
  final List<SeasonEventDto> events;
  final List<ChallengeDto>? seasonChallenges;

  const SeasonDto({
    required this.id,
    required this.name,
    this.description,
    this.startsAt,
    this.endsAt,
    required this.isActive,
    this.events = const [],
    this.seasonChallenges,
  });

  factory SeasonDto.fromJson(Map<String, dynamic> json) {
    final id = _jsonInt(json['season_id'] ?? json['id']);
    return SeasonDto(
      id: id,
      name: json['name'] as String? ?? 'Season $id',
      description: json['description'] as String?,
      startsAt: json['starts_at'] as String?,
      endsAt: json['ends_at'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      events: (json['events'] as List?)
              ?.map((e) => SeasonEventDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      seasonChallenges: (json['season_challenges'] as List?)
          ?.map((e) => ChallengeDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'season_id': id,
        'id': id, // cache compat alias
        'name': name,
        if (description != null) 'description': description,
        if (startsAt != null) 'starts_at': startsAt,
        if (endsAt != null) 'ends_at': endsAt,
        'is_active': isActive,
        'events': events.map((e) => e.toJson()).toList(),
        if (seasonChallenges != null)
          'season_challenges':
              seasonChallenges!.map((c) => c.toJson()).toList(),
      };
}

class LeaderboardEntry {
  final int rank;
  final int participantId;
  final String? displayName;
  final int totalPoints;
  final int offchainPoints;
  final int totalProducedBlocks;
  final int vrfTotalWonSlots;
  final double successRate;
  final int eventsParticipated;

  const LeaderboardEntry({
    required this.rank,
    required this.participantId,
    this.displayName,
    required this.totalPoints,
    required this.offchainPoints,
    required this.totalProducedBlocks,
    required this.vrfTotalWonSlots,
    required this.successRate,
    required this.eventsParticipated,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: _jsonInt(json['rank']),
      participantId: _jsonInt(json['participant_id']),
      displayName: json['display_name'] as String?,
      totalPoints: _jsonInt(json['total_points']),
      offchainPoints: _jsonInt(json['offchain_points']),
      totalProducedBlocks: _jsonIntN(json['total_produced_blocks']) ?? 0,
      vrfTotalWonSlots: _jsonIntN(json['vrf_total_won_slots']) ?? 0,
      successRate: _jsonDoubleN(json['success_rate']) ?? 0.0,
      eventsParticipated: _jsonIntN(
              json['events_participated'] ?? json['phases_participated']) ??
          0,
    );
  }

  Map<String, dynamic> toJson() => {
        'rank': rank,
        'participant_id': participantId,
        if (displayName != null) 'display_name': displayName,
        'total_points': totalPoints,
        'offchain_points': offchainPoints,
        'total_produced_blocks': totalProducedBlocks,
        'vrf_total_won_slots': vrfTotalWonSlots,
        'success_rate': successRate,
        'events_participated': eventsParticipated,
      };
}

class PaginationInfo {
  final int page;
  final int perPage;
  final int total;
  final int totalPages;

  const PaginationInfo({
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: _jsonInt(json['page']),
      perPage: _jsonInt(json['per_page']),
      total: _jsonInt(json['total']),
      totalPages: _jsonInt(json['total_pages']),
    );
  }

  Map<String, dynamic> toJson() => {
        'page': page,
        'per_page': perPage,
        'total': total,
        'total_pages': totalPages,
      };
}

class LeaderboardResult {
  final LeaderboardSeason season;
  final List<LeaderboardEvent> events;
  final List<LeaderboardEntry> entries;
  final PaginationInfo pagination;

  const LeaderboardResult({
    required this.season,
    required this.events,
    required this.entries,
    required this.pagination,
  });

  factory LeaderboardResult.fromJson(Map<String, dynamic> json) {
    final entriesList =
        json['leaderboard'] as List? ?? json['entries'] as List? ?? [];
    return LeaderboardResult(
      season:
          LeaderboardSeason.fromJson(json['season'] as Map<String, dynamic>),
      events: (json['events'] as List)
          .map((e) => LeaderboardEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      entries: entriesList
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination:
          PaginationInfo.fromJson(json['pagination'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'season': season.toJson(),
        'events': events.map((e) => e.toJson()).toList(),
        'leaderboard': entries.map((e) => e.toJson()).toList(),
        'pagination': pagination.toJson(),
      };
}

// ---------------------------------------------------------------------------
// Breakdown
// ---------------------------------------------------------------------------

class BreakdownActivity {
  /// Activity ID. Regular activities have numeric IDs; extra-point activities
  /// use string IDs like `"extra-point-123"`.
  final String id;
  final String activityType;
  final int points;
  final String? description;
  final String? activityAt;
  final int? challengeId;
  final String? activitySubCategory;

  const BreakdownActivity({
    required this.id,
    required this.activityType,
    required this.points,
    this.description,
    this.activityAt,
    this.challengeId,
    this.activitySubCategory,
  });

  factory BreakdownActivity.fromJson(Map<String, dynamic> json) {
    return BreakdownActivity(
      id: (json['activity_id'] ?? json['id'] ?? '').toString(),
      activityType: json['activity_type'] as String? ?? '',
      points: _jsonInt(json['points']),
      description: json['description'] as String?,
      activityAt: json['activity_at'] as String?,
      challengeId: _jsonIntN(json['challenge_id']),
      activitySubCategory: json['activity_sub_category'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'activity_id': id,
        'id': id, // cache compat alias
        'activity_type': activityType,
        'points': points,
        if (description != null) 'description': description,
        if (activityAt != null) 'activity_at': activityAt,
        if (challengeId != null) 'challenge_id': challengeId,
        if (activitySubCategory != null)
          'activity_sub_category': activitySubCategory,
      };
}

class EventBreakdown {
  final int eventId;
  final String eventName;
  final int totalPoints;
  final int offchainPoints;
  final int? rank;
  final int? firstBlockPoints;
  final int? top3Points;
  final int? success50PercentPoints;
  final int? producedBlocks;
  final int? vrfWonSlots;
  final double? successRate;
  final List<BreakdownActivity> activities;

  /// Sum of block-production bonus rewards (first block, top-3, >50% success).
  int get totalBonusPoints =>
      (firstBlockPoints ?? 0) +
      (top3Points ?? 0) +
      (success50PercentPoints ?? 0);

  const EventBreakdown({
    required this.eventId,
    required this.eventName,
    required this.totalPoints,
    required this.offchainPoints,
    this.rank,
    this.firstBlockPoints,
    this.top3Points,
    this.success50PercentPoints,
    this.producedBlocks,
    this.vrfWonSlots,
    this.successRate,
    this.activities = const [],
  });

  factory EventBreakdown.fromJson(Map<String, dynamic> json) {
    final eventObj = json['event'] as Map<String, dynamic>?;
    return EventBreakdown(
      eventId: _jsonInt(eventObj?['id'] ?? json['event_id']),
      eventName: (eventObj?['name'] ?? json['event_name']) as String? ?? '',
      totalPoints: _jsonInt(json['total_points']),
      offchainPoints: _jsonInt(json['offchain_points']),
      rank: _jsonIntN(json['rank']),
      firstBlockPoints: _jsonIntN(json['first_block_points']),
      top3Points: _jsonIntN(json['top_3_points'] ?? json['top3_points']),
      success50PercentPoints: _jsonIntN(json['success_50_percent_points']),
      producedBlocks: _jsonIntN(json['produced_blocks']),
      vrfWonSlots: _jsonIntN(json['vrf_won_slots']),
      successRate: _jsonDoubleN(json['success_rate']),
      activities: (json['activities'] as List?)
              ?.map(
                  (e) => BreakdownActivity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'event': {'id': eventId, 'name': eventName},
        'event_id': eventId, // cache compat alias
        'event_name': eventName, // cache compat alias
        'total_points': totalPoints,
        'offchain_points': offchainPoints,
        if (rank != null) 'rank': rank,
        if (firstBlockPoints != null) 'first_block_points': firstBlockPoints,
        if (top3Points != null) 'top_3_points': top3Points,
        if (success50PercentPoints != null)
          'success_50_percent_points': success50PercentPoints,
        if (producedBlocks != null) 'produced_blocks': producedBlocks,
        if (vrfWonSlots != null) 'vrf_won_slots': vrfWonSlots,
        if (successRate != null) 'success_rate': successRate,
        'activities': activities.map((a) => a.toJson()).toList(),
      };
}

class SeasonBreakdown {
  final int seasonId;
  final String seasonName;
  final int totalPoints;
  final int offchainPoints;
  final List<EventBreakdown> events;

  const SeasonBreakdown({
    required this.seasonId,
    required this.seasonName,
    required this.totalPoints,
    required this.offchainPoints,
    this.events = const [],
  });

  factory SeasonBreakdown.fromJson(Map<String, dynamic> json) {
    final seasonObj = json['season'] as Map<String, dynamic>?;
    return SeasonBreakdown(
      seasonId: _jsonInt(seasonObj?['id'] ?? json['season_id']),
      seasonName: (seasonObj?['name'] ?? json['season_name']) as String? ?? '',
      totalPoints: _jsonInt(json['total_points']),
      offchainPoints: _jsonInt(json['offchain_points']),
      events: (json['events'] as List?)
              ?.map((e) => EventBreakdown.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'season': {'id': seasonId, 'name': seasonName},
        'season_id': seasonId, // cache compat alias
        'season_name': seasonName, // cache compat alias
        'total_points': totalPoints,
        'offchain_points': offchainPoints,
        'events': events.map((e) => e.toJson()).toList(),
      };
}

class BreakdownResult {
  final String scope;
  final String displayName;
  final int totalPoints;
  final int offchainPoints;
  final EventBreakdown? eventBreakdown;
  final SeasonBreakdown? seasonBreakdown;

  const BreakdownResult({
    required this.scope,
    required this.displayName,
    required this.totalPoints,
    required this.offchainPoints,
    this.eventBreakdown,
    this.seasonBreakdown,
  });

  factory BreakdownResult.fromJson(Map<String, dynamic> json) {
    final scope = json['scope'] as String? ?? 'event';
    return BreakdownResult(
      scope: scope,
      displayName: json['display_name'] as String? ?? '',
      totalPoints: _jsonInt(json['total_points']),
      offchainPoints: _jsonInt(json['offchain_points']),
      eventBreakdown: scope == 'event' ? EventBreakdown.fromJson(json) : null,
      seasonBreakdown:
          scope == 'season' ? SeasonBreakdown.fromJson(json) : null,
    );
  }

  /// Serialises back to the flat JSON shape that [fromJson] expects.
  /// Event/season breakdown fields are merged into the top-level map.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'scope': scope,
      'display_name': displayName,
      'total_points': totalPoints,
      'offchain_points': offchainPoints,
    };
    if (eventBreakdown != null) json.addAll(eventBreakdown!.toJson());
    if (seasonBreakdown != null) json.addAll(seasonBreakdown!.toJson());
    return json;
  }
}

// ---------------------------------------------------------------------------
// Event Points (distribution / histogram)
// ---------------------------------------------------------------------------

class ParticipantPoints {
  final int participantId;
  final int totalPoints;

  const ParticipantPoints({
    required this.participantId,
    required this.totalPoints,
  });

  factory ParticipantPoints.fromJson(Map<String, dynamic> json) {
    return ParticipantPoints(
      participantId: _jsonInt(json['participant_id']),
      totalPoints: _jsonInt(json['total_points']),
    );
  }

  Map<String, dynamic> toJson() => {
        'participant_id': participantId,
        'total_points': totalPoints,
      };
}

class EventPointsResult {
  final int eventId;
  final String eventName;
  final int eventTotalPoints;
  final int participantTotalPoints;
  final List<ParticipantPoints> totalPointsPerUser;
  final int totalParticipants;

  const EventPointsResult({
    required this.eventId,
    required this.eventName,
    required this.eventTotalPoints,
    required this.participantTotalPoints,
    required this.totalPointsPerUser,
    required this.totalParticipants,
  });

  factory EventPointsResult.fromJson(Map<String, dynamic> json) {
    return EventPointsResult(
      eventId: _jsonInt(json['event_id']),
      eventName: json['event_name'] as String? ?? '',
      eventTotalPoints: _jsonInt(json['event_total_points']),
      participantTotalPoints: _jsonInt(json['participant_total_points']),
      totalPointsPerUser: (json['total_points_per_user'] as List?)
              ?.map(
                  (e) => ParticipantPoints.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      totalParticipants: _jsonInt(json['total_participants']),
    );
  }

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'event_name': eventName,
        'event_total_points': eventTotalPoints,
        'participant_total_points': participantTotalPoints,
        'total_points_per_user':
            totalPointsPerUser.map((e) => e.toJson()).toList(),
        'total_participants': totalParticipants,
      };
}

// ---------------------------------------------------------------------------
// Shared context
// ---------------------------------------------------------------------------

class SeasonEventContext {
  final int? seasonId;
  final String? seasonName;
  final int? eventId;
  final String? eventName;

  const SeasonEventContext({
    this.seasonId,
    this.seasonName,
    this.eventId,
    this.eventName,
  });

  SeasonEventContext copyWith({
    int? seasonId,
    String? seasonName,
    int? eventId,
    String? eventName,
  }) {
    return SeasonEventContext(
      seasonId: seasonId ?? this.seasonId,
      seasonName: seasonName ?? this.seasonName,
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
    );
  }
}
