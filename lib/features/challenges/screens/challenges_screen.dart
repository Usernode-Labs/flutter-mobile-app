import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/categorized_challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
import 'package:crypto_mobile_app/core/utils/url_launcher.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_activity_summary.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_card.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_category_icon.dart';
import 'package:crypto_mobile_app/design_system/src/score_header.dart';
import 'package:crypto_mobile_app/design_system/theme/color_is_expensive_theme.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/challenges/heartbeat_animation.dart';
import 'package:crypto_mobile_app/features/challenges/season_event_pickers.dart';
import 'package:crypto_mobile_app/features/challenges/screens/challenges_delegates.dart';

/// Immutable pull-to-refresh feedback values for the ScoreHeader.
class PullFeedback {
  final double scale;
  final double offset;
  const PullFeedback({this.scale = 1.0, this.offset = 0.0});

  factory PullFeedback.fromStatus(RefreshIndicatorStatus? status) =>
      switch (status) {
        RefreshIndicatorStatus.drag =>
          const PullFeedback(scale: 1.02, offset: 8.0),
        RefreshIndicatorStatus.armed =>
          const PullFeedback(scale: 1.04, offset: 16.0),
        _ => const PullFeedback(),
      };
}

class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen>
    with TickerProviderStateMixin {
  double _scrollFraction = 0.0;
  late TabController _tabController;
  late final HeartbeatAnimation _heartbeat;

  PullFeedback _pullFeedback = const PullFeedback();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: kTabLabels.length, vsync: this);
    _heartbeat = HeartbeatAnimation(vsync: this);
    _heartbeat.glowValues.addListener(_onGlowChanged);
  }

  @override
  void dispose() {
    _heartbeat.glowValues.removeListener(_onGlowChanged);
    _heartbeat.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onGlowChanged() => setState(() {});

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final fraction =
        (notification.metrics.pixels / kChallengesSpacerHeight).clamp(0.0, 1.0);
    if (fraction != _scrollFraction) {
      setState(() => _scrollFraction = fraction);
    }
    return false;
  }

  void _onRefreshStatusChange(RefreshIndicatorStatus? status) {
    final feedback = PullFeedback.fromStatus(status);
    if (feedback.scale != _pullFeedback.scale ||
        feedback.offset != _pullFeedback.offset) {
      setState(() => _pullFeedback = feedback);
    }
  }

  Future<void> _onRefresh() async {
    final apiFuture = Future.wait([
      ref.read(challengesProvider.notifier).silentRefresh(),
      ref.read(rankingProvider.notifier).silentRefresh(),
      ref.read(breakdownProvider.notifier).silentRefresh(),
    ]);
    await _heartbeat.run(
      apiFuture: apiFuture,
      variant: _scoreVariant,
      disableAnimations: MediaQuery.of(context).disableAnimations,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ensure cold-start context is restored
    ref.watch(leaderboardBootstrapProvider);

    final textTheme = Theme.of(context).textTheme;

    // Wrap the subtree with the design system theme
    return Theme(
      data: ColorIsExpensiveTheme(textTheme).light().copyWith(
            extensions: DesignSystemTheme.standardExtensions(
              semanticColors: AppSemanticColors.light(),
            ),
          ),
      child: Builder(builder: (context) => _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final challengesAsync = ref.watch(challengesProvider);
    final rankingAsync = ref.watch(rankingProvider);
    final breakdownAsync = ref.watch(breakdownProvider);
    // Trigger lazy init so seasons data is available for the pickers.
    ref.watch(seasonsProvider);

    final challenges = challengesAsync.value?.data;
    final ranking = rankingAsync.value?.data;
    final breakdown = breakdownAsync.value?.data;

    final isLoading = challengesAsync.isLoading && challenges == null;
    final hasError = challengesAsync.hasError && challenges == null;

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (hasError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Failed to load challenges',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(challengesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final categorized = ref.watch(categorizedChallengesProvider) ??
        const CategorizedEnrichedChallenges(
            active: [], completed: [], missed: []);
    final badgeCounts = [
      categorized.active.length,
      categorized.completed.length,
      categorized.missed.length,
    ];

    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final safeTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: ColoredBox(
        color: colors.surface,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Layer 1 — parallax ScoreHeader behind scroll surface
            Transform.translate(
              offset:
                  Offset(0, -_scrollFraction * kChallengesSpacerHeight * 0.4),
              child: Padding(
                padding: EdgeInsets.only(
                  top: safeTop + spacing.space8 + kChipHeight + spacing.space8,
                  left: spacing.space16,
                  right: spacing.space16,
                ),
                child: AnimatedScale(
                  scale: _pullFeedback.scale,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: _buildScoreHeader(breakdown, ranking),
                ),
              ),
            ),

            // Layer 2 — scrolling surface
            NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: RefreshIndicator.noSpinner(
                notificationPredicate: (notification) {
                  // Only trigger from outer NestedScrollView (depth 0),
                  // and only when at the top (pixels == 0).
                  if (notification.depth > 0) return false;
                  return notification.metrics.pixels <= 0.0;
                },
                onRefresh: _onRefresh,
                onStatusChange: _onRefreshStatusChange,
                child: AnimatedPadding(
                  padding: EdgeInsets.only(top: _pullFeedback.offset),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) {
                      return [
                        // Pinned chip bar
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: ChipBarDelegate(
                            topPadding: safeTop,
                            spacing: spacing,
                            scrollFraction: _scrollFraction,
                            onSeasonTap: () => showSeasonPicker(context, ref),
                            onEventTap: () => showEventPicker(context, ref),
                            seasonLabel: seasonLabel(ref),
                            eventLabel: eventLabel(ref),
                          ),
                        ),
                        // Transparent spacer revealing ScoreHeader
                        const SliverToBoxAdapter(
                          child: SizedBox(height: kChallengesSpacerHeight),
                        ),
                        // Pinned surface tab bar
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: SurfaceTabBarDelegate(
                            tabController: _tabController,
                            scrollFraction: _scrollFraction,
                            badgeCounts: badgeCounts,
                          ),
                        ),
                      ];
                    },
                    body: ColoredBox(
                      color: colors.surfaceContainerLowest,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildActiveTabContent(
                              categorized.active, categorized, spacing),
                          _buildEnrichedChallengeList(categorized.completed,
                              spacing, 'No completed challenges'),
                          _buildEnrichedChallengeList(categorized.missed,
                              spacing, 'No missed challenges'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- ScoreHeader -----------------------------------------------------------

  /// Current variant for the score header. Will be dynamic when glow is earned.
  ScoreHeaderVariant get _scoreVariant => ScoreHeaderVariant.standard;

  /// Resolves the selected season from provider state. Returns null when
  /// seasons data isn't loaded or the selected season can't be found.
  SeasonDto? _resolveSelectedSeason() {
    final seasons = ref.read(seasonsProvider).value?.data;
    final ctx = ref.read(seasonEventContextProvider);
    if (seasons == null || seasons.isEmpty || ctx.seasonId == null) return null;
    return seasons
        .cast<SeasonDto?>()
        .firstWhere((s) => s!.id == ctx.seasonId, orElse: () => null);
  }

  /// Resolves the selected event within the season.
  SeasonEventDto? _resolveSelectedEvent(SeasonDto season) {
    final ctx = ref.read(seasonEventContextProvider);
    if (ctx.eventId == null || season.events.isEmpty) return null;
    return season.events
        .cast<SeasonEventDto?>()
        .firstWhere((e) => e!.id == ctx.eventId, orElse: () => null);
  }

  /// Compute countdown label + time from the resolved event's end date.
  ({String label, String? time}) _computeCountdown() {
    final season = _resolveSelectedSeason();
    if (season == null) return (label: 'ENDS IN', time: null);

    final event = _resolveSelectedEvent(season);
    final endsAtRaw = event?.endsAt;
    if (endsAtRaw == null) return (label: 'ENDS IN', time: null);

    final endsAt = DateTime.tryParse(endsAtRaw);
    if (endsAt == null) return (label: 'ENDS IN', time: null);

    final now = DateTime.now().toUtc();
    final diff = endsAt.toUtc().difference(now);

    if (diff.isNegative) {
      final fmt = DateFormat('MMM d').format(endsAt);
      return (label: 'ENDED', time: fmt.toUpperCase());
    }

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    return (label: 'ENDS IN', time: '${days}D ${hours}H ${minutes}M');
  }

  /// Compute phase (event) time progress as a fraction (0.0 = start, 1.0 = end).
  double _computePhaseProgress() {
    final season = _resolveSelectedSeason();
    if (season == null) return 0.0;

    final event = _resolveSelectedEvent(season);
    if (event == null) return 0.0;

    final startsAtRaw = event.startsAt;
    final endsAtRaw = event.endsAt;
    if (startsAtRaw == null || endsAtRaw == null) return 0.0;

    final start = DateTime.tryParse(startsAtRaw);
    final end = DateTime.tryParse(endsAtRaw);
    if (start == null || end == null) return 0.0;

    final now = DateTime.now().toUtc();
    final total = end.toUtc().difference(start.toUtc()).inSeconds;
    if (total <= 0) return 1.0;

    final elapsed = now.difference(start.toUtc()).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Widget _buildScoreHeader(BreakdownResult? breakdown, RankingResult? ranking) {
    final totalPoints = breakdown?.totalPoints ?? ranking?.totalPoints;
    final rank = breakdown?.eventBreakdown?.rank ?? ranking?.rank;

    final score = totalPoints != null ? formatPoints(totalPoints) : '--';
    final rankLabel = rank != null ? 'Rank $rank' : null;
    final progress = _computePhaseProgress();

    final countdown = _computeCountdown();
    final glow = _heartbeat.glowValues.value;
    return ScoreHeader(
      score: score,
      scoreLabel: 'points',
      rankLabel: rankLabel,
      progress: progress,
      countdownLabel: countdown.label,
      countdownTime: countdown.time,
      ctaLabel: 'View in Leaderboard',
      variant: _scoreVariant,
      technicalGlowIntensity: glow.isAnimating ? glow.technical : null,
      flashGlowIntensity: glow.isAnimating ? glow.flash : null,
      communityGlowIntensity: glow.isAnimating ? glow.community : null,
    );
  }

  // -- Challenge lists -------------------------------------------------------

  Widget _buildActiveTabContent(
    List<EnrichedChallenge> active,
    CategorizedEnrichedChallenges categorized,
    AppSpacing spacing,
  ) {
    if (active.isNotEmpty) {
      return _buildEnrichedChallengeList(active, spacing, '');
    }

    final completedCount = categorized.completed.length;
    final missedCount = categorized.missed.length;
    final totalCount = completedCount + missedCount + active.length;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.space16),
              child: ChallengeActivitySummary(
                completedCount: completedCount,
                missedCount: missedCount,
                totalCount: totalCount,
                onViewCompleted: completedCount > 0
                    ? () => _tabController.animateTo(1)
                    : null,
                onViewMissed:
                    missedCount > 0 ? () => _tabController.animateTo(2) : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnrichedChallengeList(
    List<EnrichedChallenge> challenges,
    AppSpacing spacing,
    String emptyMessage,
  ) {
    if (challenges.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Text(
                emptyMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(spacing.space16),
      itemCount: challenges.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.space12),
      itemBuilder: (context, index) =>
          _buildEnrichedChallengeCard(challenges[index]),
    );
  }

  Widget _buildEnrichedChallengeCard(EnrichedChallenge enriched) {
    final dto = enriched.dto;
    final category = mapCategory(dto.category);
    final variant = mapEnrichedVariant(enriched);

    String? completedPoints;
    if (variant == ChallengeCardVariant.completed) {
      completedPoints = enriched.earnedPoints != null
          ? formatEarnedPoints(enriched.earnedPoints!)
          : formatCompletedPoints(dto.reward);
    } else if (variant == ChallengeCardVariant.missed) {
      completedPoints = formatCompletedPoints(dto.reward);
    }

    return ChallengeCard(
      title: dto.goal,
      description: dto.task,
      dateRange: formatDateRange(dto.scheduleStart, dto.scheduleEnd),
      category: category,
      categoryIcon: ChallengeCategoryIcon(category: category),
      variant: variant,
      rewardText: variant == ChallengeCardVariant.active
          ? formatRewardText(dto.reward)
          : null,
      completedPoints: completedPoints,
      onTap: dto.ctaLink != null ? () => launchExternalUrl(dto.ctaLink!) : null,
    );
  }
}
