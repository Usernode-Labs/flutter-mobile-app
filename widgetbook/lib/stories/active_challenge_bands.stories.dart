import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';

import 'atomic_challenge_card.stories.dart';

part 'active_challenge_bands.stories.g.dart';

const meta = Meta<ActiveChallengeBands>(path: 'challenges');

final _seasonPreviewNow = DateTime(2026, 2, 21, 9);
final _seasonPreviewEndsAt = DateTime(2026, 6, 30);
const _seasonPreviewParticipants = '159 participants';

final $Default = _Story(
  name: 'Default',
  setup: (context, child, args) {
    return SizedBox(width: 390, height: 844, child: child);
  },
  scenarios: [_Scenario(name: 'Perceived time bands')],
);

/// Widgetbook-only preview of the active Fair Rewards challenge surface.
///
/// Deadlines live at the band layer; atomic cards stay focused on progress and
/// reward state.
class ActiveChallengeBands extends StatelessWidget {
  const ActiveChallengeBands({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLow,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: spacing.space16),
          children: [
            SizedBox(height: spacing.space16),
            const _SeasonSummary(),
            SizedBox(height: spacing.space24),
            const _ChallengeBands(),
            SizedBox(height: spacing.space24),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: 0,
        onItemSelected: (_) {},
        items: [
          BottomNavItem(
            icon: Symbols.cards_star_sharp,
            label: 'Challenges',
            indicatorShape: NavIndicatorShape.circle,
            indicatorColor: colors.onSurface,
            indicatorFillColor: semantic.premium.colorContainer,
          ),
          const BottomNavItem(
            icon: Symbols.action_key_sharp,
            label: 'Apps',
            indicatorShape: NavIndicatorShape.circle,
          ),
          const BottomNavItem(
            icon: Symbols.account_balance_wallet_sharp,
            label: 'Wallet',
            indicatorShape: NavIndicatorShape.circle,
          ),
          const BottomNavItem(
            icon: Symbols.check_circle_sharp,
            label: 'Node',
            indicatorShape: NavIndicatorShape.circle,
          ),
          const BottomNavItem(
            icon: Symbols.settings_sharp,
            label: 'Settings',
            indicatorShape: NavIndicatorShape.circle,
          ),
        ],
      ),
    );
  }
}

class _SeasonSummary extends StatelessWidget {
  const _SeasonSummary();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;
    final seasonRemainingLabel = _formatRemainingTime(
      _seasonPreviewEndsAt.difference(_seasonPreviewNow),
      prefix: 'Ends in ',
      compact: true,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Season 1',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.displaySmall?.copyWith(
            color: colors.onSurface,
            fontFamily: kMonoFontFamily,
          ),
        ),
        SizedBox(height: spacing.space8),
        Text(
          '$_seasonPreviewParticipants · $seasonRemainingLabel',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ChallengeBands extends StatelessWidget {
  const _ChallengeBands();

  @override
  Widget build(BuildContext context) {
    final seasonRemainingLabel = _formatRemainingTime(
      _seasonPreviewEndsAt.difference(_seasonPreviewNow),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ChallengeBandPreview(
          title: 'Featured',
          children: [
            AtomicChallengeCard(
              title: 'Propose an app change',
              leftText: '0 / 1',
              rightText: '500 pts',
              phase: AtomicChallengePhase.open,
              fill: 0,
              featured: true,
              cardTreatment: AtomicChallengeCardTreatment.listItem,
              onTap: _noop,
            ),
          ],
        ),
        const _ChallengeBandPreview(
          title: 'Today',
          deadlineText: '5h left',
          children: [
            AtomicChallengeCard(
              title: 'Fill in Survey',
              leftText: '0 / 1',
              rightText: '500 pts',
              phase: AtomicChallengePhase.open,
              fill: 0,
              cardTreatment: AtomicChallengeCardTreatment.listItem,
              onTap: _noop,
            ),
            AtomicChallengeCard(
              title: 'Fill in Survey',
              leftText: '1 / 1',
              rightText: 'pending 500 pts',
              phase: AtomicChallengePhase.pendingFinalization,
              fill: 1,
              cardTreatment: AtomicChallengeCardTreatment.listItem,
              onTap: _noop,
            ),
          ],
        ),
        const _ChallengeBandPreview(
          title: 'This Week',
          deadlineText: '4d left',
          children: [
            AtomicChallengeCard(
              title: 'Fill in Survey',
              leftText: '1 / 1',
              rightText: 'completed 500 pts',
              phase: AtomicChallengePhase.completed,
              fill: 1,
              cardTreatment: AtomicChallengeCardTreatment.listItem,
              onTap: _noop,
            ),
            AtomicChallengeCard(
              title: 'Give Kudos',
              leftText: '2 / 5',
              rightText: '400 / 1,500 pts',
              phase: AtomicChallengePhase.inProgress,
              fill: 0.4,
              cardTreatment: AtomicChallengeCardTreatment.listItem,
              onTap: _noop,
            ),
            AtomicChallengeCard(
              title: 'Give Kudos',
              leftText: '5 / 5',
              rightText: 'pending 1,500 pts',
              phase: AtomicChallengePhase.pendingFinalization,
              fill: 1,
              cardTreatment: AtomicChallengeCardTreatment.listItem,
              onTap: _noop,
            ),
            AtomicChallengeCard(
              title: 'Top 3 most-voted ideas',
              leftText: 'Joined',
              rightText: 'waiting review',
              phase: AtomicChallengePhase.pendingFinalization,
              fill: null,
              cardTreatment: AtomicChallengeCardTreatment.listItem,
              onTap: _noop,
            ),
          ],
        ),
        _ChallengeBandPreview(
          title: 'Season',
          deadlineText: seasonRemainingLabel,
          children: const [
            AtomicChallengeCard(
              title: 'Produce Every Block',
              leftText: '90% success',
              rightText: 'Earned 10,550.1 pts',
              phase: AtomicChallengePhase.inProgress,
              fill: null,
              railTreatment: AtomicChallengeRailTreatment.technicalOngoing,
              cardTreatment: AtomicChallengeCardTreatment.listItem,
              onTap: _noop,
            ),
            AtomicChallengeCard(
              title: 'Use dApps',
              leftText: '7 / 20',
              rightText: '350 / 1,000 pts',
              phase: AtomicChallengePhase.inProgress,
              fill: 0.35,
              cardTreatment: AtomicChallengeCardTreatment.listItem,
              onTap: _noop,
            ),
          ],
        ),
      ],
    );
  }
}

String _formatRemainingTime(
  Duration remaining, {
  String prefix = '',
  bool compact = false,
}) {
  if (remaining <= Duration.zero) return 'Ended';

  final days = remaining.inDays;
  final hours = remaining.inHours.remainder(24);
  final minutes = remaining.inMinutes.remainder(60);

  if (compact) {
    if (days > 0) return '$prefix${days}d';
    if (hours > 0) return '$prefix${hours}h';
    return '$prefix${minutes}m';
  }

  if (days > 0 && hours > 0) return '${days}d, ${hours}h left';
  if (days > 0) return '${days}d left';
  if (hours > 0 && minutes > 0) return '${hours}h, ${minutes}m left';
  if (hours > 0) return '${hours}h left';
  return '${minutes}m left';
}

class _ChallengeBandPreview extends StatelessWidget {
  const _ChallengeBandPreview({
    required this.title,
    required this.children,
    this.deadlineText,
  });

  final String title;
  final String? deadlineText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final isFeatured = title == 'Featured';
    final backgroundColor = isFeatured
        ? semantic.premium.colorSurface
        : colors.surfaceContainerLowest;
    final foregroundColor = isFeatured
        ? semantic.premium.onColorSurface
        : colors.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.space16),
      child: Material(
        color: backgroundColor,
        borderRadius: radii.borderRadiusLargeIncreased,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.space16,
            spacing.space12,
            spacing.space16,
            spacing.space12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChallengeBandHeader(
                title: title,
                deadlineText: deadlineText,
                foregroundColor: foregroundColor,
                leadingIcon: isFeatured ? Symbols.star_sharp : null,
              ),
              SizedBox(height: spacing.space12),
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) SizedBox(height: spacing.space4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChallengeBandHeader extends StatelessWidget {
  const _ChallengeBandHeader({
    required this.title,
    required this.foregroundColor,
    this.deadlineText,
    this.leadingIcon,
  });

  final String title;
  final Color foregroundColor;
  final String? deadlineText;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                ExcludeSemantics(
                  child: Icon(
                    leadingIcon,
                    size: sizing.iconXSmall,
                    fill: 1,
                    color: foregroundColor,
                  ),
                ),
                SizedBox(width: spacing.space4),
              ],
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(color: foregroundColor),
                ),
              ),
            ],
          ),
        ),
        if (deadlineText != null) ...[
          SizedBox(width: spacing.space12),
          Text(
            deadlineText!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelLarge?.copyWith(
              color: foregroundColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

void _noop() {}
