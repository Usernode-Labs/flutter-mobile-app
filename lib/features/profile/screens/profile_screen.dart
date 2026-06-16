import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/categorized_challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_presentation.dart';

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
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    final ranking = ref.watch(rankingProvider.select((s) => s.valueOrNull));
    final totalPoints = ref.watch(
          breakdownProvider.select((s) => s.valueOrNull?.totalPoints),
        ) ??
        ranking?.totalPoints;
    final score = totalPoints != null ? formatPoints(totalPoints) : '--';
    final rankLabel = ranking != null ? 'Rank ${ranking.rank}' : null;

    final completed = ref.watch(
          categorizedChallengesProvider.select((c) => c?.completed),
        ) ??
        const <EnrichedChallenge>[];
    final progressById = ref.watch(
      breakdownProvider.select((s) {
        final list = s.valueOrNull?.challengeProgress;
        return (list == null || list.isEmpty)
            ? null
            : {for (final p in list) p.challengeId: p};
      }),
    );

    final entries = ref.watch(
          leaderboardProvider.select((s) => s.valueOrNull?.allEntries),
        ) ??
        const <LeaderboardEntry>[];

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      body: CustomScrollView(
        slivers: [
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
          SliverFillRemaining(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: colors.surfaceContainerLowest,
                  child: ScoreHeader(
                    score: score,
                    scoreLabel: 'points',
                    rankLabel: rankLabel,
                    showCountdown: false,
                    density: ScoreHeaderDensity.compact,
                  ),
                ),
                Expanded(
                  child: ColoredBox(
                    color: colors.surfaceContainerLowest,
                    child: Tabs(
                      tabs: const [
                        TabItem(label: 'Completed Challenges'),
                        TabItem(label: 'Leaderboard'),
                      ],
                      children: [
                        _CompletedChallengesTab(
                          challenges: completed,
                          progressById: progressById,
                        ),
                        _LeaderboardTab(entries: entries),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: spacing.space32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedChallengesTab extends StatelessWidget {
  const _CompletedChallengesTab({
    required this.challenges,
    required this.progressById,
  });

  final List<EnrichedChallenge> challenges;
  final Map<int, ChallengeProgress>? progressById;

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
      padding: EdgeInsets.symmetric(
        horizontal: spacing.space16,
        vertical: spacing.space12,
      ),
      itemCount: challenges.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.space8),
      itemBuilder: (context, index) {
        final card = mapToAtomicCard(
          challenges[index],
          progress: progressById?[challenges[index].dto.id],
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

class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;

    if (entries.isEmpty) {
      return Center(
        child: Text(
          'Leaderboard unavailable.',
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.space16,
        vertical: spacing.space12,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.space4),
      itemBuilder: (context, index) => _LeaderboardRow(entry: entries[index]),
    );
  }
}

class _LeaderboardRow extends ConsumerWidget {
  const _LeaderboardRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final opacity = Theme.of(context).extension<AppOpacity>()!;
    final textTheme = Theme.of(context).textTheme;

    final currentParticipant =
        ref.watch(participantIdProvider.select((p) => p.valueOrNull));
    final isCurrentUser = entry.participantId == currentParticipant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isCurrentUser
            ? colors.primaryContainer.withValues(alpha: opacity.strong)
            : Colors.transparent,
        borderRadius: radii.borderRadiusLargeIncreased,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.space16,
          vertical: spacing.space8,
        ),
        child: Row(
          children: [
            RankBadge(rank: '${entry.rank}'),
            SizedBox(width: spacing.space16),
            Expanded(
              child: Text(
                entry.displayName ?? 'Participant ${entry.participantId}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium,
              ),
            ),
            SizedBox(width: spacing.space16),
            Text(
              '${formatPoints(entry.totalPoints)} pts',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
