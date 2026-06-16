import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';

part 'active_challenge_bands.stories.g.dart';

const meta = Meta<ActiveChallengeBands>(path: 'prototypes/challenges');

final $Default = _Story(
  name: 'Default',
  args: _Args(
    appBarSize: EnumArg(
      TopStatusAppBarSize.large,
      values: TopStatusAppBarSize.values,
    ),
    nodeStatus: EnumArg(
      TopStatusNodeStatus.synced,
      values: TopStatusNodeStatus.values,
    ),
    profileLabel: StringArg('25k pts'),
  ),
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
  const ActiveChallengeBands({
    super.key,
    this.appBarSize = TopStatusAppBarSize.large,
    this.nodeStatus = TopStatusNodeStatus.synced,
    this.profileLabel = '25k pts',
  });

  final TopStatusAppBarSize appBarSize;
  final TopStatusNodeStatus nodeStatus;
  final String profileLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLow,
      body: CustomScrollView(
        slivers: [
          switch (appBarSize) {
            TopStatusAppBarSize.large => TopStatusAppBar.large(
              title: 'Season 1',
              profileLabel: profileLabel,
              nodeStatus: nodeStatus,
              onProfilePressed: () {},
              onNodePressed: () {},
            ),
            TopStatusAppBarSize.compact => TopStatusAppBar.compact(
              title: 'Season 1',
              nodeStatus: nodeStatus,
              onProfilePressed: () {},
              onNodePressed: () {},
            ),
          },
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              spacing.space16,
              0,
              spacing.space16,
              spacing.space32,
            ),
            sliver: const SliverToBoxAdapter(child: _ChallengeBands()),
          ),
        ],
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
            icon: Symbols.receipt_long_sharp,
            label: 'Activity',
            indicatorShape: NavIndicatorShape.circle,
          ),
        ],
      ),
    );
  }
}

class _ChallengeBands extends StatelessWidget {
  const _ChallengeBands();

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.space12,
      children: [
        const _ChallengeBandPreview(
          title: 'Featured',
          children: [
            AtomicChallengeCard(
              title: 'Propose an app change',
              leftText: 'Not done',
              rightText: '500 pts',
              phase: AtomicChallengePhase.open,
              fill: 0,
              featured: true,
              railTreatment: AtomicChallengeRailTreatment.checkbox,
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
              title: 'Fill in survey',
              leftText: 'Not done',
              rightText: '500 pts',
              phase: AtomicChallengePhase.open,
              fill: 0,
              railTreatment: AtomicChallengeRailTreatment.checkbox,
              cardTreatment: AtomicChallengeCardTreatment.listItem,
              onTap: _noop,
            ),
            AtomicChallengeCard(
              title: 'Fill in survey',
              leftText: 'Submitted',
              rightText: '500 pts',
              phase: AtomicChallengePhase.pendingFinalization,
              fill: 1,
              railTreatment: AtomicChallengeRailTreatment.checkbox,
              cardTreatment: AtomicChallengeCardTreatment.listItem,
              onTap: _noop,
            ),
          ],
        ),
        const _ChallengeBandPreview(
          title: 'This week',
          deadlineText: '4d left',
          children: [
            AtomicChallengeCard(
              title: 'Fill in survey',
              leftText: 'Done',
              rightText: '500 pts',
              phase: AtomicChallengePhase.completed,
              fill: 1,
              railTreatment: AtomicChallengeRailTreatment.checkbox,
              cardTreatment: AtomicChallengeCardTreatment.listItem,
              onTap: _noop,
            ),
            AtomicChallengeCard(
              title: 'Give kudos',
              leftText: '2 / 5',
              rightText: '400 / 1,500 pts',
              phase: AtomicChallengePhase.inProgress,
              fill: 0.4,
              cardTreatment: AtomicChallengeCardTreatment.listItem,
              onTap: _noop,
            ),
            AtomicChallengeCard(
              title: 'Give kudos',
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
        const _ChallengeBandPreview(
          title: 'Hackathon event',
          deadlineText: '14d left',
          children: [
            AtomicChallengeCard(
              title: 'Improve a dApp flow',
              leftText: 'Submitted',
              rightText: 'review pending',
              phase: AtomicChallengePhase.pendingFinalization,
              fill: null,
              railTreatment: AtomicChallengeRailTreatment.checkbox,
              cardTreatment: AtomicChallengeCardTreatment.listItem,
              onTap: _noop,
            ),
            AtomicChallengeCard(
              title: 'Test another builder app',
              leftText: 'Not done',
              rightText: '750 pts',
              phase: AtomicChallengePhase.open,
              fill: 0,
              railTreatment: AtomicChallengeRailTreatment.checkbox,
              cardTreatment: AtomicChallengeCardTreatment.listItem,
              onTap: _noop,
            ),
            AtomicChallengeCard(
              title: 'Vote on top ideas',
              leftText: '3 / 5',
              rightText: '300 / 500 pts',
              phase: AtomicChallengePhase.inProgress,
              fill: 0.6,
              cardTreatment: AtomicChallengeCardTreatment.listItem,
              onTap: _noop,
            ),
          ],
        ),
        const _ChallengeBandPreview(
          title: 'June',
          children: [
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
        const _ChallengeBandPreview(
          title: 'May',
          children: [
            AtomicChallengeCard(
              title: 'Produce Every Block',
              leftText: '92% success',
              rightText: 'Earned 4,600 pts',
              phase: AtomicChallengePhase.inProgress,
              fill: null,
              railTreatment: AtomicChallengeRailTreatment.technicalOngoing,
              cardTreatment: AtomicChallengeCardTreatment.listItem,
              onTap: _noop,
            ),
          ],
        ),
        const _ChallengeBandPreview(
          title: 'April',
          children: [
            AtomicChallengeCard(
              title: 'Produce Every Block',
              leftText: '78% success',
              rightText: 'Earned 3,900 pts',
              phase: AtomicChallengePhase.inProgress,
              fill: null,
              railTreatment: AtomicChallengeRailTreatment.technicalOngoing,
              cardTreatment: AtomicChallengeCardTreatment.listItem,
              onTap: _noop,
            ),
          ],
        ),
      ],
    );
  }
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

    return Material(
      color: backgroundColor,
      borderRadius: radii.borderRadiusLargeIncreased,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.space16,
          children: [
            _ChallengeBandHeader(
              title: title,
              deadlineText: deadlineText,
              foregroundColor: foregroundColor,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spacing.space8,
              children: children,
            ),
          ],
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
  });

  final String title;
  final Color foregroundColor;
  final String? deadlineText;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelLarge?.copyWith(color: foregroundColor),
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
