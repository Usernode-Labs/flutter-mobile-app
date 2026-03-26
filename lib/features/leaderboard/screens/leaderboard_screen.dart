import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/widgets/app_card.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/categorized_challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/event_points_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
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

    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    final ranking = ref.watch(rankingProvider.select((s) => s.value));
    final leaderboard = ref.watch(leaderboardProvider.select((s) => s.value));
    final eventPoints = ref.watch(eventPointsProvider.select((s) => s.value));
    final participantId = ref.watch(participantIdProvider).value;
    final categorized = ref.watch(categorizedChallengesProvider);
    ref.watch(seasonsProvider);

    final isLoading = ref.watch(
      leaderboardProvider.select((s) => s.isLoading && s.value == null),
    );
    final hasError = ref.watch(
      leaderboardProvider.select((s) => s.hasError && s.value == null),
    );

    if (isLoading) {
      return const Scaffold(
        // ignore: deprecated_member_use_from_same_package
        body: FullPageLoadingState(),
      );
    }

    if (hasError) {
      return Scaffold(
        body: FullPageErrorState(
          message: AppLocalizations.of(context).leaderboardFailedToLoad,
          onRetry: () => ref.invalidate(leaderboardProvider),
          retryLabel: AppLocalizations.of(context).retry,
        ),
      );
    }

    final spacing = Theme.of(context).extension<AppSpacing>()!;

    final colors = Theme.of(context).colorScheme;
    final radii = Theme.of(context).extension<AppRadii>()!;

    final entries = leaderboard?.allEntries ?? [];
    final isLoadingMore = leaderboard?.isLoadingMore ?? false;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            TopAppBar(
              title: AppLocalizations.of(context).leaderboardTitle,
              onLeadingTap: () => Navigator.of(context).pop(),
            ),

            // Filter chip row
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.space16,
                vertical: spacing.space8,
              ),
              sliver: SliverToBoxAdapter(
                child: DropdownChain(
                  items: [
                    DropdownChainItem(
                      label: seasonLabel(context, ref),
                      onTap: () => showSeasonPicker(context, ref),
                    ),
                    DropdownChainItem(
                      label: eventLabel(context, ref),
                      onTap: () => showEventPicker(context, ref),
                    ),
                  ],
                ),
              ),
            ),

            // Stats card
            SliverPadding(
              padding: EdgeInsets.only(
                left: spacing.space16,
                right: spacing.space16,
                bottom: spacing.space8,
              ),
              sliver: SliverToBoxAdapter(
                child: _buildStatsCard(context, ranking, eventPoints),
              ),
            ),

            // Challenge category tiles
            if (categorized != null)
              SliverPadding(
                padding: EdgeInsets.only(
                  left: spacing.space16,
                  right: spacing.space16,
                  bottom: spacing.space8,
                ),
                sliver: SliverToBoxAdapter(
                  child: _buildCategoryTiles(context, categorized, spacing),
                ),
              ),

            // Participants list card
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: spacing.space16),
              sliver: SliverToBoxAdapter(
                child: AppCard(
                  padding: EdgeInsets.zero,
                  borderRadius: radii.borderRadiusLargeIncreased,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          left: spacing.space16,
                          right: spacing.space16,
                          top: spacing.space16,
                          bottom: spacing.space8,
                        ),
                        child: Text(
                          AppLocalizations.of(context).allParticipants,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      ...entries.map((entry) {
                        final isCurrentUser =
                            participantId != null &&
                            entry.participantId == participantId;
                        final l10n = AppLocalizations.of(context);
                        return ListTile(
                          leading: RankBadge(rank: '${entry.rank}'),
                          title: Text(
                            entry.displayName ??
                                l10n.participantFallbackName(
                                  entry.participantId.toString(),
                                ),
                          ),
                          trailing: Text(
                            l10n.pointsAbbreviated(
                              formatPoints(entry.totalPoints),
                            ),
                          ),
                          tileColor: isCurrentUser
                              ? colors.primaryContainer.withValues(alpha: 0.3)
                              : null,
                        );
                      }),
                      if (isLoadingMore)
                        Padding(
                          padding: EdgeInsets.all(spacing.space16),
                          child: const Center(
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
            SliverToBoxAdapter(child: SizedBox(height: spacing.space32)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(
    BuildContext context,
    RankingResult? ranking,
    EventPointsResult? eventPoints,
  ) {
    final l10n = AppLocalizations.of(context);
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
      calloutTitle = l10n.betterThanPercent(betterThanPercent);
      if (betterThanPercent < 50) {
        calloutBody = l10n.leaderboardClimbEncouragement;
      } else {
        final topPercent = 100 - betterThanPercent;
        calloutBody = l10n.leaderboardTopPercent(topPercent);
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
        return l10n.pointsRangeBucket(formatPoints(lo), formatPoints(hi));
      });
    }

    final userScore = eventPoints?.participantTotalPoints ?? totalPoints;

    return LeaderboardStatsCard(
      totalPoints: totalPoints != null ? formatPoints(totalPoints) : '--',
      totalPointsLabel: l10n.totalPointsLabel,
      rank: rank?.toString() ?? '--',
      rankLabel: l10n.rankLabel,
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
    AppSpacing spacing,
  ) {
    final radii = Theme.of(context).extension<AppRadii>()!;

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

    return AppCard(
      padding: EdgeInsets.zero,
      borderRadius: radii.borderRadiusLargeIncreased,
      child: Column(
        children: [
          for (var i = 0; i < sortedCategories.length; i++) ...[
            _buildCategoryTile(
              context,
              sortedCategories[i],
              grouped[sortedCategories[i]]!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    ChallengeCategory category,
    List<EnrichedChallenge> challenges,
  ) {
    final l10n = AppLocalizations.of(context);
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
      ChallengeCategory.technical => l10n.categoryTechnical,
      ChallengeCategory.community => l10n.categoryCommunity,
      ChallengeCategory.flash => l10n.categoryFlash,
    };

    return ChallengeCategoryTile(
      categoryIcon: ChallengeCategoryIcon(category: category, size: 40),
      categoryName: categoryName,
      remainingCount: remaining.length,
      completedCount: completed.length,
      pointsLabel: l10n.pointsAbbreviated(formatPoints(totalPoints)),
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
