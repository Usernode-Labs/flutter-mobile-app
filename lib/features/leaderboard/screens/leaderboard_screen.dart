import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/event_points_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
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
                          leading: RankBadge(rank: '#${entry.rank}'),
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
    final distribution = computeDistribution(allPoints);
    final userBarIndex = computeUserBarIndex(
      eventPoints?.participantTotalPoints ?? totalPoints,
      allPoints,
    );

    final betterThanPercent = (rank != null && totalParticipants > 0)
        ? ((totalParticipants - rank) / totalParticipants * 100).round()
        : null;
    final tooltipText = betterThanPercent != null
        ? 'Better than $betterThanPercent% of participants.'
        : null;

    return LeaderboardStatsCard(
      totalPoints: totalPoints != null ? formatPoints(totalPoints) : '--',
      totalPointsLabel: 'TOTAL POINTS',
      rank: rank?.toString() ?? '--',
      rankLabel: 'RANK',
      distribution: distribution,
      userBarIndex: userBarIndex,
      tooltipText: tooltipText,
    );
  }
}
