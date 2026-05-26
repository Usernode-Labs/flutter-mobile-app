import 'dart:async';

import 'package:collection/collection.dart';
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
import 'package:crypto_mobile_app/core/services/app_sleep_service.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:crypto_mobile_app/core/providers/syncing_text_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/challenges/heartbeat_animation.dart';
import 'package:crypto_mobile_app/features/challenges/screens/challenges_delegates.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';

/// Immutable pull-to-refresh feedback values for the ScoreHeader.
class PullFeedback {
  final double scale;
  final double offset;
  const PullFeedback({this.scale = 1.0, this.offset = 0.0});

  factory PullFeedback.fromStatus(RefreshIndicatorStatus? status) =>
      switch (status) {
        RefreshIndicatorStatus.drag => const PullFeedback(
            scale: 1.02,
            offset: 8.0,
          ),
        RefreshIndicatorStatus.armed => const PullFeedback(
            scale: 1.04,
            offset: 16.0,
          ),
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
  final _appSleepService = AppSleepService.instance;
  Timer? _refreshTimer;

  final _pullFeedback = ValueNotifier<PullFeedback>(const PullFeedback());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: kTabLabels.length, vsync: this);
    _heartbeat = HeartbeatAnimation(vsync: this);
    _appSleepService.addListener(_handleAppSleepChanged);
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _appSleepService.removeListener(_handleAppSleepChanged);
    _refreshTimer?.cancel();
    _heartbeat.dispose();
    _tabController.dispose();
    _scrollFraction.dispose();
    _pullFeedback.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    if (_appSleepService.isSleeping) return;
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_appSleepService.isSleeping) return;
      if (!mounted) return;
      final currentTab = ref.read(currentHomeTabProvider);
      if (currentTab == HomeTab.challenges) {
        await Future.wait([
          ref.read(challengesProvider.notifier).silentRefresh(),
          ref.read(rankingProvider.notifier).silentRefresh(),
          ref.read(breakdownProvider.notifier).silentRefresh(),
        ]);
      }
    });
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
    _startAutoRefresh();
  }

  void _handleAppSleepChanged() {
    if (!mounted) return;
    if (_appSleepService.isSleeping) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      return;
    }

    _startAutoRefresh();
    unawaited(_onRefresh());
  }

  @override
  Widget build(BuildContext context) {
    // Ensure cold-start context is restored
    ref.watch(leaderboardBootstrapProvider);

    return _buildBody(context);
  }

  /// Custom refresh predicate for NestedScrollView: accepts outer scroll
  /// (depth 0) unconditionally and inner overscroll at the top edge (Android).
  bool _challengesRefreshPredicate(ScrollNotification notification) {
    if (notification.depth == 0) return true;
    // On Android (ClampingScrollPhysics) NestedScrollView dispatches
    // overscroll from the inner body at depth > 0. Accept it only when
    // at the top edge so normal inner-list scroll-up doesn't false-trigger.
    if (notification is OverscrollNotification &&
        notification.metrics.pixels <= 0.0) {
      return true;
    }
    return false;
  }

  Widget _buildBody(BuildContext context) {
    final ranking = ref.watch(rankingProvider.select((s) => s.valueOrNull));
    final breakdown = ref.watch(breakdownProvider.select((s) => s.valueOrNull));
    final eb = breakdown?.eventBreakdown ??
        breakdown?.seasonBreakdown?.events.lastOrNull;
    final isLoading = ref.watch(
      challengesProvider.select((s) => s.isLoading && s.valueOrNull == null),
    );
    final hasError = ref.watch(
      challengesProvider.select((s) => s.hasError && s.valueOrNull == null),
    );

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
          active: [],
          completed: [],
          missed: [],
        );

    // Exclude challenges from active events in the Missed tab — if the event
    // hasn't ended, its challenges aren't truly missed yet.
    final seasons = ref.watch(seasonsProvider).valueOrNull;
    final activeEventIds = seasons
            ?.expand((s) => s.events)
            .where((e) => e.isActive)
            .map((e) => e.id)
            .toSet() ??
        const <int>{};
    final filteredMissed = activeEventIds.isEmpty
        ? categorized.missed
        : categorized.missed
            .where((c) => !activeEventIds.contains(c.dto.eventId))
            .toList();

    final badgeCounts = [
      categorized.active.length,
      categorized.completed.length,
      filteredMissed.length,
    ];

    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Scaffold(
      body: ParallaxSurfaceLayout(
        headerHeight: kScreenHeaderHeight + kPinnedBarPadding,
        scrollFractionNotifier: _scrollFraction,
        onRefresh: _onRefresh,
        onRefreshStatusChange: _onRefreshStatusChange,
        refreshNotificationPredicate: _challengesRefreshPredicate,
        header: _buildHeaderWithPullFeedback(breakdown, ranking, spacing),
        headerOverlay: _buildCtaOverlay(spacing),
        surfacePinnedSlivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: SurfaceTabBarDelegate(
              tabController: _tabController,
              scrollFractionNotifier: _scrollFraction,
              badgeCounts: badgeCounts,
            ),
          ),
        ],
        surfacePinnedHeight: 8.0 + kTabBarHeight,
        nestedBody: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          controller: _tabController,
          children: [
            _buildActiveTabContent(
              categorized.active,
              categorized,
              spacing,
              isLoading: isLoading,
              eb: eb,
              missedOverride: filteredMissed.length,
            ),
            _buildGroupedChallengeList(
              categorized.completed,
              spacing,
              AppLocalizations.of(context).challengeNoCompleted,
              isLoading: isLoading,
              eventBreakdowns: breakdown?.seasonBreakdown?.events ?? const [],
            ),
            _buildGroupedChallengeList(
              filteredMissed,
              spacing,
              AppLocalizations.of(context).challengeNoMissed,
              isLoading: isLoading,
              eventBreakdowns: breakdown?.seasonBreakdown?.events ?? const [],
              showPoints: false,
            ),
          ],
        ),
      ),
    );
  }

  /// Header with PullFeedback scale animation and heartbeat glow.
  Widget _buildHeaderWithPullFeedback(
    BreakdownResult? breakdown,
    RankingResult? ranking,
    AppSpacing spacing,
  ) {
    return ValueListenableBuilder<PullFeedback>(
      valueListenable: _pullFeedback,
      builder: (context, pf, child) {
        return Padding(
          padding: EdgeInsets.only(
            top: pf.offset,
            left: spacing.space16,
            right: spacing.space16,
          ),
          child: AnimatedScale(
            scale: pf.scale,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: child,
          ),
        );
      },
      child: ValueListenableBuilder<GlowValues>(
        valueListenable: _heartbeat.glowValues,
        builder: (context, glow, _) {
          return _buildScoreHeader(breakdown, ranking, glow);
        },
      ),
    );
  }

  /// CTA button overlay — rendered in PSL Layer 3 above the scroll surface.
  /// Uses opaque hit testing so the childless SizedBox accepts taps.
  Widget _buildCtaOverlay(AppSpacing spacing) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: spacing.space24),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push(AppRoutes.leaderboard),
          child: SizedBox(width: 200, height: spacing.space48),
        ),
      ),
    );
  }

  // -- ScoreHeader -----------------------------------------------------------

  /// Current variant for the score header. Will be dynamic when glow is earned.
  ScoreHeaderVariant get _scoreVariant {
    final isComplete = ref.watch(
      zkIdentityIsCompleteProvider.select(
        (v) => v.maybeWhen(data: (d) => d, orElse: () => false),
      ),
    );
    return isComplete ? ScoreHeaderVariant.glow : ScoreHeaderVariant.standard;
  }

  /// Resolves the selected season from provider state. Returns null when
  /// seasons data isn't loaded or the selected season can't be found.
  SeasonDto? _resolveSelectedSeason() {
    final seasons = ref.read(seasonsProvider).valueOrNull;
    final ctx = ref.read(seasonEventContextProvider);
    if (seasons == null || seasons.isEmpty || ctx.seasonId == null) return null;
    return seasons.firstWhereOrNull((s) => s.id == ctx.seasonId);
  }

  /// Resolves start/end dates from the current season.
  ({String? startsAt, String? endsAt}) _resolveDateRange() {
    final season = _resolveSelectedSeason();
    if (season == null) return (startsAt: null, endsAt: null);
    return (startsAt: season.startsAt, endsAt: season.endsAt);
  }

  /// Compute countdown label + time from the resolved end date.
  ({String label, String? time}) _computeCountdown(
      ({String? startsAt, String? endsAt}) range) {
    final endsAtRaw = range.endsAt;
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

  /// Compute time progress as a fraction (0.0 = start, 1.0 = end).
  double _computePhaseProgress(({String? startsAt, String? endsAt}) range) {
    if (range.startsAt == null || range.endsAt == null) return 0.0;

    final start = DateTime.tryParse(range.startsAt!);
    final end = DateTime.tryParse(range.endsAt!);
    if (start == null || end == null) return 0.0;

    final now = DateTime.now().toUtc();
    final total = end.toUtc().difference(start.toUtc()).inSeconds;
    if (total <= 0) return 1.0;

    final elapsed = now.difference(start.toUtc()).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Widget _buildScoreHeader(
    BreakdownResult? breakdown,
    RankingResult? ranking,
    GlowValues glow,
  ) {
    final totalPoints = breakdown?.totalPoints ?? ranking?.totalPoints;
    final rank = ranking?.rank;

    final l10n = AppLocalizations.of(context);
    final score = totalPoints != null ? formatPoints(totalPoints) : '--';
    final rankLabel = rank != null ? l10n.challengeRank(rank) : null;
    final range = _resolveDateRange();
    final progress = _computePhaseProgress(range);

    final countdown = _computeCountdown(range);
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
    EventBreakdown? eb,
    int? missedOverride,
  }) {
    if (isLoading) {
      return _buildShimmerCards(spacing);
    }

    if (active.isNotEmpty) {
      return _buildEnrichedChallengeList(active, spacing, '', eb: eb);
    }

    final completedCount = categorized.completed.length;
    final missedCount = missedOverride ?? categorized.missed.length;
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
    EventBreakdown? eb,
  }) {
    if (isLoading) {
      return _buildShimmerCards(spacing);
    }

    if (challenges.isEmpty) return _buildEmptyTab(emptyMessage);

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      addRepaintBoundaries: false,
      padding: EdgeInsets.all(spacing.space16),
      itemCount: challenges.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.space8),
      itemBuilder: (context, index) => RepaintBoundary(
        key: ValueKey(challenges[index].dto.id),
        child: _buildEnrichedChallengeCard(challenges[index], eb: eb),
      ),
    );
  }

  Widget _buildGroupedChallengeList(
    List<EnrichedChallenge> challenges,
    AppSpacing spacing,
    String emptyMessage, {
    bool isLoading = false,
    List<EventBreakdown> eventBreakdowns = const [],
    bool showPoints = true,
  }) {
    if (isLoading) return _buildShimmerCards(spacing);

    if (challenges.isEmpty) return _buildEmptyTab(emptyMessage);

    final groups = groupByEvent(challenges);

    // Single event — show flat list, no section headers needed.
    if (groups.length == 1) {
      final singleEventBd = groups.first.eventId != null
          ? eventBreakdowns
              .firstWhereOrNull((e) => e.eventId == groups.first.eventId)
          : null;
      return _buildEnrichedChallengeList(
        challenges,
        spacing,
        emptyMessage,
        eb: singleEventBd,
      );
    }

    // Multiple events — one card per event, flat challenge rows inside.
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(spacing.space16),
      itemCount: groups.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.space16),
      itemBuilder: (context, index) {
        final group = groups[index];
        final eventBd = group.eventId != null
            ? eventBreakdowns
                .firstWhereOrNull((e) => e.eventId == group.eventId)
            : null;
        final totalPoints = eventBd?.totalPoints ??
            group.challenges.fold<int>(
              0,
              (sum, c) => sum + (c.earnedPoints ?? 0),
            );
        // Only the first produce-blocks challenge claims event bonuses.
        var bonusesClaimed = false;
        final items = <ChallengeEventItem>[];
        for (final c in group.challenges) {
          final isPB = isProduceBlocksChallenge(c.dto);
          items.add(_mapToEventItem(
            c,
            eventBd: eventBd,
            claimBonuses: isPB && !bonusesClaimed,
          ));
          if (isPB) bonusesClaimed = true;
        }
        return ChallengeEventGroup(
          eventName: group.eventName ?? 'Event',
          dateRange: _formatEventDateRange(group.challenges),
          pointsLabel: showPoints ? '${formatPoints(totalPoints)} pts' : '',
          challenges: items,
        );
      },
    );
  }

  /// Derives a date range label from the first challenge's scheduleStart
  /// to the last challenge's scheduleEnd within an event group.
  String? _formatEventDateRange(List<EnrichedChallenge> challenges) {
    if (challenges.isEmpty) return null;
    final first = challenges.first.dto.scheduleStart;
    final last = challenges.last.dto.scheduleEnd;
    return formatDateRange(first, last);
  }

  ChallengeEventItem _mapToEventItem(
    EnrichedChallenge enriched, {
    EventBreakdown? eventBd,
    required bool claimBonuses,
  }) {
    final dto = enriched.dto;
    final category = mapCategory(dto.category);
    final isProduceBlocks = isProduceBlocksChallenge(dto);
    final variant = mapEnrichedVariant(
      enriched,
      eventSuccessRate: isProduceBlocks ? eventBd?.successRate : null,
    );

    final effectiveEarned = enriched.earnedPoints;
    final bonusPoints =
        (isProduceBlocks && claimBonuses) ? eventBd?.totalBonusPoints ?? 0 : 0;

    String? points;
    if (variant == ChallengeCardVariant.completed &&
        (effectiveEarned != null || bonusPoints > 0)) {
      points = formatEarnedPoints((effectiveEarned ?? 0) + bonusPoints);
    }

    return ChallengeEventItem(
      title: dto.goal,
      category: category,
      variant: variant,
      earnedPoints: points,
      onTap: () {
        context.push(AppRoutes.challengeDetail, extra: enriched);
      },
    );
  }

  Widget _buildEmptyTab(String message) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerCards(AppSpacing spacing) {
    return ShimmerHost(
      child: CustomScrollView(
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
      ),
    );
  }

  Widget _buildEnrichedChallengeCard(
    EnrichedChallenge enriched, {
    EventBreakdown? eb,
  }) {
    final dto = enriched.dto;
    final category = mapCategory(dto.category);
    final isProduceBlocks = isProduceBlocksChallenge(dto);
    final variant = mapEnrichedVariant(
      enriched,
      eventSuccessRate: isProduceBlocks ? eb?.successRate : null,
    );

    // Use API-provided earned points directly (breakdown with include_activity=1).
    final effectiveEarned = enriched.earnedPoints;
    final isSyncing = isProduceBlocksSyncing(
      isProduceBlocks: isProduceBlocks,
      earnedPoints: effectiveEarned,
      successRate: eb?.successRate ?? 0,
    );

    String? completedPoints;
    if (variant == ChallengeCardVariant.completed) {
      completedPoints = effectiveEarned != null
          ? formatEarnedPoints(effectiveEarned)
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
      earnedPoints: variant == ChallengeCardVariant.ongoing
          ? isSyncing
              ? ref.watch(syncingTextProvider).valueOrNull ??
                  kSyncingTextFallback
              : effectiveEarned != null
                  ? formatEarnedPoints(effectiveEarned)
                  : null
          : null,
      completedPoints: completedPoints,
      onTap: () {
        context.push(AppRoutes.challengeDetail, extra: enriched);
      },
    );
  }
}
