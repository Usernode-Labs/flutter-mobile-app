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

/// A perceived-time band of atomic challenge cards. The deadline lives at the
/// band layer; cards stay focused on progress + reward (#449, #440).
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

class ChallengePresentationLabels {
  const ChallengePresentationLabels({
    this.phaseNotDone = 'Not done',
    this.phaseInProgress = 'In progress',
    this.phaseSubmitted = 'Submitted',
    this.phaseWaitingReview = 'waiting review',
    this.phaseDone = 'Done',
    this.bandFeatured = 'Featured',
    this.bandToday = 'Today',
    this.bandThisWeek = 'This week',
    this.bandSeason = 'Season',
  });

  final String phaseNotDone;
  final String phaseInProgress;
  final String phaseSubmitted;
  final String phaseWaitingReview;
  final String phaseDone;
  final String bandFeatured;
  final String bandToday;
  final String bandThisWeek;
  final String bandSeason;
}

// ---------------------------------------------------------------------------
// Card mapping
// ---------------------------------------------------------------------------

/// Maps an [EnrichedChallenge] to an [AtomicChallengeCardModel].
///
/// When [progress] is supplied by the breakdown contract it drives the phase,
/// fill, and labels precisely. Otherwise a generic status is derived from the
/// schedule + breakdown activities the app already has (#440 "generic progress
/// first").
AtomicChallengeCardModel mapToAtomicCard(
  EnrichedChallenge c, {
  ChallengeProgress? progress,
  double? technicalSuccessRate,
  bool featured = false,
  ChallengePresentationLabels labels = const ChallengePresentationLabels(),
}) {
  final progressRailTreatment = _railTreatment(c.dto);
  final phase = _phase(c, progress);
  final cardRailTreatment = _cardRailTreatment(
    c.dto,
    phase,
    progressRailTreatment,
  );
  final fill = _fill(c, progress, progressRailTreatment);
  return AtomicChallengeCardModel(
    challengeId: c.dto.id,
    title: c.dto.goal,
    leftText: _leftText(
      c,
      progress,
      phase,
      progressRailTreatment,
      technicalSuccessRate,
      labels,
    ),
    rightText: _rightText(c, progress, phase, progressRailTreatment, labels),
    phase: phase,
    fill: fill,
    railTreatment: cardRailTreatment,
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
    ChallengeMetricKind.unknown ||
    null =>
      AtomicChallengeRailTreatment.checkbox,
  };
}

AtomicChallengeRailTreatment _cardRailTreatment(
  ChallengeDto dto,
  AtomicChallengePhase phase,
  AtomicChallengeRailTreatment progressRailTreatment,
) {
  if (isProduceBlocksChallenge(dto) &&
      phase == AtomicChallengePhase.completed) {
    return AtomicChallengeRailTreatment.checkbox;
  }
  return progressRailTreatment;
}

AtomicChallengePhase _phase(EnrichedChallenge c, ChallengeProgress? progress) {
  if (progress != null) {
    return switch (progress.state) {
      ChallengeProgressState.none => _pendingPointsPhase(c, progress),
      ChallengeProgressState.inProgress => AtomicChallengePhase.inProgress,
      ChallengeProgressState.pending => _pendingPhase(c, progress),
      ChallengeProgressState.earned => AtomicChallengePhase.completed,
      // Atomic cards do not have distinct missed/declined treatments yet, and
      // these states are explicitly not successful completions.
      ChallengeProgressState.missed ||
      ChallengeProgressState.declined =>
        AtomicChallengePhase.open,
    };
  }

  // Generic fallback from existing fields (#440). Do not treat an expired or
  // administratively closed schedule as user completion; the scoped breakdown
  // progress is the canonical source for missed/earned status when available.
  final hasPoints = (c.displayEarnedPoints ?? 0) > 0;
  if (hasPoints) return AtomicChallengePhase.completed;
  if (c.participantCompleted) return AtomicChallengePhase.inProgress;
  return AtomicChallengePhase.open;
}

AtomicChallengePhase _pendingPointsPhase(
  EnrichedChallenge c,
  ChallengeProgress progress,
) {
  final kind = c.dto.metric?.kind;
  final hasEarnedPoints = progress.earnedPoints > 0;
  final hasPendingPoints = progress.pendingPoints > 0;
  final isBinaryOrNoMetric = kind == null || kind == ChallengeMetricKind.binary;
  if (hasEarnedPoints && isBinaryOrNoMetric) {
    return AtomicChallengePhase.completed;
  }
  if (hasPendingPoints && isBinaryOrNoMetric) {
    return AtomicChallengePhase.pendingFinalization;
  }
  return AtomicChallengePhase.open;
}

AtomicChallengePhase _pendingPhase(
  EnrichedChallenge c,
  ChallengeProgress progress,
) {
  final kind = c.dto.metric?.kind;
  if (kind != ChallengeMetricKind.count && kind != ChallengeMetricKind.sum) {
    return AtomicChallengePhase.pendingFinalization;
  }

  final bounded = _metricProgress(c, progress);
  if (bounded == null) return AtomicChallengePhase.open;
  if (bounded.current >= bounded.target) {
    return AtomicChallengePhase.pendingFinalization;
  }
  return bounded.current > 0
      ? AtomicChallengePhase.inProgress
      : AtomicChallengePhase.open;
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
    final bounded = _metricProgress(c, progress);
    if (bounded != null) {
      return (bounded.current / bounded.target).clamp(0.0, 1.0).toDouble();
    }
    final current = progress.current;
    if (c.dto.metric?.kind == ChallengeMetricKind.percentage &&
        current != null) {
      return (current / 100).clamp(0.0, 1.0).toDouble();
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
  double? technicalSuccessRate,
  ChallengePresentationLabels labels,
) {
  if (progress != null) {
    final kind = c.dto.metric?.kind;
    final bounded = _metricProgress(c, progress);
    if (bounded != null) {
      return _metricProgressText(c.dto.metric, bounded);
    }
    // Percentage / continuous work reads as "N% success".
    if (railTreatment == AtomicChallengeRailTreatment.technicalOngoing ||
        kind == ChallengeMetricKind.percentage) {
      if (progress.current != null) {
        if (railTreatment == AtomicChallengeRailTreatment.technicalOngoing) {
          return _successRateText(progress.current!);
        }
        return '${_formatMetricValue(progress.current!)}% success';
      }
      if (railTreatment == AtomicChallengeRailTreatment.technicalOngoing) {
        final successRate =
            technicalSuccessRate ?? _derivedProduceBlocksSuccessRate(c);
        if (successRate != null) {
          return _successRateText(successRate);
        }
      }
    }
    // Count/sum progress is canonical only when `current` is present. Backend
    // reasoning is evidence text, not a stable progress source.
    if (kind == ChallengeMetricKind.count || kind == ChallengeMetricKind.sum) {
      return _phaseLabel(phase, labels);
    }
    if (phase == AtomicChallengePhase.completed &&
        (kind == null || kind == ChallengeMetricKind.binary)) {
      return _phaseLabel(phase, labels);
    }
    // A backend-provided status wins for non-empty states (e.g. "Submitted",
    // "Joined", "Eligible"). In the API shape, state=none may carry the
    // challenge description, which is not progress/status text.
    if (progress.state != ChallengeProgressState.none &&
        progress.description != null &&
        progress.description!.isNotEmpty) {
      return progress.description!;
    }
  }
  final bounded = _metricProgress(c, progress);
  if (bounded != null) {
    return _metricProgressText(c.dto.metric, bounded);
  }
  if (railTreatment == AtomicChallengeRailTreatment.technicalOngoing) {
    final successRate =
        technicalSuccessRate ?? _derivedProduceBlocksSuccessRate(c);
    if (successRate != null) {
      return _successRateText(successRate);
    }
  }
  return _phaseLabel(phase, labels);
}

String _successRateText(num value) => '${value.round()}% success';

double? _derivedProduceBlocksSuccessRate(EnrichedChallenge c) {
  if (!isProduceBlocksChallenge(c.dto)) return null;
  final earned = c.activity?.points ?? c.displayEarnedPoints;
  if (earned == null || earned <= 0) return null;
  final ceiling = _rewardCeiling(c.dto);
  if (ceiling == null || ceiling <= kTop3RankBonusPoints) return null;
  final baseCeiling = ceiling - kTop3RankBonusPoints;
  return (earned / baseCeiling * 100).clamp(0.0, 100.0).toDouble();
}

({num current, num target})? _metricProgress(
  EnrichedChallenge c,
  ChallengeProgress? progress,
) {
  final kind = c.dto.metric?.kind;
  if (kind != ChallengeMetricKind.count && kind != ChallengeMetricKind.sum) {
    return null;
  }

  final target = progress?.target ?? c.dto.metric?.target;
  if (target == null || target <= 0) return null;

  final current = progress?.current ?? _defaultMetricCurrent(progress);
  if (current == null) return null;

  return (current: current.clamp(0, target), target: target);
}

String _metricProgressText(
  ChallengeMetric? metric,
  ({num current, num target}) progress,
) {
  final label = metric?.label?.trim();
  final suffix = label == null || label.isEmpty ? '' : ' $label';
  return '${_formatMetricValue(progress.current)} / '
      '${_formatMetricValue(progress.target)}$suffix';
}

num? _defaultMetricCurrent(ChallengeProgress? progress) {
  return switch (progress?.state) {
    ChallengeProgressState.none => 0,
    _ => null,
  };
}

String _formatMetricValue(num value) {
  final doubleValue = value.toDouble();
  if (doubleValue.isFinite && doubleValue == doubleValue.truncateToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

String _rightText(
  EnrichedChallenge c,
  ChallengeProgress? progress,
  AtomicChallengePhase phase,
  AtomicChallengeRailTreatment railTreatment,
  ChallengePresentationLabels labels,
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
      return labels.phaseWaitingReview;
    case AtomicChallengePhase.completed:
      final pts = earned > 0 ? earned : ceiling;
      return pts != null
          ? 'completed ${formatPoints(pts)} pts'
          : labels.phaseDone;
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

String _phaseLabel(
  AtomicChallengePhase phase,
  ChallengePresentationLabels labels,
) {
  return switch (phase) {
    AtomicChallengePhase.open => labels.phaseNotDone,
    AtomicChallengePhase.inProgress => labels.phaseInProgress,
    AtomicChallengePhase.pendingFinalization => labels.phaseSubmitted,
    AtomicChallengePhase.completed => labels.phaseDone,
  };
}

/// Reward ceiling in points from the DTO's `reward` string. Handles plain
/// numbers ("500"), simple point strings ("500 pts"), and "Up to 6,500 pts".
int? _rewardCeiling(ChallengeDto dto) {
  final plain = int.tryParse(dto.reward.replaceAll(',', '').trim());
  if (plain != null) return plain;
  final simplePoints = RegExp(r'^\s*([\d,]+)\s*pts?\s*$', caseSensitive: false)
      .firstMatch(dto.reward);
  if (simplePoints != null) {
    return int.tryParse(simplePoints.group(1)!.replaceAll(',', ''));
  }
  return parseRewardCeiling(dto.reward) ??
      parseRewardCeiling(formatRewardText(dto.reward));
}

/// Legacy helper for the previous active-only Challenges surface.
///
/// A challenge is "over" when it is explicitly completed or its schedule end is
/// in the past. The current Challenges surface keeps completed challenges in
/// the deadline stream; new stream code should not use this to filter cards.
bool isChallengeActive(ChallengeDto dto) {
  return !dto.completed && !_isScheduleExpired(dto);
}

// ---------------------------------------------------------------------------
// Band grouping
// ---------------------------------------------------------------------------

/// Groups enriched challenges into perceived-time bands for the Challenges
/// surface.
///
/// - `Featured`: explicit backend presentation picks.
/// - `Today`: schedule ends within the next 24h.
/// - `This week`: schedule ends within the next 7 days.
/// - `Season`: everything else (long-running / background / expired work).
///
/// Within each deadline band, non-terminal cards stay above completed cards.
/// Otherwise, backend order is preserved.
///
/// [progressForChallenge] resolves explicit backend progress for a challenge.
/// [now] is injectable for deterministic tests.
List<ChallengeBand> buildChallengeBands(
  List<EnrichedChallenge> active, {
  ChallengeProgress? Function(ChallengeDto dto)? progressForChallenge,
  double? Function(ChallengeDto dto)? technicalSuccessRateForChallenge,
  ChallengePresentationLabels labels = const ChallengePresentationLabels(),
  DateTime? now,
}) {
  if (active.isEmpty) return const [];
  final clock = (now ?? DateTime.now()).toUtc();

  AtomicChallengeCardModel cardFor(EnrichedChallenge c,
      {bool featured = false}) {
    return mapToAtomicCard(
      c,
      progress: progressForChallenge?.call(c.dto),
      technicalSuccessRate: technicalSuccessRateForChallenge?.call(c.dto),
      featured: featured,
      labels: labels,
    );
  }

  final bands = <ChallengeBand>[];
  final featured = active.where((c) => c.dto.featured).toList();
  final rest = active.where((c) => !c.dto.featured).toList();

  if (featured.isNotEmpty) {
    final sorted = _sortFeaturedItems(featured);
    bands.add(ChallengeBand(
      title: labels.bandFeatured,
      cards: [for (final c in sorted) cardFor(c, featured: true)],
    ));
  }

  final today = <EnrichedChallenge>[];
  final thisWeek = <EnrichedChallenge>[];
  final season = <EnrichedChallenge>[];
  for (final c in rest) {
    switch (_timeBand(c.dto, clock)) {
      case _ChallengeTimeBand.today:
        today.add(c);
      case _ChallengeTimeBand.thisWeek:
        thisWeek.add(c);
      case _ChallengeTimeBand.season:
        season.add(c);
    }
  }

  void addBand(String title, List<EnrichedChallenge> items) {
    if (items.isEmpty) return;
    final sorted = _sortBandItems(items, progressForChallenge);
    bands.add(ChallengeBand(
      title: title,
      deadlineText: _bandDeadline(sorted, clock),
      cards: [for (final c in sorted) cardFor(c)],
    ));
  }

  addBand(labels.bandToday, today);
  addBand(labels.bandThisWeek, thisWeek);
  addBand(labels.bandSeason, season);
  return bands;
}

enum _ChallengeTimeBand { today, thisWeek, season }

_ChallengeTimeBand _timeBand(ChallengeDto dto, DateTime nowUtc) {
  final end = _scheduleEndUtc(dto);
  if (end == null) return _ChallengeTimeBand.season;

  final remaining = end.difference(nowUtc);
  if (remaining.isNegative) return _ChallengeTimeBand.season;
  if (remaining <= const Duration(hours: 24)) {
    return _ChallengeTimeBand.today;
  }
  if (remaining <= const Duration(days: 7)) {
    return _ChallengeTimeBand.thisWeek;
  }
  return _ChallengeTimeBand.season;
}

List<EnrichedChallenge> _sortFeaturedItems(List<EnrichedChallenge> items) {
  const unprioritizedFeaturedOrder = 1 << 30;
  final indexed = items.indexed.toList();
  indexed.sort((a, b) {
    final featuredOrderA = a.$2.dto.featuredOrder ?? unprioritizedFeaturedOrder;
    final featuredOrderB = b.$2.dto.featuredOrder ?? unprioritizedFeaturedOrder;
    final byFeaturedOrder = featuredOrderA.compareTo(featuredOrderB);
    if (byFeaturedOrder != 0) return byFeaturedOrder;
    final byDisplayOrder =
        a.$2.dto.displayOrder.compareTo(b.$2.dto.displayOrder);
    if (byDisplayOrder != 0) return byDisplayOrder;
    return a.$1.compareTo(b.$1);
  });
  return indexed.map((entry) => entry.$2).toList();
}

List<EnrichedChallenge> _sortBandItems(
  List<EnrichedChallenge> items,
  ChallengeProgress? Function(ChallengeDto dto)? progressForChallenge,
) {
  final indexed = items.indexed.toList();
  indexed.sort((a, b) {
    final phaseA = _phase(a.$2, progressForChallenge?.call(a.$2.dto));
    final phaseB = _phase(b.$2, progressForChallenge?.call(b.$2.dto));
    final priority =
        _bandSortPriority(phaseA).compareTo(_bandSortPriority(phaseB));
    if (priority != 0) return priority;
    return a.$1.compareTo(b.$1);
  });
  return indexed.map((entry) => entry.$2).toList();
}

int _bandSortPriority(AtomicChallengePhase phase) {
  return phase == AtomicChallengePhase.completed ? 1 : 0;
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
