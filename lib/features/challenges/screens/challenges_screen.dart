import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/categorized_challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
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
                notificationPredicate: (notification) =>
                    notification.depth <= 2,
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
                          _buildEnrichedChallengeList(categorized.active,
                              spacing, 'No active challenges'),
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

  Widget _buildScoreHeader(BreakdownResult? breakdown, RankingResult? ranking) {
    final totalPoints = breakdown?.totalPoints ?? ranking?.totalPoints;
    final rank = breakdown?.eventBreakdown?.rank ?? ranking?.rank;
    final totalParticipants = ranking?.totalParticipants;

    final score = totalPoints != null ? formatPoints(totalPoints) : '--';
    final rankLabel = rank != null ? 'Rank $rank' : null;
    final progress =
        rank != null && totalParticipants != null && totalParticipants > 0
            ? (totalParticipants - rank + 1) / totalParticipants
            : 0.0;

    final glow = _heartbeat.glowValues.value;
    return ScoreHeader(
      score: score,
      scoreLabel: 'points',
      rankLabel: rankLabel,
      progress: progress,
      ctaLabel: 'View in Leaderboard',
      variant: _scoreVariant,
      technicalGlowIntensity: glow.isAnimating ? glow.technical : null,
      flashGlowIntensity: glow.isAnimating ? glow.flash : null,
      communityGlowIntensity: glow.isAnimating ? glow.community : null,
    );
  }

  // -- Challenge lists -------------------------------------------------------

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
      onTap: () => context.push(
        AppRoutes.challengeDetail,
        extra: enriched,
      ),
    );
  }
}
