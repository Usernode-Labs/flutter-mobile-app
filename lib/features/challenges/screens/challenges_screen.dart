import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/categorized_challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
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
  final _scrollFraction = ValueNotifier<double>(0.0);
  late TabController _tabController;
  late final HeartbeatAnimation _heartbeat;

  final _pullFeedback = ValueNotifier<PullFeedback>(const PullFeedback());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: kTabLabels.length, vsync: this);
    _heartbeat = HeartbeatAnimation(vsync: this);
  }

  @override
  void dispose() {
    _heartbeat.dispose();
    _tabController.dispose();
    _scrollFraction.dispose();
    _pullFeedback.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final fraction =
        (notification.metrics.pixels / kScreenHeaderHeight).clamp(0.0, 1.0);
    if (fraction != _scrollFraction.value) {
      _scrollFraction.value = fraction;
    }
    return false;
  }

  void _onRefreshStatusChange(RefreshIndicatorStatus? status) {
    final feedback = PullFeedback.fromStatus(status);
    if (feedback.scale != _pullFeedback.value.scale ||
        feedback.offset != _pullFeedback.value.offset) {
      _pullFeedback.value = feedback;
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

    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    final ranking = ref.watch(rankingProvider.select((s) => s.value?.data));
    final breakdown = ref.watch(breakdownProvider.select((s) => s.value?.data));
    final isLoading = ref.watch(
        challengesProvider.select((s) => s.isLoading && s.value?.data == null));
    final hasError = ref.watch(
        challengesProvider.select((s) => s.hasError && s.value?.data == null));
    // Trigger lazy init so seasons data is available for the pickers.
    ref.watch(seasonsProvider);

    if (hasError) {
      return Scaffold(
        body: FullPageErrorState(
          message: AppLocalizations.of(context).challengeFailedToLoad,
          onRetry: () => ref.invalidate(challengesProvider),
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
            ValueListenableBuilder<double>(
              valueListenable: _scrollFraction,
              builder: (context, sf, pullAndGlow) {
                return ValueListenableBuilder<PullFeedback>(
                  valueListenable: _pullFeedback,
                  builder: (context, pf, scoreHeader) {
                    return Transform.translate(
                      offset: Offset(
                        0,
                        -sf * kScreenHeaderHeight * kParallaxRatio + pf.offset,
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: safeTop +
                              spacing.space8 +
                              kChipHeight +
                              spacing.space8,
                          left: spacing.space16,
                          right: spacing.space16,
                        ),
                        child: AnimatedScale(
                          scale: pf.scale,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: scoreHeader,
                        ),
                      ),
                    );
                  },
                  child: pullAndGlow,
                );
              },
              child: ValueListenableBuilder<GlowValues>(
                valueListenable: _heartbeat.glowValues,
                builder: (context, glow, _) {
                  return _buildScoreHeader(breakdown, ranking, glow);
                },
              ),
            ),

            // Layer 2 — scrolling surface
            NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: RefreshIndicator.noSpinner(
                notificationPredicate: (notification) {
                  // Accept outer scroll (depth 0) unconditionally.
                  if (notification.depth == 0) return true;
                  // On Android (ClampingScrollPhysics) NestedScrollView
                  // dispatches overscroll from the inner body at depth > 0.
                  // Accept it only when at the top edge so normal inner-
                  // list scroll-up doesn't false-trigger.
                  if (notification is OverscrollNotification &&
                      notification.metrics.pixels <= 0.0) {
                    return true;
                  }
                  return false;
                },
                onRefresh: _onRefresh,
                onStatusChange: _onRefreshStatusChange,
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      // Pinned chip bar
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: ChipBarDelegate(
                          topPadding: safeTop,
                          spacing: spacing,
                          scrollFractionNotifier: _scrollFraction,
                          onSeasonTap: () => showSeasonPicker(context, ref),
                          onEventTap: () => showEventPicker(context, ref),
                          seasonLabel: seasonLabel(context, ref),
                          eventLabel: eventLabel(context, ref),
                        ),
                      ),
                      // Transparent spacer revealing ScoreHeader.
                      // The CTA button is rendered visually by ScoreHeader
                      // in Layer 1, but that layer sits behind the scroll
                      // surface and can't receive taps. This invisible tap
                      // target overlays the button's position so taps land
                      // in Layer 2 directly.
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: kScreenHeaderHeight,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: spacing.space24),
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: () =>
                                    context.push(AppRoutes.leaderboard),
                                child: SizedBox(
                                    width: 200, height: spacing.space48),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Pinned surface tab bar
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: SurfaceTabBarDelegate(
                          tabController: _tabController,
                          scrollFractionNotifier: _scrollFraction,
                          badgeCounts: badgeCounts,
                        ),
                      ),
                    ];
                  },
                  body: ColoredBox(
                    color: colors.surfaceContainerLowest,
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      controller: _tabController,
                      children: [
                        _buildActiveTabContent(
                            categorized.active, categorized, spacing,
                            isLoading: isLoading),
                        _buildEnrichedChallengeList(
                            categorized.completed,
                            spacing,
                            AppLocalizations.of(context).challengeNoCompleted,
                            isLoading: isLoading),
                        _buildEnrichedChallengeList(categorized.missed, spacing,
                            AppLocalizations.of(context).challengeNoMissed,
                            isLoading: isLoading),
                      ],
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

  Widget _buildScoreHeader(
      BreakdownResult? breakdown, RankingResult? ranking, GlowValues glow) {
    final totalPoints = breakdown?.totalPoints ?? ranking?.totalPoints;
    final rank = breakdown?.eventBreakdown?.rank ?? ranking?.rank;

    final l10n = AppLocalizations.of(context);
    final score = totalPoints != null ? formatPoints(totalPoints) : '--';
    final rankLabel = rank != null ? l10n.challengeRank(rank) : null;
    final progress = _computePhaseProgress();

    final countdown = _computeCountdown();
    return ScoreHeader(
      score: score,
      scoreLabel: l10n.challengePoints,
      rankLabel: rankLabel,
      progress: progress,
      countdownLabel: countdown.label,
      countdownTime: countdown.time,
      ctaLabel: l10n.challengeViewInLeaderboard,
      onCtaTap: () => context.push(AppRoutes.leaderboard),
      variant: _scoreVariant,
      technicalGlowIntensity: glow.isAnimating ? glow.technical : null,
      flashGlowIntensity: glow.isAnimating ? glow.flash : null,
      communityGlowIntensity: glow.isAnimating ? glow.community : null,
      countdownOpacity: glow.countdownOpacity,
      countdownTextMode: glow.countdownTextMode,
    );
  }

  // -- Challenge lists -------------------------------------------------------

  Widget _buildActiveTabContent(
    List<EnrichedChallenge> active,
    CategorizedEnrichedChallenges categorized,
    AppSpacing spacing, {
    bool isLoading = false,
  }) {
    if (isLoading) {
      return _buildShimmerCards(spacing);
    }

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
    String emptyMessage, {
    bool isLoading = false,
  }) {
    if (isLoading) {
      return _buildShimmerCards(spacing);
    }

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
      addRepaintBoundaries: false,
      padding: EdgeInsets.all(spacing.space16),
      itemCount: challenges.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.space12),
      itemBuilder: (context, index) => RepaintBoundary(
        key: ValueKey(challenges[index].dto.id),
        child: _buildEnrichedChallengeCard(challenges[index]),
      ),
    );
  }

  Widget _buildShimmerCards(AppSpacing spacing) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(spacing.space16),
          sliver: SliverList.separated(
            itemCount: 3,
            separatorBuilder: (_, __) => SizedBox(height: spacing.space12),
            itemBuilder: (_, __) => const ShimmerCardSkeleton(),
          ),
        ),
      ],
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
      categoryIcon: ChallengeCategoryIcon(
        category: category,
        muted: variant == ChallengeCardVariant.missed,
      ),
      variant: variant,
      rewardText: variant == ChallengeCardVariant.active
          ? formatRewardText(dto.reward)
          : null,
      completedPoints: completedPoints,
      onTap: () => context.push(
        AppRoutes.challengeDetail,
        extra: enriched,
      ),
    );
  }
}
