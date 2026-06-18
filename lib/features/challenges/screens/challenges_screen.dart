import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/providers/challenge_bands_provider.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/providers/top_status_node_status_provider.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_presentation.dart';

/// The Fair Rewards Challenges surface: a top status bar (profile + node entry
/// points) over perceived-time bands of atomic challenge cards.
///
/// Deadline-grouped challenge stream. Cards route attention; the task/CTA live
/// on the detail screen.
class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Restore cold-start season/participant context.
    ref.watch(leaderboardBootstrapProvider);

    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);

    final hasError = ref.watch(
      challengesProvider.select((s) => s.hasError && s.valueOrNull == null),
    );
    final result = ref.watch(challengeBandsProvider);

    final points = ref.watch(
          breakdownProvider.select((s) => s.valueOrNull?.totalPoints),
        ) ??
        ref.watch(rankingProvider.select((s) => s.valueOrNull?.totalPoints));
    final profileLabel =
        points != null ? '${formatPoints(points)} pts' : l10n.navChallenges;
    final title = ref.watch(
          seasonEventContextProvider.select((c) => c.seasonName),
        ) ??
        l10n.navChallenges;

    final nodeStatus = ref.watch(topStatusNodeStatusProvider);

    return Scaffold(
      // No backgroundColor override → DS scaffold grey (surface). Top-level
      // tab roots share this substrate; nested pages use white surfaces.
      // SafeArea/top inset is owned by TopStatusAppBar.large; adding one here
      // would double-inset the pinned header.
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          slivers: [
            TopStatusAppBar.large(
              title: title,
              profileLabel: profileLabel,
              nodeStatus: nodeStatus,
              onProfilePressed: () => context.push(AppRoutes.profile),
              onNodePressed: () => context.push(AppRoutes.mainNode),
            ),
            if (hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: FullPageErrorState(
                  message: l10n.challengeFailedToLoad,
                  onRetry: () => ref.invalidate(challengesProvider),
                ),
              )
            else if (result == null)
              _LoadingSliver(spacing: spacing)
            else if (result.bands.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    // TODO(fair-rewards): add a localized challengeNoActive key.
                    'No active challenges right now.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  spacing.space16,
                  0,
                  spacing.space16,
                  spacing.space32,
                ),
                sliver: SliverList.separated(
                  itemCount: result.bands.length,
                  separatorBuilder: (_, __) =>
                      SizedBox(height: spacing.space12),
                  itemBuilder: (context, index) => _ChallengeBandSection(
                    band: result.bands[index],
                    onCardTap: (id) {
                      final challenge = result.byId[id];
                      if (challenge != null) {
                        context.push(
                          AppRoutes.challengeDetail,
                          extra: challenge,
                        );
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait([
      ref.read(challengesProvider.notifier).silentRefresh(),
      ref.read(breakdownProvider.notifier).silentRefresh(),
      ref.read(rankingProvider.notifier).silentRefresh(),
    ]);
  }
}

class _LoadingSliver extends StatelessWidget {
  const _LoadingSliver({required this.spacing});

  final AppSpacing spacing;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        spacing.space16,
        0,
        spacing.space16,
        spacing.space32,
      ),
      sliver: SliverToBoxAdapter(
        child: ShimmerHost(
          child: Column(
            children: [
              for (var i = 0; i < 3; i++) ...[
                const ShimmerCardSkeleton(),
                SizedBox(height: spacing.space12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One perceived-time band: a titled container holding atomic challenge cards.
class _ChallengeBandSection extends StatelessWidget {
  const _ChallengeBandSection({required this.band, required this.onCardTap});

  final ChallengeBand band;
  final void Function(int challengeId) onCardTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final textTheme = Theme.of(context).textTheme;
    final isFeatured = band.title == 'Featured';
    final background = isFeatured
        ? semantic.premium.colorSurface
        : colors.surfaceContainerLowest;
    final foreground =
        isFeatured ? semantic.premium.onColorSurface : colors.onSurfaceVariant;

    return Material(
      color: background,
      borderRadius: radii.borderRadiusLargeIncreased,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.space16,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    band.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(color: foreground),
                  ),
                ),
                if (band.deadlineText != null) ...[
                  SizedBox(width: spacing.space12),
                  Text(
                    band.deadlineText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spacing.space8,
              children: [
                for (final card in band.cards)
                  AtomicChallengeCard(
                    title: card.title,
                    leftText: card.leftText,
                    rightText: card.rightText,
                    phase: card.phase,
                    fill: card.fill,
                    featured: card.featured,
                    railTreatment: card.railTreatment,
                    cardTreatment: AtomicChallengeCardTreatment.listItem,
                    onTap: () => onCardTap(card.challengeId),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
