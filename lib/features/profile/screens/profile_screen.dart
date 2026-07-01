import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/profile_completed_challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_presentation.dart';
import 'package:crypto_mobile_app/features/challenges/season_event_pickers.dart';
import 'package:crypto_mobile_app/features/profile/widgets/profile_leaderboard_list.dart';

/// "What I earned" surface (#440): points + rank summary over completed
/// challenges and the season leaderboard, with Settings reached from the app
/// bar cog. Pushed from the Challenges top bar's profile action.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  /// Route path used by the Settings cog (kept as a literal so this screen
  /// stays free of the router import).
  static const String _settingsPath = '/profile/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(leaderboardBootstrapProvider);

    final colors = Theme.of(context).colorScheme;

    ref.watch(seasonsProvider);
    final ranking = ref.watch(rankingProvider.select((s) => s.valueOrNull));
    final totalPoints = ref.watch(
          breakdownProvider.select((s) => s.valueOrNull?.totalPoints),
        ) ??
        ranking?.totalPoints;
    final score = totalPoints != null ? formatPoints(totalPoints) : '--';
    final rankLabel = ranking != null ? 'Rank ${ranking.rank}' : null;

    final completedHistory = ref.watch(
      profileCompletedChallengesProvider.select((s) => s.valueOrNull),
    );
    final completed =
        completedHistory?.completed ?? const <EnrichedChallenge>[];
    final completedBreakdown = completedHistory?.breakdown;

    final entries = ref.watch(
          leaderboardProvider.select((s) => s.valueOrNull?.allEntries),
        ) ??
        const <LeaderboardEntry>[];
    final currentParticipantId =
        ref.watch(participantIdProvider.select((p) => p.valueOrNull));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.surfaceContainerLowest,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            TopAppBar(
              title: 'Profile',
              onLeadingTap: () {
                if (context.canPop()) context.pop();
              },
              backgroundColor: colors.surfaceContainerLowest,
              actions: [
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => context.push(_settingsPath),
                  icon: const Icon(Symbols.settings_sharp),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: colors.surfaceContainerLowest,
                child: ScoreHeader(
                  score: score,
                  scoreLabel: 'points',
                  rankLabel: rankLabel,
                  showCountdown: false,
                  density: ScoreHeaderDensity.compact,
                  footer: Center(
                    child: DropdownChip(
                      label: seasonLabel(context, ref),
                      variant: ChipVariant.outlined,
                      onTap: () => showSeasonPicker(context, ref),
                    ),
                  ),
                ),
              ),
            ),
            const SliverPersistentHeader(
              pinned: true,
              delegate: _ProfileTabBarDelegate(
                tabs: [
                  Tab(text: 'Completed Challenges'),
                  Tab(text: 'Leaderboard'),
                ],
              ),
            ),
          ],
          body: ColoredBox(
            color: colors.surfaceContainerLowest,
            child: TabBarView(
              children: [
                _CompletedChallengesTab(
                  challenges: completed,
                  breakdown: completedBreakdown,
                ),
                ProfileLeaderboardList(
                  entries: [
                    for (final entry in entries)
                      ProfileLeaderboardEntryData(
                        rank: '${entry.rank}',
                        name: entry.displayName ??
                            'Participant ${entry.participantId}',
                        points: '${formatPoints(entry.totalPoints)} pts',
                        isCurrentUser:
                            entry.participantId == currentParticipantId,
                      ),
                  ],
                  emptyLabel: 'Leaderboard unavailable.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileTabBarDelegate({
    required this.tabs,
  });

  final List<Widget> tabs;

  @override
  double get minExtent => kTextTabBarHeight;

  @override
  double get maxExtent => kTextTabBarHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final borders = Theme.of(context).extension<AppBorders>()!;

    return ColoredBox(
      color: colors.surfaceContainerLowest,
      child: TabBar(
        labelColor: colors.onSurface,
        unselectedLabelColor: colors.outline,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.titleSmall,
        indicatorColor: colors.primary,
        indicatorWeight: 3,
        dividerColor: colors.onSurface.withValues(alpha: borders.opacity),
        dividerHeight: borders.width,
        tabs: tabs,
      ),
    );
  }

  @override
  bool shouldRebuild(_ProfileTabBarDelegate oldDelegate) {
    return oldDelegate.tabs != tabs;
  }
}

class _CompletedChallengesTab extends StatelessWidget {
  const _CompletedChallengesTab({
    required this.challenges,
    required this.breakdown,
  });

  final List<EnrichedChallenge> challenges;
  final BreakdownResult? breakdown;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;

    if (challenges.isEmpty) {
      return Center(
        child: Text(
          'No completed challenges yet.',
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        spacing.space16,
        spacing.space12,
        spacing.space16,
        spacing.space32,
      ),
      itemCount: challenges.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.space8),
      itemBuilder: (context, index) {
        final challenge = challenges[index];
        final progress = _profileCompletedProgress(challenge, breakdown);
        final card = mapToAtomicCard(
          challenge,
          progress: progress,
          technicalSuccessRate: _profileTechnicalSuccessRate(
            challenge,
            breakdown,
          ),
        );
        return AtomicChallengeCard(
          title: card.title,
          leftText: card.leftText,
          rightText: card.rightText,
          phase: card.phase,
          fill: card.fill,
          railTreatment: card.railTreatment,
          cardTreatment: AtomicChallengeCardTreatment.listItem,
          onTap: () {},
        );
      },
    );
  }
}

double? _profileTechnicalSuccessRate(
  EnrichedChallenge challenge,
  BreakdownResult? breakdown,
) {
  if (!isProduceBlocksChallenge(challenge.dto) || breakdown == null) {
    return null;
  }
  final eventId = challenge.dto.eventId;
  if (eventId == null) return null;
  for (final event in _profileBreakdownEvents(breakdown)) {
    if (event.eventId == eventId) return event.successRate;
  }
  return null;
}

Iterable<EventBreakdown> _profileBreakdownEvents(BreakdownResult breakdown) {
  final event = breakdown.eventBreakdown;
  if (event != null) return [event];
  final season = breakdown.seasonBreakdown;
  if (season != null) return season.events;
  return breakdown.globalSeasons.expand((season) => season.events);
}

ChallengeProgress? _profileCompletedProgress(
  EnrichedChallenge challenge,
  BreakdownResult? breakdown,
) {
  final progress = breakdown?.progressForChallenge(challenge.dto);
  final earnedPoints = progress?.earnedPoints ?? challenge.displayEarnedPoints;
  if (earnedPoints == null || earnedPoints <= 0) return progress;

  if (progress == null) {
    return ChallengeProgress(
      challengeId: challenge.dto.id,
      state: ChallengeProgressState.earned,
      earnedPoints: earnedPoints,
    );
  }

  if (progress.state == ChallengeProgressState.earned) return progress;
  return ChallengeProgress(
    challengeId: progress.challengeId,
    state: ChallengeProgressState.earned,
    current: progress.current,
    target: progress.target,
    pendingPoints: progress.pendingPoints,
    earnedPoints: progress.earnedPoints,
    description: progress.description,
  );
}
