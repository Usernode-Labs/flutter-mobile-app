import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/categorized_challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/event_points_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_card.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_category_icon.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_category_tile.dart';
import 'package:crypto_mobile_app/design_system/src/dropdown_chain.dart';
import 'package:crypto_mobile_app/design_system/src/leaderboard_stats_card.dart';
import 'package:crypto_mobile_app/design_system/src/rank_badge.dart';
import 'package:crypto_mobile_app/design_system/src/top_app_bar.dart';
import 'package:crypto_mobile_app/design_system/theme/color_is_expensive_theme.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/challenges/season_event_pickers.dart';
import 'package:crypto_mobile_app/features/leaderboard/leaderboard_distribution.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 200) {
      ref.read(leaderboardProvider.notifier).loadNextPage();
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      ref.read(leaderboardProvider.notifier).silentRefresh(),
      ref.read(rankingProvider.notifier).silentRefresh(),
      ref.read(eventPointsProvider.notifier).silentRefresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(leaderboardBootstrapProvider);

    final textTheme = Theme.of(context).textTheme;

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
    final ranking = ref.watch(rankingProvider.select((s) => s.value?.data));
    final leaderboard = ref.watch(leaderboardProvider.select((s) => s.value));
    final eventPoints =
        ref.watch(eventPointsProvider.select((s) => s.value?.data));
    final participantId = ref.watch(participantIdProvider).value;
    final categorized = ref.watch(categorizedChallengesProvider);
    ref.watch(seasonsProvider);

    final isLoading = ref.watch(leaderboardProvider
        .select((s) => s.isLoading && s.value?.data == null));
    final hasError = ref.watch(
        leaderboardProvider.select((s) => s.hasError && s.value?.data == null));

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
                'Failed to load leaderboard',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(leaderboardProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;

    final entries = leaderboard?.data.allEntries ?? [];
    final isLoadingMore = leaderboard?.data.isLoadingMore ?? false;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            TopAppBar(
              title: 'Leaderboard',
              onLeadingTap: () => Navigator.of(context).pop(),
            ),

            // Filter chip row
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.space16,
                  vertical: spacing.space8,
                ),
                child: DropdownChain(
                  items: [
                    DropdownChainItem(
                      label: seasonLabel(ref),
                      onTap: () => showSeasonPicker(context, ref),
                    ),
                    DropdownChainItem(
                      label: eventLabel(ref),
                      onTap: () => showEventPicker(context, ref),
                    ),
                  ],
                ),
              ),
            ),

            // Stats card
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.space16),
                child: _buildStatsCard(ranking, eventPoints),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: spacing.space16),
            ),

            // Challenge category tiles
            if (categorized != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing.space16),
                  child: _buildCategoryTiles(
                    context,
                    categorized,
                    colors,
                    spacing,
                    radii,
                  ),
                ),
              ),

            if (categorized != null)
              SliverToBoxAdapter(
                child: SizedBox(height: spacing.space16),
              ),

            // Participants list card
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.space16),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLowest,
                    borderRadius: radii.borderRadiusLargeIncreased,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          left: spacing.space16,
                          top: spacing.space16,
                          bottom: spacing.space8,
                        ),
                        child: Text(
                          'All Participants',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      ...entries.map((entry) {
                        final isCurrentUser = participantId != null &&
                            entry.participantId == participantId;
                        return ListTile(
                          leading: RankBadge(rank: '${entry.rank}'),
                          title: Text(
                            entry.displayName ??
                                'Participant ${entry.participantId}',
                          ),
                          trailing: Text(
                            '${formatPoints(entry.totalPoints)} pts',
                          ),
                          tileColor: isCurrentUser
                              ? colors.primaryContainer.withValues(alpha: 0.3)
                              : null,
                          onTap: () {},
                        );
                      }),
                      if (isLoadingMore)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      SizedBox(height: spacing.space8),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom padding
            SliverToBoxAdapter(
              child: SizedBox(height: spacing.space32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(
    RankingResult? ranking,
    EventPointsResult? eventPoints,
  ) {
    final totalPoints = ranking?.totalPoints;
    final rank = ranking?.rank;
    final totalParticipants = ranking?.totalParticipants ?? 0;

    final allPoints = eventPoints?.totalPointsPerUser ?? [];
    final bucketCount = computeAdaptiveBucketCount(allPoints.length);
    final distributionCounts = computeDistributionCounts(
      allPoints,
      bucketCount: bucketCount,
    );
    final userBucketIndex = computeUserBarIndex(
      eventPoints?.participantTotalPoints ?? totalPoints,
      allPoints,
      bucketCount: bucketCount,
    );
    final (minPts, maxPts) = computeDistributionRange(allPoints);

    final betterThanPercent = (rank != null && totalParticipants > 0)
        ? ((totalParticipants - rank) / totalParticipants * 100).round()
        : null;

    String? calloutTitle;
    String? calloutBody;
    if (betterThanPercent != null) {
      calloutTitle = 'Better than $betterThanPercent% of participants';
      if (betterThanPercent < 50) {
        calloutBody =
            'Keep completing tasks to climb higher on the leaderboard.';
      } else {
        final topPercent = 100 - betterThanPercent;
        calloutBody =
            "You're in the top $topPercent%! Keep completing challenges to secure your position.";
      }
    }

    List<String>? bucketScoreLabels;
    if (allPoints.isNotEmpty && minPts != maxPts) {
      final bucketWidth = (maxPts - minPts) / bucketCount;
      bucketScoreLabels = List.generate(bucketCount, (i) {
        final lo = (minPts + i * bucketWidth).round();
        final hi = i == bucketCount - 1
            ? maxPts
            : (minPts + (i + 1) * bucketWidth).round();
        return '${formatPoints(lo)}–${formatPoints(hi)} pts';
      });
    }

    final userScore = eventPoints?.participantTotalPoints ?? totalPoints;

    return LeaderboardStatsCard(
      totalPoints: totalPoints != null ? formatPoints(totalPoints) : '--',
      totalPointsLabel: 'TOTAL POINTS',
      rank: rank?.toString() ?? '--',
      rankLabel: 'RANK',
      distributionCounts: distributionCounts,
      userBucketIndex: userBucketIndex,
      minScoreLabel: allPoints.isNotEmpty ? formatPoints(minPts) : null,
      userScoreLabel: userScore != null ? formatPoints(userScore) : null,
      maxScoreLabel: allPoints.isNotEmpty ? formatPoints(maxPts) : null,
      calloutTitle: calloutTitle,
      calloutBody: calloutBody,
      bucketScoreLabels: bucketScoreLabels,
    );
  }

  Widget _buildCategoryTiles(
    BuildContext context,
    CategorizedEnrichedChallenges categorized,
    ColorScheme colors,
    AppSpacing spacing,
    AppRadii radii,
  ) {
    final allChallenges = [
      ...categorized.active,
      ...categorized.completed,
      ...categorized.missed,
    ];

    final grouped = <ChallengeCategory, List<EnrichedChallenge>>{};
    for (final c in allChallenges) {
      final cat = mapCategory(c.dto.category);
      (grouped[cat] ??= []).add(c);
    }

    if (grouped.isEmpty) return const SizedBox.shrink();

    final sortedCategories = [
      ChallengeCategory.technical,
      ChallengeCategory.community,
      ChallengeCategory.flash,
    ].where(grouped.containsKey).toList();

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: radii.borderRadiusLargeIncreased,
      ),
      padding: EdgeInsets.symmetric(vertical: spacing.space8),
      child: Column(
        children: [
          for (var i = 0; i < sortedCategories.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: colors.surfaceContainerHighest),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.space16),
              child: _buildCategoryTile(
                sortedCategories[i],
                grouped[sortedCategories[i]]!,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    ChallengeCategory category,
    List<EnrichedChallenge> challenges,
  ) {
    final remaining = challenges.where((c) => !c.participantCompleted).toList();
    final completed = challenges.where((c) => c.participantCompleted).toList();

    var totalPoints = 0;
    for (final c in completed) {
      totalPoints += c.earnedPoints ?? int.tryParse(c.dto.reward) ?? 0;
    }
    for (final c in remaining) {
      totalPoints += int.tryParse(c.dto.reward) ?? 0;
    }

    final categoryName = switch (category) {
      ChallengeCategory.technical => 'Technical',
      ChallengeCategory.community => 'Community',
      ChallengeCategory.flash => 'Flash',
    };

    return ChallengeCategoryTile(
      categoryIcon: ChallengeCategoryIcon(category: category, size: 40),
      categoryName: categoryName,
      remainingCount: remaining.length,
      completedCount: completed.length,
      pointsLabel: '${formatPoints(totalPoints)} pts',
      challenges: [
        for (final c in completed)
          ChallengeCategoryItem(
            title: c.dto.goal,
            isCompleted: true,
            onTap: () => context.push(AppRoutes.challengeDetail, extra: c),
          ),
        for (final c in remaining)
          ChallengeCategoryItem(
            title: c.dto.goal,
            isCompleted: false,
            onTap: () => context.push(AppRoutes.challengeDetail, extra: c),
          ),
      ],
    );
  }
}
