// DTOs and shared types for the Leaderboard v2 Mobile API.
//
// Base URL: https://leaderboard.usernodelabs.org/api/v2/mobile/

// ---------------------------------------------------------------------------
// Safe JSON number helpers
// ---------------------------------------------------------------------------

/// Coerces a JSON value that may be [int], [double], or numeric [String] → [int].
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

class PhaseInfo {
  final int id;
  final String name;
  final String? endsAt;

  const PhaseInfo({required this.id, required this.name, this.endsAt});

  factory PhaseInfo.fromJson(Map<String, dynamic> json) {
    return PhaseInfo(
      id: _jsonInt(json['id']),
      name: json['name'] as String,
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
  final int seasonId;
  final String seasonName;
  final PhaseInfo? phase;

  const RegistrationV2Result({
    required this.participantId,
    required this.identityUid,
    required this.publicKey,
    required this.secretKey,
    required this.address,
    required this.tier,
    required this.seasonId,
    required this.seasonName,
    this.phase,
  });

  factory RegistrationV2Result.fromJson(Map<String, dynamic> json) {
    final phase = json['phase'];
    return RegistrationV2Result(
      participantId: _jsonInt(json['participant_id']),
      identityUid: json['identity_uid'] as String,
      publicKey: json['public_key'] as String,
      secretKey: json['secret_key'] as String,
      address: json['address'] as String,
      tier: json['tier'] as String,
      seasonId: _jsonInt(json['season_id']),
      seasonName: json['season_name'] as String,
      phase: phase is Map<String, dynamic> ? PhaseInfo.fromJson(phase) : null,
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
  final int? phasesParticipated;
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
    this.phasesParticipated,
    this.totalProducedBlocks,
  });

  factory RankingResult.fromJson(Map<String, dynamic> json) {
    return RankingResult(
      scope: json['scope'] as String,
      rank: _jsonInt(json['rank']),
      totalPoints: _jsonInt(json['total_points']),
      offchainPoints: _jsonInt(json['offchain_points']),
      totalParticipants: _jsonInt(json['total_participants']),
      eventId: _jsonIntN(json['event_id']),
      eventName: json['event_name'] as String?,
      seasonId: _jsonIntN(json['season_id']),
      seasonName: json['season_name'] as String?,
      phasesParticipated: _jsonIntN(json['phases_participated']),
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
        if (phasesParticipated != null)
          'phases_participated': phasesParticipated,
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
  final String category;
  final String goal;
  final String task;
  final String reward;
  final String? description;
  final String? requirements;
  final String? rewardLogic;
  final String? ctaLabel;
  final String? ctaLink;
  final String? scheduleStart;
  final String? scheduleEnd;
  final bool enabled;
  final bool completed;

  const ChallengeDto({
    required this.id,
    this.eventId,
    this.eventName,
    required this.category,
    required this.goal,
    required this.task,
    required this.reward,
    this.description,
    this.requirements,
    this.rewardLogic,
    this.ctaLabel,
    this.ctaLink,
    this.scheduleStart,
    this.scheduleEnd,
    required this.enabled,
    required this.completed,
  });

  factory ChallengeDto.fromJson(Map<String, dynamic> json) {
    return ChallengeDto(
      id: _jsonInt(json['id']),
      eventId: _jsonIntN(json['event_id']),
      eventName: json['event_name'] as String?,
      category: json['category'] as String,
      goal: json['goal'] as String,
      task: json['task'] as String,
      reward: json['reward'].toString(),
      description: json['description'] as String?,
      requirements: json['requirements'] as String?,
      rewardLogic: json['reward_logic'] as String?,
      ctaLabel: json['cta_label'] as String?,
      ctaLink: json['cta_link'] as String?,
      scheduleStart: json['schedule_start'] as String?,
      scheduleEnd: json['schedule_end'] as String?,
      enabled: json['enabled'] as bool,
      completed: json['completed'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (eventId != null) 'event_id': eventId,
        if (eventName != null) 'event_name': eventName,
        'category': category,
        'goal': goal,
        'task': task,
        'reward': reward,
        if (description != null) 'description': description,
        if (requirements != null) 'requirements': requirements,
        if (rewardLogic != null) 'reward_logic': rewardLogic,
        if (ctaLabel != null) 'cta_label': ctaLabel,
        if (ctaLink != null) 'cta_link': ctaLink,
        if (scheduleStart != null) 'schedule_start': scheduleStart,
        if (scheduleEnd != null) 'schedule_end': scheduleEnd,
        'enabled': enabled,
        'completed': completed,
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
      name: json['name'] as String,
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
  final String? startsAt;
  final String? endsAt;
  final bool isActive;

  const LeaderboardEvent({
    required this.id,
    required this.name,
    this.startsAt,
    this.endsAt,
    required this.isActive,
  });

  factory LeaderboardEvent.fromJson(Map<String, dynamic> json) {
    return LeaderboardEvent(
      id: _jsonInt(json['id']),
      name: json['name'] as String,
      startsAt: json['starts_at'] as String?,
      endsAt: json['ends_at'] as String?,
      isActive: json['is_active'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
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
  final String? description;
  final String? startsAt;
  final String? endsAt;
  final bool isActive;

  const SeasonEventDto({
    required this.id,
    required this.name,
    this.description,
    this.startsAt,
    this.endsAt,
    required this.isActive,
  });

  factory SeasonEventDto.fromJson(Map<String, dynamic> json) {
    return SeasonEventDto(
      id: _jsonInt(json['id']),
      name: json['name'] as String,
      description: json['description'] as String?,
      startsAt: json['starts_at'] as String?,
      endsAt: json['ends_at'] as String?,
      isActive: json['is_active'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
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

  const SeasonDto({
    required this.id,
    required this.name,
    this.description,
    this.startsAt,
    this.endsAt,
    required this.isActive,
    this.events = const [],
  });

  factory SeasonDto.fromJson(Map<String, dynamic> json) {
    return SeasonDto(
      id: _jsonInt(json['id']),
      name: json['name'] as String,
      description: json['description'] as String?,
      startsAt: json['starts_at'] as String?,
      endsAt: json['ends_at'] as String?,
      isActive: json['is_active'] as bool,
      events: (json['events'] as List?)
              ?.map((e) => SeasonEventDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        if (startsAt != null) 'starts_at': startsAt,
        if (endsAt != null) 'ends_at': endsAt,
        'is_active': isActive,
        'events': events.map((e) => e.toJson()).toList(),
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
  final int phasesParticipated;

  const LeaderboardEntry({
    required this.rank,
    required this.participantId,
    this.displayName,
    required this.totalPoints,
    required this.offchainPoints,
    required this.totalProducedBlocks,
    required this.vrfTotalWonSlots,
    required this.successRate,
    required this.phasesParticipated,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: _jsonInt(json['rank']),
      participantId: _jsonInt(json['participant_id']),
      displayName: json['display_name'] as String?,
      totalPoints: _jsonInt(json['total_points']),
      offchainPoints: _jsonInt(json['offchain_points']),
      totalProducedBlocks: _jsonInt(json['total_produced_blocks']),
      vrfTotalWonSlots: _jsonInt(json['vrf_total_won_slots']),
      successRate: _jsonDouble(json['success_rate']),
      phasesParticipated: _jsonInt(json['phases_participated']),
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
        'phases_participated': phasesParticipated,
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
    return LeaderboardResult(
      season:
          LeaderboardSeason.fromJson(json['season'] as Map<String, dynamic>),
      events: (json['events'] as List)
          .map((e) => LeaderboardEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      entries: (json['entries'] as List)
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination:
          PaginationInfo.fromJson(json['pagination'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'season': season.toJson(),
        'events': events.map((e) => e.toJson()).toList(),
        'entries': entries.map((e) => e.toJson()).toList(),
        'pagination': pagination.toJson(),
      };
}

// ---------------------------------------------------------------------------
// Breakdown
// ---------------------------------------------------------------------------

class BreakdownActivity {
  final int id;
  final String activityType;
  final int points;
  final String? description;
  final String? activityAt;

  const BreakdownActivity({
    required this.id,
    required this.activityType,
    required this.points,
    this.description,
    this.activityAt,
  });

  factory BreakdownActivity.fromJson(Map<String, dynamic> json) {
    return BreakdownActivity(
      id: _jsonInt(json['id']),
      activityType: json['activity_type'] as String,
      points: _jsonInt(json['points']),
      description: json['description'] as String?,
      activityAt: json['activity_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'activity_type': activityType,
        'points': points,
        if (description != null) 'description': description,
        if (activityAt != null) 'activity_at': activityAt,
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
    return EventBreakdown(
      eventId: _jsonInt(json['event_id']),
      eventName: json['event_name'] as String,
      totalPoints: _jsonInt(json['total_points']),
      offchainPoints: _jsonInt(json['offchain_points']),
      rank: _jsonIntN(json['rank']),
      firstBlockPoints: _jsonIntN(json['first_block_points']),
      top3Points: _jsonIntN(json['top3_points']),
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
        'event_id': eventId,
        'event_name': eventName,
        'total_points': totalPoints,
        'offchain_points': offchainPoints,
        if (rank != null) 'rank': rank,
        if (firstBlockPoints != null) 'first_block_points': firstBlockPoints,
        if (top3Points != null) 'top3_points': top3Points,
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
    return SeasonBreakdown(
      seasonId: _jsonInt(json['season_id']),
      seasonName: json['season_name'] as String,
      totalPoints: _jsonInt(json['total_points']),
      offchainPoints: _jsonInt(json['offchain_points']),
      events: (json['events'] as List?)
              ?.map((e) => EventBreakdown.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'season_id': seasonId,
        'season_name': seasonName,
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
    final scope = json['scope'] as String;
    return BreakdownResult(
      scope: scope,
      displayName: json['display_name'] as String,
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
