import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
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
import 'package:crypto_mobile_app/features/challenges/challenge_presentation_l10n.dart';
import 'package:crypto_mobile_app/features/challenges/season_event_pickers.dart';
import 'package:crypto_mobile_app/features/profile/providers/token_allocation_provider.dart';
import 'package:crypto_mobile_app/features/profile/widgets/profile_leaderboard_list.dart';
import 'package:crypto_mobile_app/features/profile/widgets/token_allocation_gated_notice.dart';

/// "What I earned" surface (#440): points + rank summary over completed
/// challenges and the season leaderboard, with Settings reached from the app
/// bar cog. Pushed from the Challenges top bar's profile action.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(leaderboardBootstrapProvider);

    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);

    ref.watch(seasonsProvider);
    final ranking = ref.watch(rankingProvider.select((s) => s.valueOrNull));
    final totalPoints = ref.watch(
          breakdownProvider.select((s) => s.valueOrNull?.totalPoints),
        ) ??
        ranking?.totalPoints;
    final score = totalPoints != null ? formatPoints(totalPoints) : '--';
    final rankLabel = ranking != null ? l10n.challengeRank(ranking.rank) : null;
    final allocation = ref.watch(tokenAllocationProvider);

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
              title: l10n.profileTitle,
              onLeadingTap: () {
                if (context.canPop()) context.pop();
              },
              backgroundColor: colors.surfaceContainerLowest,
              actions: [
                IconButton(
                  tooltip: l10n.settingsTitle,
                  onPressed: () => context.push(AppRoutes.profileSettings),
                  icon: const Icon(Symbols.settings_sharp),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: colors.surfaceContainerLowest,
                child: ScoreHeader(
                  score: score,
                  scoreLabel: l10n.challengePoints,
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
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                spacing.space16,
                spacing.space12,
                spacing.space16,
                spacing.space16,
              ),
              sliver: SliverToBoxAdapter(
                child: allocation.when(
                  data: (data) {
                    if (data == null) return const SizedBox.shrink();
                    // A gated allocation is forced to 0 by the backend, so the
                    // reveal card would present a withheld balance as a real one.
                    if (!data.termsAccepted) {
                      return TokenAllocationGatedNotice(
                        onReviewTerms: () => context.push(AppRoutes.terms),
                      );
                    }
                    return TokenAllocationReveal(
                      amount: NumberFormat.decimalPattern(
                        Localizations.localeOf(context).toLanguageTag(),
                      ).format(data.amount),
                      label: l10n.profileTokenAllocation,
                      disclaimer: l10n.profileTokenAllocationDisclaimer,
                      revealLabel: l10n.profileRevealTokens,
                      revealed: data.acknowledged,
                      onReveal: () => ref
                          .read(tokenAllocationProvider.notifier)
                          .acknowledge(),
                    );
                  },
                  loading: () => const ShimmerCardSkeleton(),
                  error: (_, __) => Card(
                    child: ListTile(
                      title: Text(l10n.profileTokenAllocationLoadError),
                      trailing: Button(
                        label: l10n.commonRetry,
                        variant: ButtonVariant.outlined,
                        onTap: () {
                          ref.invalidate(rankingProvider);
                          ref.invalidate(tokenAllocationProvider);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _ProfileTabBarDelegate(
                tabs: [
                  Tab(text: l10n.profileCompletedChallengesTab),
                  Tab(text: l10n.leaderboardTitle),
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
                  labels: challengePresentationLabels(l10n),
                ),
                ProfileLeaderboardList(
                  entries: [
                    for (final entry in entries)
                      ProfileLeaderboardEntryData(
                        rank: '${entry.rank}',
                        name: entry.displayName ??
                            l10n.participantFallbackName(
                              entry.participantId.toString(),
                            ),
                        points: l10n.pointsAbbreviated(
                          formatPoints(entry.totalPoints),
                        ),
                        isCurrentUser:
                            entry.participantId == currentParticipantId,
                      ),
                  ],
                  emptyLabel: l10n.profileLeaderboardUnavailable,
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
    required this.labels,
  });

  final List<EnrichedChallenge> challenges;
  final BreakdownResult? breakdown;
  final ChallengePresentationLabels labels;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    if (challenges.isEmpty) {
      return Center(
        child: Text(
          l10n.profileNoCompletedChallengesYet,
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
          labels: labels,
        );
        return AtomicChallengeCard(
          title: card.title,
          leftText: card.leftText,
          rightText: card.rightText,
          phase: card.phase,
          fill: card.fill,
          railTreatment: card.railTreatment,
          cardTreatment: AtomicChallengeCardTreatment.listItem,
          onTap: () => context.push(
            AppRoutes.challengeDetail,
            extra: challenge,
          ),
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
