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

num _jsonNum(dynamic v) => v is num ? v : num.parse(v as String);

/// Nullable variant.
num? _jsonNumN(dynamic v) => v == null ? null : _jsonNum(v);

/// Parses backend point economics into the app's integer display model.
///
/// The leaderboard may serialize aggregate challenge points as decimals
/// (for example success-rate based block production points). UI surfaces still
/// present whole points, so round at the data boundary instead of failing an
/// entire screen on a fractional aggregate.
int _jsonPointInt(dynamic v) {
  final value = _jsonNum(v);
  if (value.isNaN || value.isInfinite) {
    throw FormatException('Expected a finite JSON point value.', v);
  }
  return value.round();
}

/// Nullable variant.
int? _jsonPointIntN(dynamic v) => v == null ? null : _jsonPointInt(v);

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
// Wallet provisioning (v4 replacement for the retired v2 registration)
// ---------------------------------------------------------------------------

/// The platform-allocated on-chain account returned by
/// `POST /wallet/provision`. Idempotent server-side: reinstalls and
/// migrated users get the same account back. [secretKey] is the credential
/// the device imports to run its node — the same exposure the retired v2
/// registration response had.
class WalletProvisionResult {
  const WalletProvisionResult({
    required this.address,
    required this.publicKey,
    required this.secretKey,
    this.seasonId,
    this.seasonEventId,
    this.newlyAllocated = false,
  });

  final String address;
  final String publicKey;
  final String secretKey;
  final int? seasonId;
  final int? seasonEventId;
  final bool newlyAllocated;

  factory WalletProvisionResult.fromJson(Map<String, dynamic> json) {
    return WalletProvisionResult(
      address: json['address'] as String,
      publicKey: json['public_key'] as String,
      secretKey: json['secret_key'] as String,
      seasonId: _jsonIntN(json['season_id']),
      seasonEventId: _jsonIntN(json['season_event_id']),
      newlyAllocated: json['newly_allocated'] == true,
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
  final int totalTokens;
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
  // Terms gating. The backend forces [totalTokens] to 0 while [termsAccepted]
  // is false; [rank] and [totalPoints] are never affected.
  final bool termsAccepted;
  final String? termsVersionRequired;
  final String? termsLink;

  const RankingResult({
    required this.scope,
    required this.rank,
    required this.totalPoints,
    this.totalTokens = 0,
    required this.offchainPoints,
    required this.totalParticipants,
    this.eventId,
    this.eventName,
    this.seasonId,
    this.seasonName,
    this.eventsParticipated,
    this.totalProducedBlocks,
    this.termsAccepted = true,
    this.termsVersionRequired,
    this.termsLink,
  });

  factory RankingResult.fromJson(Map<String, dynamic> json) {
    return RankingResult(
      scope: json['scope'] as String? ?? 'event',
      rank: _jsonIntN(json['rank']) ?? 0,
      totalPoints: _jsonIntN(json['total_points']) ?? 0,
      totalTokens: _jsonIntN(json['total_tokens']) ?? 0,
      // SV v4 emits `extra_points`; topochain v2/v3 called the same value
      // `offchain_points`. Same fallback pattern for `season_event_id` vs
      // the legacy `event_id` throughout this file.
      offchainPoints:
          _jsonIntN(json['extra_points'] ?? json['offchain_points']) ?? 0,
      totalParticipants: _jsonIntN(json['total_participants']) ?? 0,
      eventId: _jsonIntN(json['season_event_id'] ?? json['event_id']),
      eventName: json['event_name'] as String?,
      seasonId: _jsonIntN(json['season_id']),
      seasonName: json['season_name'] as String?,
      eventsParticipated:
          _jsonIntN(json['events_participated'] ?? json['phases_participated']),
      totalProducedBlocks: _jsonIntN(json['total_produced_blocks']),
      // Absent key means a backend that predates terms gating, which is also a
      // backend that never zeroes tokens — gating there would misreport a real
      // balance as withheld.
      termsAccepted: json['terms_accepted'] as bool? ?? true,
      termsVersionRequired: _nonEmptyString(json['terms_version_required']),
      termsLink: _sanitizeCtaLink(CtaType.url, json['terms_link']),
    );
  }

  Map<String, dynamic> toJson() => {
        'scope': scope,
        'rank': rank,
        'total_points': totalPoints,
        'total_tokens': totalTokens,
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
        // Emitted unconditionally: omitting a false/null terms field would let
        // it round-trip back to the permissive default and un-gate the UI.
        'terms_accepted': termsAccepted,
        'terms_version_required': termsVersionRequired,
        'terms_link': termsLink,
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
  final int displayOrder;
  final bool featured;
  final int? featuredOrder;
  final String? subCategory;

  /// Optional structured CTA/verification source (backend `source{}` shape:
  /// `type`/`label`/`url`/`resolver`).
  final ChallengeSource? source;

  /// Optional metric descriptor (board `metric{}` shape: `kind`/`label`/
  /// `target`). Drives the atomic card's rail treatment and bounded fill when
  /// present.
  final ChallengeMetric? metric;

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
    this.displayOrder = 0,
    this.featured = false,
    this.featuredOrder,
    this.subCategory,
    this.source,
    this.metric,
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
      // v4's compact per-season/per-event challenge item (GET /seasons'
      // season_challenges and events[].challenges) keys the id as
      // challenge_id; the full /challenges shape keeps id.
      id: _jsonInt(json['id'] ?? json['challenge_id']),
      eventId: _jsonIntN(json['season_event_id'] ?? json['event_id']),
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
      displayOrder: _jsonIntN(json['display_order']) ?? 0,
      featured: json['featured'] as bool? ?? false,
      featuredOrder: _jsonIntN(json['featured_order']),
      // v4 renames a challenge's `sub_category` to `kind` (SPEC §8.2).
      subCategory: (json['kind'] ?? json['sub_category']) as String?,
      source: json['source'] is Map<String, dynamic>
          ? ChallengeSource.fromJson(json['source'] as Map<String, dynamic>)
          : null,
      metric: json['metric'] is Map<String, dynamic>
          ? ChallengeMetric.fromJson(json['metric'] as Map<String, dynamic>)
          : null,
      activities: (json['activities'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(BreakdownActivity.fromJson)
              .toList() ??
          const [],
      activitiesTotal: _jsonPointIntN(json['activities_total']) ?? 0,
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
        'display_order': displayOrder,
        'featured': featured,
        if (featuredOrder != null) 'featured_order': featuredOrder,
        if (subCategory != null) 'sub_category': subCategory,
        if (source != null) 'source': source!.toJson(),
        if (metric != null) 'metric': metric!.toJson(),
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
    final id =
        _jsonInt(json['season_event_id'] ?? json['event_id'] ?? json['id']);
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
      participantId: _jsonInt(json['user_id'] ?? json['participant_id']),
      displayName: json['display_name'] as String?,
      totalPoints: _jsonInt(json['total_points']),
      offchainPoints: _jsonInt(json['extra_points'] ?? json['offchain_points']),
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
      points: _jsonPointInt(json['points']),
      description: json['description'] as String?,
      activityAt: json['activity_at'] as String?,
      challengeId: _jsonIntN(json['challenge_id']),
      // v4 renames `activity_sub_category` to `activity_kind` (SPEC §8.2).
      activitySubCategory:
          (json['activity_kind'] ?? json['activity_sub_category']) as String?,
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
  final List<ChallengeProgress> challengeProgress;
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
    this.challengeProgress = const [],
    this.activities = const [],
  });

  factory EventBreakdown.fromJson(Map<String, dynamic> json) {
    final eventObj = json['event'] as Map<String, dynamic>?;
    return EventBreakdown(
      eventId: _jsonInt(
          eventObj?['id'] ?? json['season_event_id'] ?? json['event_id']),
      eventName: (eventObj?['name'] ?? json['event_name']) as String? ?? '',
      totalPoints: _jsonPointInt(json['total_points']),
      offchainPoints:
          _jsonPointInt(json['extra_points'] ?? json['offchain_points']),
      rank: _jsonIntN(json['rank']),
      firstBlockPoints: _jsonPointIntN(json['first_block_points']),
      top3Points: _jsonPointIntN(json['top_3_points'] ?? json['top3_points']),
      success50PercentPoints: _jsonPointIntN(json['success_50_percent_points']),
      producedBlocks: _jsonIntN(json['produced_blocks']),
      vrfWonSlots: _jsonIntN(json['vrf_won_slots']),
      successRate: _jsonDoubleN(json['success_rate']),
      challengeProgress: _parseChallengeProgressList(
        json['challenge_progress'],
      ),
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
        if (challengeProgress.isNotEmpty)
          'challenge_progress':
              challengeProgress.map((p) => p.toJson()).toList(),
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
    final events = (json['events'] as List?)
            ?.map((e) => EventBreakdown.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <EventBreakdown>[];
    return SeasonBreakdown(
      // v4 global entries are {id, name, events}; the v4 season-scope
      // response carries no season identity at all (the caller supplied
      // the season_id) — fall back to 0 rather than failing the parse.
      seasonId:
          _jsonIntN(seasonObj?['id'] ?? json['season_id'] ?? json['id']) ?? 0,
      seasonName: (seasonObj?['name'] ?? json['season_name'] ?? json['name'])
              as String? ??
          '',
      // v4 has no per-season totals — derive them from the events.
      totalPoints: _jsonPointIntN(json['total_points']) ??
          events.fold<int>(0, (a, e) => a + e.totalPoints),
      offchainPoints:
          _jsonPointIntN(json['extra_points'] ?? json['offchain_points']) ??
              events.fold<int>(0, (a, e) => a + e.offchainPoints),
      events: events,
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
  final List<SeasonBreakdown> globalSeasons;

  /// Legacy top-level per-challenge progress.
  ///
  /// The current backend owns progress at the event level. Use
  /// [progressForChallenge] or [allScopedChallengeProgress] so duplicate
  /// challenge IDs across events cannot silently collide.
  @Deprecated('Use progressForChallenge or allScopedChallengeProgress.')
  List<ChallengeProgress>? get challengeProgress => _challengeProgress;

  final List<ChallengeProgress>? _challengeProgress;

  const BreakdownResult({
    required this.scope,
    required this.displayName,
    required this.totalPoints,
    required this.offchainPoints,
    this.eventBreakdown,
    this.seasonBreakdown,
    this.globalSeasons = const [],
    List<ChallengeProgress>? challengeProgress,
  }) : _challengeProgress = challengeProgress;

  factory BreakdownResult.fromJson(Map<String, dynamic> json) {
    final scope = json['scope'] as String? ?? 'event';
    final progress = _parseChallengeProgressList(json['challenge_progress']);
    final eventBreakdown =
        scope == 'event' ? EventBreakdown.fromJson(json) : null;
    final seasonBreakdown =
        scope == 'season' ? SeasonBreakdown.fromJson(json) : null;
    final globalSeasons = scope == 'global'
        ? (json['seasons'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(SeasonBreakdown.fromJson)
                .toList() ??
            const <SeasonBreakdown>[]
        : const <SeasonBreakdown>[];
    // v4 season/global responses carry only {display_name, scope,
    // events|seasons} — no top-level totals (only event scope spreads them
    // in). Derive from the nested breakdowns instead of failing the parse.
    return BreakdownResult(
      scope: scope,
      displayName: json['display_name'] as String? ?? '',
      totalPoints: _jsonPointIntN(json['total_points']) ??
          seasonBreakdown?.totalPoints ??
          globalSeasons.fold<int>(0, (a, s) => a + s.totalPoints),
      offchainPoints:
          _jsonPointIntN(json['extra_points'] ?? json['offchain_points']) ??
              seasonBreakdown?.offchainPoints ??
              globalSeasons.fold<int>(0, (a, s) => a + s.offchainPoints),
      eventBreakdown: eventBreakdown,
      seasonBreakdown: seasonBreakdown,
      globalSeasons: globalSeasons,
      challengeProgress: progress.isEmpty ? null : progress,
    );
  }

  List<ScopedChallengeProgress> get allScopedChallengeProgress {
    final scoped = <ScopedChallengeProgress>[];
    final eventProgress = eventBreakdown?.challengeProgress ?? const [];
    for (final progress in eventProgress) {
      scoped.add((eventId: eventBreakdown!.eventId, progress: progress));
    }
    if (eventProgress.isEmpty) {
      for (final progress in _challengeProgress ?? const []) {
        scoped.add((eventId: eventBreakdown?.eventId, progress: progress));
      }
    }
    for (final event in seasonBreakdown?.events ?? const <EventBreakdown>[]) {
      for (final progress in event.challengeProgress) {
        scoped.add((eventId: event.eventId, progress: progress));
      }
    }
    for (final season in globalSeasons) {
      for (final event in season.events) {
        for (final progress in event.challengeProgress) {
          scoped.add((eventId: event.eventId, progress: progress));
        }
      }
    }
    return List.unmodifiable(scoped);
  }

  ChallengeProgress? progressForChallenge(ChallengeDto dto) {
    final scoped = allScopedChallengeProgress;
    if (dto.eventId != null) {
      for (final item in scoped) {
        if (item.eventId == dto.eventId &&
            item.progress.challengeId == dto.id) {
          return item.progress;
        }
      }
      return null;
    }

    final matches = scoped
        .where((item) => item.progress.challengeId == dto.id)
        .map((item) => item.progress)
        .toList();
    return matches.length == 1 ? matches.single : null;
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
    if (globalSeasons.isNotEmpty) {
      json['seasons'] = globalSeasons.map((s) => s.toJson()).toList();
    }
    if (_challengeProgress != null) {
      json['challenge_progress'] =
          _challengeProgress.map((p) => p.toJson()).toList();
    }
    return json;
  }
}

typedef ScopedChallengeProgress = ({
  int? eventId,
  ChallengeProgress progress,
});

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
      participantId: _jsonInt(json['user_id'] ?? json['participant_id']),
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
      eventId: _jsonInt(json['season_event_id'] ?? json['event_id']),
      eventName: json['event_name'] as String? ?? '',
      eventTotalPoints: _jsonInt(json['event_total_points']),
      participantTotalPoints: _jsonInt(
          json['user_total_points'] ?? json['participant_total_points']),
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

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SeasonEventContext &&
            other.seasonId == seasonId &&
            other.seasonName == seasonName &&
            other.eventId == eventId &&
            other.eventName == eventName;
  }

  @override
  int get hashCode => Object.hash(seasonId, seasonName, eventId, eventName);
}

// ---------------------------------------------------------------------------
// Fair Rewards challenge shape (board "DEFINITIONS" / "APIs?" frames)
//
// These types model the live challenge contract. Fields are nullable where the
// backend can omit optional metadata, and unknown metric kinds remain preserved
// for safe state-only rendering.
// ---------------------------------------------------------------------------

/// How a challenge's connected data source resolves participant results
/// (board "Sources" column).
class ChallengeSource {
  /// `legacy` | `manual` | `dapp` | `chain` | `external_source` | ...
  final String type;
  final String? label;
  final String? url;

  /// `agent` | `human` | `code`.
  final String? resolver;

  const ChallengeSource({
    required this.type,
    this.label,
    this.url,
    this.resolver,
  });

  factory ChallengeSource.fromJson(Map<String, dynamic> json) {
    return ChallengeSource(
      type: json['type'] as String? ?? 'legacy',
      label: json['label'] as String?,
      url: json['url'] as String?,
      resolver: json['resolver'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        if (label != null) 'label': label,
        if (url != null) 'url': url,
        if (resolver != null) 'resolver': resolver,
      };
}

/// Metric kind for a challenge. Drives the atomic card's rail treatment and
/// whether a bounded progress fill exists.
enum ChallengeMetricKind { binary, count, percentage, rank, sum, unknown }

ChallengeMetricKind _parseMetricKind(dynamic raw) {
  return switch ((raw as String?)?.toLowerCase()) {
    'binary' => ChallengeMetricKind.binary,
    'count' => ChallengeMetricKind.count,
    'percentage' => ChallengeMetricKind.percentage,
    'rank' => ChallengeMetricKind.rank,
    'sum' => ChallengeMetricKind.sum,
    _ => ChallengeMetricKind.unknown,
  };
}

/// Metric descriptor for a challenge.
class ChallengeMetric {
  final ChallengeMetricKind kind;
  final String? rawKind;
  final String? label;

  /// Target value for bounded metrics (e.g. 5 for "2 / 5"). Null for unbounded
  /// or state-only metrics.
  final num? target;

  const ChallengeMetric({
    required this.kind,
    this.rawKind,
    this.label,
    this.target,
  });

  factory ChallengeMetric.fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind'] as String?;
    return ChallengeMetric(
      kind: _parseMetricKind(rawKind),
      rawKind: rawKind,
      label: json['label'] as String?,
      target: _jsonNumN(json['target']),
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': rawKind ?? kind.name,
        if (label != null) 'label': label,
        if (target != null) 'target': target,
      };
}

/// Participant reward state for a challenge (board "Reward State" column).
enum ChallengeProgressState {
  none,
  inProgress,
  pending,
  earned,
  missed,
  declined
}

ChallengeProgressState _parseProgressState(dynamic raw) {
  // Accepts both wire forms ("in progress", "in_progress") and enum names.
  final normalized =
      (raw as String?)?.toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  return switch (normalized) {
    'none' => ChallengeProgressState.none,
    'in_progress' || 'inprogress' => ChallengeProgressState.inProgress,
    'pending' => ChallengeProgressState.pending,
    'earned' => ChallengeProgressState.earned,
    'missed' => ChallengeProgressState.missed,
    'declined' => ChallengeProgressState.declined,
    _ => ChallengeProgressState.none,
  };
}

String _progressStateWire(ChallengeProgressState state) {
  return switch (state) {
    ChallengeProgressState.none => 'none',
    ChallengeProgressState.inProgress => 'in progress',
    ChallengeProgressState.pending => 'pending',
    ChallengeProgressState.earned => 'earned',
    ChallengeProgressState.missed => 'missed',
    ChallengeProgressState.declined => 'declined',
  };
}

/// Per-challenge participant progress (board `/me/breakdown`
/// `challenge_progress[]` shape).
class ChallengeProgress {
  final int challengeId;
  final ChallengeProgressState state;

  /// Current metric value (e.g. 2 for "2 / 5"). Null for state-only metrics.
  final num? current;

  /// Target metric value (e.g. 5 for "2 / 5"). Null for state-only metrics.
  final num? target;

  /// Points awaiting verification/finalization.
  final int pendingPoints;

  /// Points already assigned to the participant.
  final int earnedPoints;

  /// Short human-readable status (e.g. "Survey submitted and approved").
  final String? description;

  const ChallengeProgress({
    required this.challengeId,
    required this.state,
    this.current,
    this.target,
    this.pendingPoints = 0,
    this.earnedPoints = 0,
    this.description,
  });

  factory ChallengeProgress.fromJson(Map<String, dynamic> json) {
    return ChallengeProgress(
      challengeId: _jsonInt(json['challenge_id']),
      state: _parseProgressState(json['state']),
      current: _jsonNumN(json['current']),
      target: _jsonNumN(json['target']),
      pendingPoints: _jsonPointIntN(json['pending_points']) ?? 0,
      earnedPoints: _jsonPointIntN(json['earned_points']) ?? 0,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'challenge_id': challengeId,
        'state': _progressStateWire(state),
        if (current != null) 'current': current,
        if (target != null) 'target': target,
        'pending_points': pendingPoints,
        'earned_points': earnedPoints,
        if (description != null) 'description': description,
      };
}

List<ChallengeProgress> _parseChallengeProgressList(dynamic raw) {
  return (raw as List?)
          ?.whereType<Map<String, dynamic>>()
          .map(ChallengeProgress.fromJson)
          .toList() ??
      const [];
}

// ---------------------------------------------------------------------------
// Terms & conditions
// ---------------------------------------------------------------------------

/// A participant's response to a specific terms version.
///
/// Only present when `participant_id` was passed to `GET /terms/current`.
class TermsConsent {
  const TermsConsent({
    this.status,
    required this.accepted,
    this.respondedAt,
  });

  /// `null` when the participant has never responded to this version,
  /// otherwise `'accepted'` or `'refused'`.
  final String? status;

  final bool accepted;

  /// ISO-8601 timestamp, kept as a string like every other date in this file.
  final String? respondedAt;

  factory TermsConsent.fromJson(Map<String, dynamic> json) => TermsConsent(
        status: _nonEmptyString(json['status']),
        accepted: json['accepted'] as bool? ?? false,
        respondedAt: _nonEmptyString(json['responded_at']),
      );

  Map<String, dynamic> toJson() => {
        'status': status,
        'accepted': accepted,
        'responded_at': respondedAt,
      };
}

/// The currently published terms version, from `GET /terms/current`.
///
/// A 404 from that endpoint means nothing is published and is not an error —
/// the service maps it to null rather than surfacing it.
class CurrentTerms {
  const CurrentTerms({
    required this.id,
    required this.version,
    required this.title,
    this.termsLink,
    this.publishedAt,
    this.consent,
  });

  /// Send this back as `terms_version_id` when posting consent. Never hardcode.
  final int id;

  final String version;
  final String title;

  /// Hosted copy of the terms displayed inside the app WebView.
  final String? termsLink;

  final String? publishedAt;
  final TermsConsent? consent;

  factory CurrentTerms.fromJson(Map<String, dynamic> json) => CurrentTerms(
        id: _jsonInt(json['id']),
        version: json['version'] as String? ?? '',
        title: json['title'] as String? ?? '',
        termsLink: _sanitizeCtaLink(CtaType.url, json['terms_link']),
        publishedAt: _nonEmptyString(json['published_at']),
        consent: json['consent'] is Map<String, dynamic>
            ? TermsConsent.fromJson(json['consent'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'title': title,
        'terms_link': termsLink,
        'published_at': publishedAt,
        'consent': consent?.toJson(),
      };
}

/// Wire values for `POST /terms/consent`.
class TermsConsentStatus {
  static const accepted = 'accepted';
}
