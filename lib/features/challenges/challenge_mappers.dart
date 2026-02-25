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
    if (dto.completed) {
      completed.add(dto);
    } else if (!dto.enabled) {
      missed.add(dto);
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

/// Categorizes enriched challenges using participant-specific completion.
///
/// - **Completed**: participant has a matching breakdown activity
/// - **Missed**: challenge not enabled for this phase AND participant didn't complete it
/// - **Active**: everything else (enabled for this phase, not yet completed)
CategorizedEnrichedChallenges categorizeEnrichedChallenges(
  List<EnrichedChallenge> challenges,
) {
  final active = <EnrichedChallenge>[];
  final completed = <EnrichedChallenge>[];
  final missed = <EnrichedChallenge>[];

  for (final c in challenges) {
    if (c.participantCompleted) {
      completed.add(c);
    } else if (!c.dto.enabled) {
      missed.add(c);
    } else {
      active.add(c);
    }
  }

  return CategorizedEnrichedChallenges(
    active: active,
    completed: completed,
    missed: missed,
  );
}

/// Maps an [EnrichedChallenge] to [ChallengeCardVariant] using
/// participant-specific completion data.
ChallengeCardVariant mapEnrichedVariant(EnrichedChallenge c) {
  if (c.participantCompleted) return ChallengeCardVariant.completed;
  if (!c.dto.enabled) return ChallengeCardVariant.missed;
  return ChallengeCardVariant.active;
}

/// Formats actual earned points from breakdown, e.g. 6491 → "6,491 pts".
String formatEarnedPoints(int points) {
  return '${formatPoints(points)} pts';
}

/// Formats an ISO 8601 date range as "Jan 15 - Feb 15".
///
/// Returns an empty string if both dates are null.
String formatDateRange(String? start, String? end) {
  final fmt = DateFormat('MMM d');
  final parts = <String>[];
  if (start != null) {
    try {
      parts.add(fmt.format(DateTime.parse(start)));
    } catch (_) {}
  }
  if (end != null) {
    try {
      parts.add(fmt.format(DateTime.parse(end)));
    } catch (_) {}
  }
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
