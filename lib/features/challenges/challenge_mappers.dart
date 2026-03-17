import 'package:intl/intl.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_card.dart';

/// Maps [ChallengeDto.category] string to [ChallengeCategory] enum.
///
/// Case-insensitive. Unknown values fall back to [ChallengeCategory.technical].
ChallengeCategory mapCategory(String category) {
  switch (category.toLowerCase()) {
    case 'technical':
      return ChallengeCategory.technical;
    case 'community':
      return ChallengeCategory.community;
    case 'flash':
      return ChallengeCategory.flash;
    default:
      return ChallengeCategory.technical;
  }
}

/// Maps a [ChallengeDto] to the simplified v1 [ChallengeCardVariant].
///
/// No ongoing detection for v1 — all enabled challenges are `active`.
ChallengeCardVariant mapVariant(ChallengeDto dto) {
  if (dto.completed) return ChallengeCardVariant.completed;
  if (!dto.enabled && !dto.completed) return ChallengeCardVariant.missed;
  return ChallengeCardVariant.active;
}

/// Result of categorizing challenges into tab buckets.
class CategorizedChallenges {
  final List<ChallengeDto> active;
  final List<ChallengeDto> completed;
  final List<ChallengeDto> missed;

  const CategorizedChallenges({
    required this.active,
    required this.completed,
    required this.missed,
  });
}

/// Splits challenges into three lists for the tab view.
CategorizedChallenges categorizeChallenges(List<ChallengeDto> challenges) {
  final active = <ChallengeDto>[];
  final completed = <ChallengeDto>[];
  final missed = <ChallengeDto>[];

  for (final dto in challenges) {
    if (!dto.enabled) continue;
    if (dto.completed) {
      completed.add(dto);
    } else {
      active.add(dto);
    }
  }

  return CategorizedChallenges(
    active: active,
    completed: completed,
    missed: missed,
  );
}

// ---------------------------------------------------------------------------
// Activity extraction from breakdown
// ---------------------------------------------------------------------------

/// Extracts breakdown activities based on the breakdown scope.
///
/// For event scope, returns the event's activities directly.
/// For season scope, flattens activities across all events.
/// Returns null when breakdown is null or scope is unrecognised.
List<BreakdownActivity>? extractActivities(BreakdownResult? breakdown) {
  if (breakdown == null) return null;
  if (breakdown.scope == 'event') {
    return breakdown.eventBreakdown?.activities;
  }
  if (breakdown.scope == 'season') {
    final events = breakdown.seasonBreakdown?.events;
    if (events == null) return null;
    return events.expand((e) => e.activities).toList();
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

  const EnrichedChallenge({required this.dto, this.activity});

  /// Whether the participant completed this challenge (has a matching activity).
  bool get participantCompleted => activity != null;

  /// Actual points earned by the participant, or null if not completed.
  int? get earnedPoints => activity?.points;
}

/// Cross-references challenges with breakdown activities.
///
/// Prefers matching by [BreakdownActivity.challengeId] → [ChallengeDto.id].
/// Falls back to [BreakdownActivity.description] → [ChallengeDto.goal] when
/// `challengeId` is null (older cached data).
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

  final byId = <int, BreakdownActivity>{};
  final byDesc = <String, BreakdownActivity>{};
  for (final a in activities) {
    if (a.challengeId != null) byId[a.challengeId!] = a;
    if (a.description != null) byDesc[a.description!] = a;
  }

  return challenges
      .map((dto) => EnrichedChallenge(
            dto: dto,
            // TODO(challenges): Remove description fallback once all breakdown
            // activities include challengeId. The assumption that
            // description == goal is a reliable match is fragile.
            activity: byId[dto.id] ?? byDesc[dto.goal],
          ))
      .toList();
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

/// Categorizes enriched challenges using participant-specific completion.
///
/// - **Completed**: participant has a matching breakdown activity
/// - **Missed**: challenge not enabled OR schedule has ended (and not completed)
/// - **Active**: everything else (enabled, schedule not expired, not yet completed)
CategorizedEnrichedChallenges categorizeEnrichedChallenges(
  List<EnrichedChallenge> challenges,
) {
  final active = <EnrichedChallenge>[];
  final completed = <EnrichedChallenge>[];
  final missed = <EnrichedChallenge>[];

  for (final c in challenges) {
    if (!c.dto.enabled) continue;
    // Produce-blocks earns incrementally — activity ≠ completed.
    if (isProduceBlocksChallenge(c.dto)) {
      if (c.dto.completed) {
        completed.add(c);
      } else if (_isScheduleExpired(c.dto)) {
        missed.add(c);
      } else {
        active.add(c);
      }
    } else if (c.participantCompleted) {
      completed.add(c);
    } else if (_isScheduleExpired(c.dto)) {
      missed.add(c);
    } else {
      active.add(c);
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

/// Maps an [EnrichedChallenge] to [ChallengeCardVariant] using
/// participant-specific completion data.
///
/// For produce-blocks challenges, [eventSuccessRate] provides a fallback for
/// ongoing detection when there is no per-challenge activity match but the
/// event-level breakdown shows a non-zero success rate.
ChallengeCardVariant mapEnrichedVariant(
  EnrichedChallenge c, {
  double? eventSuccessRate,
}) {
  // Produce-blocks earns points incrementally — activity ≠ completed.
  if (isProduceBlocksChallenge(c.dto)) {
    if (c.dto.completed) return ChallengeCardVariant.completed;
    if (!c.dto.enabled || _isScheduleExpired(c.dto)) {
      return ChallengeCardVariant.missed;
    }
    if (c.earnedPoints != null) return ChallengeCardVariant.ongoing;
    if (eventSuccessRate != null && eventSuccessRate > 0) {
      return ChallengeCardVariant.ongoing;
    }
    return ChallengeCardVariant.active;
  }
  if (c.participantCompleted) return ChallengeCardVariant.completed;
  if (!c.dto.enabled || _isScheduleExpired(c.dto)) {
    return ChallengeCardVariant.missed;
  }
  return ChallengeCardVariant.active;
}

/// Formats actual earned points from breakdown, e.g. 6491 → "6,491 pts".
String formatEarnedPoints(int points) {
  return '${formatPoints(points)} pts';
}

/// Formats a date range as "Jan 15 - Feb 15", converting UTC to local time.
///
/// Returns an empty string if both dates are null.
String formatDateRange(String? start, String? end) {
  final fmt = DateFormat('MMM d');
  final parts = <String>[];
  final s = _parseAsUtc(start)?.toLocal();
  if (s != null) parts.add(fmt.format(s));
  final e = _parseAsUtc(end)?.toLocal();
  if (e != null) parts.add(fmt.format(e));
  return parts.join(' - ');
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

/// Formats a reward value for the completed/missed bar.
///
/// If [reward] is a pure number string, formats as "6,500 pts".
/// Otherwise returns the raw string.
String formatCompletedPoints(String reward) {
  final asInt = int.tryParse(reward);
  if (asInt != null) return '${formatPoints(asInt)} pts';
  return reward;
}

/// Formats a human-readable label for a point-tracking duration.
///
/// - >= 24h: "Last 24h"
/// - >= 1h: "Last Xh" (e.g. "Last 3h")
/// - >= 5m: "Last Xm" (e.g. "Last 15m")
/// - < 5m: "Last 24h" (too short to be meaningful; show default)
String formatDiffLabel(Duration since) {
  if (since >= const Duration(hours: 24)) return 'Last 24h';
  if (since >= const Duration(hours: 1)) return 'Last ${since.inHours}h';
  if (since >= const Duration(minutes: 5)) return 'Last ${since.inMinutes}m';
  return 'Last 24h';
}

// ---------------------------------------------------------------------------
// Reward-type detection & parsing
// ---------------------------------------------------------------------------

/// The subcategory value that identifies produce-blocks challenges.
const String kProduceBlocksSubCategory = 'PRODUCE_BLOCKS_CHALLENGE';

/// Points reserved for top-3 rank bonus in the reward ceiling.
///
/// The API returns a single ceiling (e.g. 6,500) that includes both the
/// success-rate component and the top-3 bonus. Until the API splits these,
/// we subtract this constant to derive maxSuccessRatePoints.
const int kTop3RankBonusPoints = 1500;

/// Parses the ceiling value from reward strings like "Up to 6,500 pts" → 6500.
///
/// Returns null when the string does not match the "Up to" pattern (e.g. plain
/// number strings like "1000").
int? parseRewardCeiling(String reward) {
  final match = RegExp(r'[Uu]p\s+to\s+([\d,]+)').firstMatch(reward);
  if (match == null) return null;
  return int.tryParse(match.group(1)!.replaceAll(',', ''));
}

/// Returns true when the challenge is the produce-blocks challenge.
bool isProduceBlocksChallenge(ChallengeDto dto) {
  return dto.subCategory == kProduceBlocksSubCategory;
}

/// SubCategory identifier for the ZK Identity challenge.
const String zkIdentitySubCategory = 'ZK_IDENTITY_VERIFICATION';

/// Returns true when the challenge is the ZK Identity challenge.
bool isZkIdentityChallenge(ChallengeDto dto) {
  return dto.subCategory == zkIdentitySubCategory;
}

/// SubCategory identifier for the dApps challenge.
const String kDappsSubCategory = 'DAPPS_CHALLENGE';

/// Returns true when the challenge is the dApps challenge.
bool isDappsChallenge(ChallengeDto dto) => dto.subCategory == kDappsSubCategory;

/// Computes effective earned points for produce-blocks challenges.
///
/// When [earnedPoints] (from per-challenge breakdown) is available, returns it
/// directly. Otherwise, derives from event-level [successRate] × max pts
/// (ceiling minus [kTop3RankBonusPoints]).
///
/// Returns null when neither source is available or [rewardText] can't be
/// parsed.
int? computeEffectiveEarnedPoints({
  int? earnedPoints,
  double? successRate,
  String? rewardText,
}) {
  if (earnedPoints != null) return earnedPoints;
  final sr = successRate ?? 0;
  if (sr <= 0 || rewardText == null) return null;
  final ceiling = parseRewardCeiling(formatRewardText(rewardText));
  if (ceiling == null) return null;
  final maxPts = ceiling - kTop3RankBonusPoints;
  return (sr * maxPts / 100).round();
}

/// Formats rank as an ordinal: 1 → "1st", 2 → "2nd", 3 → "3rd".
///
/// Returns null for null input or ranks outside 1–3.
String? formatRankOrdinal(int? rank) {
  return switch (rank) {
    1 => '1st',
    2 => '2nd',
    3 => '3rd',
    _ => null,
  };
}
