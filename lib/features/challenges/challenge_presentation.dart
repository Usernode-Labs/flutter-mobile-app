import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart'
    show AtomicChallengePhase, AtomicChallengeRailTreatment;
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';

/// Presentation model for one [AtomicChallengeCard]. Built by [mapToAtomicCard]
/// from an [EnrichedChallenge] plus optional explicit [ChallengeProgress].
///
/// This is the single contract between the challenge data layer and the
/// stateless atomic card: the screen renders these directly and never touches
/// raw DTOs.
class AtomicChallengeCardModel {
  const AtomicChallengeCardModel({
    required this.challengeId,
    required this.title,
    required this.leftText,
    required this.rightText,
    required this.phase,
    required this.fill,
    required this.railTreatment,
    this.featured = false,
  });

  final int challengeId;
  final String title;
  final String leftText;
  final String rightText;
  final AtomicChallengePhase phase;
  final double? fill;
  final AtomicChallengeRailTreatment railTreatment;
  final bool featured;
}

/// A perceived-time band of atomic challenge cards (board "Featured" / "Today" /
/// "This week" / "Season" frames). The deadline lives at the band layer; cards
/// stay focused on progress + reward (#449, #440).
class ChallengeBand {
  const ChallengeBand({
    required this.title,
    required this.cards,
    this.deadlineText,
  });

  final String title;
  final String? deadlineText;
  final List<AtomicChallengeCardModel> cards;
}

// ---------------------------------------------------------------------------
// Card mapping
// ---------------------------------------------------------------------------

/// Maps an [EnrichedChallenge] to an [AtomicChallengeCardModel].
///
/// When [progress] is supplied (mock service / future API) it drives the phase,
/// fill, and labels precisely. Otherwise a generic status is derived from the
/// schedule + breakdown activities the app already has (#440 "generic progress
/// first").
AtomicChallengeCardModel mapToAtomicCard(
  EnrichedChallenge c, {
  ChallengeProgress? progress,
  bool featured = false,
}) {
  final railTreatment = _railTreatment(c.dto);
  final phase = _phase(c, progress);
  final fill = _fill(c, progress, railTreatment);
  return AtomicChallengeCardModel(
    challengeId: c.dto.id,
    title: c.dto.goal,
    leftText: _leftText(c, progress, phase, railTreatment),
    rightText: _rightText(c, progress, phase, railTreatment),
    phase: phase,
    fill: fill,
    railTreatment: railTreatment,
    featured: featured,
  );
}

AtomicChallengeRailTreatment _railTreatment(ChallengeDto dto) {
  if (isProduceBlocksChallenge(dto)) {
    return AtomicChallengeRailTreatment.technicalOngoing;
  }
  return switch (dto.metric?.kind) {
    ChallengeMetricKind.binary => AtomicChallengeRailTreatment.checkbox,
    ChallengeMetricKind.count ||
    ChallengeMetricKind.percentage ||
    ChallengeMetricKind.sum =>
      AtomicChallengeRailTreatment.standard,
    // `rank` is state-only (no bounded fill) — render as a standard rail.
    ChallengeMetricKind.rank => AtomicChallengeRailTreatment.standard,
    // No metric on the wire (current backend): a binary checkbox is the safest
    // generic treatment unless a bounded fraction can be derived.
    null => AtomicChallengeRailTreatment.checkbox,
  };
}

AtomicChallengePhase _phase(EnrichedChallenge c, ChallengeProgress? progress) {
  if (progress != null) {
    return switch (progress.state) {
      ChallengeProgressState.none => AtomicChallengePhase.open,
      ChallengeProgressState.inProgress => AtomicChallengePhase.inProgress,
      ChallengeProgressState.pending =>
        AtomicChallengePhase.pendingFinalization,
      // earned / missed / declined are terminal — render as completed (missed
      // and declined are filtered out of the active surface upstream).
      ChallengeProgressState.earned ||
      ChallengeProgressState.missed ||
      ChallengeProgressState.declined =>
        AtomicChallengePhase.completed,
    };
  }

  // Generic fallback from existing fields (#440).
  final hasPoints = (c.displayEarnedPoints ?? 0) > 0;
  final over = c.dto.completed || _isScheduleExpired(c.dto);
  if (over) return AtomicChallengePhase.completed;
  if (hasPoints || c.participantCompleted) {
    return AtomicChallengePhase.inProgress;
  }
  return AtomicChallengePhase.open;
}

double? _fill(
  EnrichedChallenge c,
  ChallengeProgress? progress,
  AtomicChallengeRailTreatment railTreatment,
) {
  // technicalOngoing renders an animated frame, never a bounded fill.
  if (railTreatment == AtomicChallengeRailTreatment.technicalOngoing) {
    return null;
  }
  if (progress != null) {
    final current = progress.current;
    final target = progress.target;
    if (current != null && target != null && target > 0) {
      return (current / target).clamp(0.0, 1.0);
    }
    if (c.dto.metric?.kind == ChallengeMetricKind.percentage &&
        current != null) {
      return (current / 100).clamp(0.0, 1.0);
    }
    // State-only metric (binary / rank / no bounds): no fake progress.
    return null;
  }

  // Generic: earned-vs-ceiling fraction when both are known.
  final earned = c.displayEarnedPoints ?? 0;
  final ceiling = _rewardCeiling(c.dto);
  if (ceiling != null && ceiling > 0 && earned > 0) {
    return (earned / ceiling).clamp(0.0, 1.0);
  }
  return null;
}

String _leftText(
  EnrichedChallenge c,
  ChallengeProgress? progress,
  AtomicChallengePhase phase,
  AtomicChallengeRailTreatment railTreatment,
) {
  if (progress != null) {
    final kind = c.dto.metric?.kind;
    // Percentage / continuous work reads as "N% success".
    if (railTreatment == AtomicChallengeRailTreatment.technicalOngoing ||
        kind == ChallengeMetricKind.percentage) {
      if (progress.current != null) return '${progress.current}% success';
    }
    // Bounded counts read as "current / target".
    if ((kind == ChallengeMetricKind.count ||
            kind == ChallengeMetricKind.sum) &&
        progress.current != null &&
        progress.target != null) {
      return '${progress.current} / ${progress.target}';
    }
    // A backend-provided status wins for everything else (e.g. "Submitted",
    // "Joined", "Eligible").
    if (progress.description != null && progress.description!.isNotEmpty) {
      return progress.description!;
    }
  }
  return _phaseLabel(phase);
}

String _rightText(
  EnrichedChallenge c,
  ChallengeProgress? progress,
  AtomicChallengePhase phase,
  AtomicChallengeRailTreatment railTreatment,
) {
  final ceiling = _rewardCeiling(c.dto);
  final earned = progress?.earnedPoints ?? c.displayEarnedPoints ?? 0;
  final pending = progress?.pendingPoints ?? 0;

  // Continuous background work reports a running total, not a bounded fraction.
  if (railTreatment == AtomicChallengeRailTreatment.technicalOngoing) {
    return earned > 0 ? 'Earned ${formatPoints(earned)} pts' : 'Earned 0 pts';
  }

  switch (phase) {
    case AtomicChallengePhase.pendingFinalization:
      final pts = pending > 0 ? pending : (ceiling ?? earned);
      if (pts > 0) return 'pending ${formatPoints(pts)} pts';
      return 'waiting review';
    case AtomicChallengePhase.completed:
      final pts = earned > 0 ? earned : ceiling;
      return pts != null ? 'completed ${formatPoints(pts)} pts' : 'completed';
    case AtomicChallengePhase.inProgress:
      // Show earned-of-ceiling when both are known, else the ceiling.
      if (ceiling != null && ceiling > 0) {
        return earned > 0
            ? '${formatPoints(earned)} / ${formatPoints(ceiling)} pts'
            : '${formatPoints(ceiling)} pts';
      }
      return earned > 0 ? '${formatPoints(earned)} pts' : '';
    case AtomicChallengePhase.open:
      if (ceiling != null && ceiling > 0) return '${formatPoints(ceiling)} pts';
      return formatCompletedPoints(c.dto.reward);
  }
}

String _phaseLabel(AtomicChallengePhase phase) {
  return switch (phase) {
    AtomicChallengePhase.open => 'Not done',
    AtomicChallengePhase.inProgress => 'In progress',
    AtomicChallengePhase.pendingFinalization => 'Submitted',
    AtomicChallengePhase.completed => 'Done',
  };
}

/// Reward ceiling in points from the DTO's `reward` string. Handles both plain
/// numbers ("500") and "Up to 6,500 pts" forms.
int? _rewardCeiling(ChallengeDto dto) {
  final plain = int.tryParse(dto.reward.replaceAll(',', '').trim());
  if (plain != null) return plain;
  return parseRewardCeiling(dto.reward) ??
      parseRewardCeiling(formatRewardText(dto.reward));
}

// ---------------------------------------------------------------------------
// Band grouping
// ---------------------------------------------------------------------------

/// Groups active enriched challenges into perceived-time bands for the
/// Challenges surface.
///
/// - `Featured`: the first active challenge in backend order, given premium
///   treatment (#440 — a layout treatment of the first item, not a backend
///   state). Pass [featuredFirst] = false to disable.
/// - `Today`: schedule ends within 24h.
/// - `This week`: schedule ends within 7 days.
/// - `Season`: everything else (long-running / background work).
///
/// [progressById] is the optional explicit progress map (mock / future API).
/// [now] is injectable for deterministic tests.
List<ChallengeBand> buildChallengeBands(
  List<EnrichedChallenge> active, {
  Map<int, ChallengeProgress>? progressById,
  bool featuredFirst = true,
  DateTime? now,
}) {
  if (active.isEmpty) return const [];
  final clock = (now ?? DateTime.now()).toUtc();

  AtomicChallengeCardModel cardFor(EnrichedChallenge c,
      {bool featured = false}) {
    return mapToAtomicCard(
      c,
      progress: progressById?[c.dto.id],
      featured: featured,
    );
  }

  final bands = <ChallengeBand>[];
  var rest = active;

  if (featuredFirst) {
    final featured = active.first;
    bands.add(ChallengeBand(
      title: 'Featured',
      cards: [cardFor(featured, featured: true)],
    ));
    rest = active.sublist(1);
  }

  final today = <EnrichedChallenge>[];
  final thisWeek = <EnrichedChallenge>[];
  final season = <EnrichedChallenge>[];
  for (final c in rest) {
    final end = _scheduleEndUtc(c.dto);
    if (end == null) {
      season.add(c);
      continue;
    }
    final remaining = end.difference(clock);
    if (remaining <= const Duration(hours: 24)) {
      today.add(c);
    } else if (remaining <= const Duration(days: 7)) {
      thisWeek.add(c);
    } else {
      season.add(c);
    }
  }

  void addBand(String title, List<EnrichedChallenge> items) {
    if (items.isEmpty) return;
    bands.add(ChallengeBand(
      title: title,
      deadlineText: _bandDeadline(items, clock),
      cards: [for (final c in items) cardFor(c)],
    ));
  }

  addBand('Today', today);
  addBand('This week', thisWeek);
  addBand('Season', season);
  return bands;
}

/// Shortest remaining deadline across a band, formatted as "5h left" / "4d left".
String? _bandDeadline(List<EnrichedChallenge> items, DateTime nowUtc) {
  Duration? shortest;
  for (final c in items) {
    final end = _scheduleEndUtc(c.dto);
    if (end == null) continue;
    final remaining = end.difference(nowUtc);
    if (remaining.isNegative) continue;
    if (shortest == null || remaining < shortest) shortest = remaining;
  }
  if (shortest == null) return null;
  if (shortest.inHours < 24) return '${shortest.inHours}h left';
  return '${shortest.inDays}d left';
}

DateTime? _scheduleEndUtc(ChallengeDto dto) {
  final raw = dto.scheduleEnd;
  if (raw == null) return null;
  final dt = DateTime.tryParse(raw);
  if (dt == null) return null;
  return dt.isUtc
      ? dt
      : DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
}

bool _isScheduleExpired(ChallengeDto dto) {
  final end = _scheduleEndUtc(dto);
  if (end == null) return false;
  return DateTime.now().toUtc().isAfter(end);
}
