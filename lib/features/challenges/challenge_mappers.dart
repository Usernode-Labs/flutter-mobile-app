import 'package:intl/intl.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';

/// Extracts breakdown activities based on the breakdown scope.
///
/// For event scope, returns the event's activities directly.
/// For season/global scope, flattens activities across all events.
/// Returns null when breakdown is null or scope is unrecognised.
List<BreakdownActivity>? extractActivities(BreakdownResult? breakdown) {
  if (breakdown == null) return null;
  if (breakdown.eventBreakdown != null) {
    return breakdown.eventBreakdown?.activities;
  }
  if (breakdown.seasonBreakdown != null) {
    return breakdown.seasonBreakdown!.events
        .expand((event) => event.activities)
        .toList();
  }
  if (breakdown.globalSeasons.isNotEmpty) {
    return breakdown.globalSeasons
        .expand((season) => season.events)
        .expand((event) => event.activities)
        .toList();
  }
  return null;
}

// ---------------------------------------------------------------------------
// Enrichment — participant-specific challenge data from breakdown
// ---------------------------------------------------------------------------

/// Wraps a [ChallengeDto] with an optional [BreakdownActivity] match from
/// the breakdown endpoint, providing participant-specific completion info.
class EnrichedChallenge {
  final ChallengeDto dto;
  final BreakdownActivity? activity;

  /// Extra points from manual adjustments for this challenge.
  final int extraPoints;

  const EnrichedChallenge({
    required this.dto,
    this.activity,
    this.extraPoints = 0,
  });

  /// Whether the participant completed this challenge (has a matching activity).
  bool get participantCompleted => activity != null;

  /// Actual points earned by the participant (including extra points),
  /// or null if not completed.
  ///
  /// Reflects only the single primary breakdown [activity]; use
  /// [displayEarnedPoints] for the user-facing total.
  int? get earnedPoints {
    final base = activity?.points;
    if (base == null && extraPoints == 0) return null;
    return (base ?? 0) + extraPoints;
  }

  /// User-facing earned total. Prefers the server's per-challenge
  /// [ChallengeDto.activitiesTotal] (sum of all activities) so cards and the
  /// detail page match the Points breakdown; falls back to [earnedPoints] when
  /// the list was fetched without `participant_id` (no embedded activities).
  int? get displayEarnedPoints =>
      dto.activitiesTotal > 0 ? dto.activitiesTotal : earnedPoints;
}

/// Cross-references challenges with breakdown activities.
///
/// Prefers matching by [BreakdownActivity.challengeId] → [ChallengeDto.id].
/// Falls back to [BreakdownActivity.description] → [ChallengeDto.goal] when
/// `challengeId` is null (older cached data).
///
/// When multiple activities share the same [challengeId] (e.g. regular epoch
/// activities plus extra-point activities for produce-blocks), the primary
/// (non-extra-point) activity is preferred.
///
/// When [activities] is null (breakdown unavailable), wraps all challenges
/// with `activity: null` for graceful v1-style fallback.
List<EnrichedChallenge> enrichChallenges(
  List<ChallengeDto> challenges,
  List<BreakdownActivity>? activities,
) {
  if (activities == null) {
    return challenges.map((dto) => EnrichedChallenge(dto: dto)).toList();
  }

  final byId = <int, List<BreakdownActivity>>{};
  final byDesc = <String, BreakdownActivity>{};
  for (final a in activities) {
    if (a.challengeId != null) {
      byId.putIfAbsent(a.challengeId!, () => []).add(a);
    } else if (a.description != null) {
      // Description fallback only for legacy activities without challengeId.
      // Activities WITH challengeId must match by ID only — otherwise
      // same-named challenges across events get false matches.
      byDesc[a.description!] = a;
    }
  }

  return challenges
      .map((dto) => EnrichedChallenge(
            dto: dto,
            // TODO(challenges): Remove description fallback once all breakdown
            // activities include challengeId. The assumption that
            // description == goal is a reliable match is fragile.
            activity: _primaryActivity(byId[dto.id]) ?? byDesc[dto.goal],
            extraPoints: _sumExtraPoints(byId[dto.id]),
          ))
      .toList();
}

/// Picks the primary activity from a list sharing the same [challengeId].
///
/// Prefers non-extra-point activities (regular epoch evaluations) over
/// extra-point entries so that [EnrichedChallenge.activity] reflects the
/// base reward. Extra points are summed separately via [_sumExtraPoints].
BreakdownActivity? _primaryActivity(List<BreakdownActivity>? list) {
  if (list == null || list.isEmpty) return null;
  if (list.length == 1 && !list.first.id.startsWith('extra-point-')) {
    return list.first;
  }
  final primary = list.where((a) => !a.id.startsWith(kExtraPointIdPrefix));
  return primary.isNotEmpty ? primary.first : null;
}

/// Sums points from extra-point activities in [list].
int _sumExtraPoints(List<BreakdownActivity>? list) {
  if (list == null || list.isEmpty) return 0;
  return list
      .where((a) => a.id.startsWith(kExtraPointIdPrefix))
      .fold<int>(0, (sum, a) => sum + a.points);
}

/// Result of categorizing enriched challenges into tab buckets.
class CategorizedEnrichedChallenges {
  final List<EnrichedChallenge> active;
  final List<EnrichedChallenge> completed;
  final List<EnrichedChallenge> missed;

  const CategorizedEnrichedChallenges({
    required this.active,
    required this.completed,
    required this.missed,
  });
}

typedef ChallengeProgressResolver = ChallengeProgress? Function(
  ChallengeDto dto,
);

/// Parses a datetime string, treating bare (non-UTC) values as UTC.
///
/// The leaderboard API sends schedule dates without timezone info
/// (e.g. "2026-01-30 12:00:00"). Dart parses these as local time,
/// but the server intends UTC.
DateTime? _parseAsUtc(String? value) {
  if (value == null) return null;
  final dt = DateTime.tryParse(value);
  if (dt == null) return null;
  return dt.isUtc
      ? dt
      : DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
}

/// Whether [dto.scheduleEnd] is in the past.
bool _isScheduleExpired(ChallengeDto dto) {
  final end = _parseAsUtc(dto.scheduleEnd);
  if (end == null) return false;
  return DateTime.now().toUtc().isAfter(end);
}

/// Categorizes enriched challenges into the three tab buckets.
///
/// A challenge is **over** when `dto.completed` is true OR its schedule end
/// date is in the past.
///
/// - **Completed**: over AND the participant won points.
/// - **Missed**: over but won no points, OR not enabled and not yet over.
/// - **Active**: enabled, not over.
CategorizedEnrichedChallenges categorizeEnrichedChallenges(
    List<EnrichedChallenge> challenges,
    {ChallengeProgressResolver? progressForChallenge}) {
  final active = <EnrichedChallenge>[];
  final completed = <EnrichedChallenge>[];
  final missed = <EnrichedChallenge>[];

  for (final c in challenges) {
    final progress = progressForChallenge?.call(c.dto);
    final progressEarned = progress?.state == ChallengeProgressState.earned;
    final hasEarnedPoints =
        (c.displayEarnedPoints ?? progress?.earnedPoints ?? 0) > 0;
    final over = c.dto.completed || _isScheduleExpired(c.dto);

    // HIDE: unreleased challenge — not enabled, not over, no earned points.
    if (!c.dto.enabled && !over && !hasEarnedPoints && !progressEarned) {
      continue;
    }

    if (progressEarned) {
      completed.add(c);
    } else if (over) {
      (hasEarnedPoints ? completed : missed).add(c);
    } else if (c.dto.enabled) {
      active.add(c);
    } else {
      missed.add(c);
    }
  }

  return CategorizedEnrichedChallenges(
    active: _pinProduceBlocks(active),
    completed: _pinProduceBlocks(completed),
    missed: _pinProduceBlocks(missed),
  );
}

/// Moves produce-blocks challenges to the front, preserving relative order.
List<EnrichedChallenge> _pinProduceBlocks(List<EnrichedChallenge> list) {
  final pb = list.where((c) => isProduceBlocksChallenge(c.dto));
  final rest = list.where((c) => !isProduceBlocksChallenge(c.dto));
  return [...pb, ...rest];
}

/// Formats an integer with comma grouping, e.g. 8000 → "8,000".
String formatPoints(int points) {
  return NumberFormat('#,##0').format(points);
}

/// Formats a reward value for display.
///
/// If [reward] is a pure number string (e.g. "6500"), formats it with comma
/// grouping and wraps as "Up to 6,500 pts". If it already contains non-digit
/// characters (e.g. "Up to 6,500 pts"), returns it as-is.
String formatRewardText(String reward) {
  final asInt = int.tryParse(reward);
  if (asInt != null) return 'Up to ${formatPoints(asInt)} pts';
  return reward;
}

/// ID prefix for extra-point activities returned by the backend, e.g.
/// `"extra-point-42"`.
const String kExtraPointIdPrefix = 'extra-point-';

/// Parses the ceiling value from reward strings like "Up to 6,500 pts" → 6500.
///
/// Returns null when the string does not match the "Up to" pattern (e.g. plain
/// number strings like "1000").
int? parseRewardCeiling(String reward) {
  final match = RegExp(r'[Uu]p\s+to\s+([\d,]+)').firstMatch(reward);
  if (match == null) return null;
  return int.tryParse(match.group(1)!.replaceAll(',', ''));
}

/// SubCategory identifier for the produce-blocks challenge.
const String kProduceBlocksSubCategory = 'PRODUCE_BLOCKS_CHALLENGE';

/// SubCategory identifier for the ZK Identity challenge.
const String zkIdentitySubCategory = 'ZK_IDENTITY_VERIFICATION';

/// Returns true when the challenge is the produce-blocks challenge.
bool isProduceBlocksChallenge(ChallengeDto dto) {
  return dto.subCategory == kProduceBlocksSubCategory;
}
