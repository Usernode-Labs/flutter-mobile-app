import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';

import 'atomic_challenge_card.stories.dart';

part 'testnet_profile_page.stories.g.dart';

const meta = Meta<TestnetProfilePageDemo>(path: 'prototypes/pages/challenges');

const _defaultCompletedChallenges = [
  TestnetProfileChallengeData(
    title: 'Produce Blocks',
    leftText: 'Done',
    rightText: 'completed 6,500 pts',
    fill: 1,
    railTreatment: AtomicChallengeRailTreatment.checkbox,
  ),
  TestnetProfileChallengeData(
    title: 'Community Sprint',
    leftText: 'Done',
    rightText: 'completed 3,000 pts',
    fill: 1,
    railTreatment: AtomicChallengeRailTreatment.checkbox,
  ),
  TestnetProfileChallengeData(
    title: 'Flash Verification',
    leftText: 'Done',
    rightText: 'completed 1,500 pts',
    fill: 1,
    railTreatment: AtomicChallengeRailTreatment.checkbox,
  ),
];

const _defaultRankingEntries = [
  TestnetProfileRankingEntry(
    rank: '1',
    name: 'node-alpha',
    points: '18,420 pts',
  ),
  TestnetProfileRankingEntry(
    rank: '2',
    name: 'blocksmith',
    points: '16,800 pts',
  ),
  TestnetProfileRankingEntry(
    rank: '3',
    name: 'epoch-runner',
    points: '15,250 pts',
  ),
  TestnetProfileRankingEntry(
    rank: '44',
    name: 'You',
    points: '8,000 pts',
    isCurrentUser: true,
  ),
  TestnetProfileRankingEntry(
    rank: '45',
    name: 'testnet-node',
    points: '7,960 pts',
  ),
];

final $Default = _Story(
  args: _Args(
    title: StringArg('Profile'),
    score: StringArg('8,000'),
    scoreLabel: StringArg('points'),
    rankLabel: StringArg('Rank 44'),
    progress: DoubleArg(0.65),
    periodLabel: StringArg('All Events'),
    completedChallenges: Arg.fixed(_defaultCompletedChallenges),
    rankingEntries: Arg.fixed(_defaultRankingEntries),
    initialTabIndex: IntArg(0),
    onBackTap: Arg.fixed(() {}),
    onSettingsTap: Arg.fixed(() {}),
    onPeriodTap: Arg.fixed(() {}),
  ),
  scenarios: [
    _Scenario(
      name: 'All Events',
      args: _Args.fixed(
        title: 'Profile',
        score: '8,000',
        scoreLabel: 'points',
        rankLabel: 'Rank 44',
        progress: 0.65,
        periodLabel: 'All Events',
        completedChallenges: _defaultCompletedChallenges,
        rankingEntries: _defaultRankingEntries,
        initialTabIndex: 0,
        onBackTap: () {},
        onSettingsTap: () {},
        onPeriodTap: () {},
      ),
    ),
    _Scenario(
      name: 'Event Selected',
      args: _Args.fixed(
        title: 'Profile',
        score: '3,250',
        scoreLabel: 'points',
        rankLabel: 'Rank 18',
        progress: 0.82,
        periodLabel: 'Block Production',
        completedChallenges: [_defaultCompletedChallenges.first],
        rankingEntries: _defaultRankingEntries,
        initialTabIndex: 0,
        onBackTap: () {},
        onSettingsTap: () {},
        onPeriodTap: () {},
      ),
    ),
  ],
);

final $Leaderboard = _Story(
  name: 'Leaderboard',
  args: _Args(
    title: StringArg('Profile'),
    score: StringArg('8,000'),
    scoreLabel: StringArg('points'),
    rankLabel: StringArg('Rank 44'),
    progress: DoubleArg(0.65),
    periodLabel: StringArg('All Events'),
    completedChallenges: Arg.fixed(_defaultCompletedChallenges),
    rankingEntries: Arg.fixed(_defaultRankingEntries),
    initialTabIndex: IntArg(1),
    onBackTap: Arg.fixed(() {}),
    onSettingsTap: Arg.fixed(() {}),
    onPeriodTap: Arg.fixed(() {}),
  ),
);

class TestnetProfilePageDemo extends StatelessWidget {
  const TestnetProfilePageDemo({
    super.key,
    this.title = 'Profile',
    this.score = '8,000',
    this.scoreLabel = 'points',
    this.rankLabel = 'Rank 44',
    this.progress = 0.65,
    this.periodLabel = 'All Events',
    this.completedChallenges = _defaultCompletedChallenges,
    this.rankingEntries = _defaultRankingEntries,
    this.initialTabIndex = 0,
    this.onBackTap,
    this.onSettingsTap,
    this.onPeriodTap,
  });

  final String title;
  final String score;
  final String scoreLabel;
  final String? rankLabel;
  final double progress;
  final String periodLabel;
  final List<TestnetProfileChallengeData> completedChallenges;
  final List<TestnetProfileRankingEntry> rankingEntries;
  final int initialTabIndex;
  final VoidCallback? onBackTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onPeriodTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      body: CustomScrollView(
        slivers: [
          TopAppBar(
            title: title,
            onLeadingTap: onBackTap,
            backgroundColor: colors.surfaceContainerLowest,
            actions: [
              IconButton(
                tooltip: 'Settings',
                onPressed: onSettingsTap,
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
                    scoreLabel: scoreLabel,
                    rankLabel: rankLabel,
                    progress: progress,
                    showCountdown: false,
                    density: ScoreHeaderDensity.compact,
                    footer: DropdownChip(
                      label: periodLabel,
                      variant: ChipVariant.outlined,
                      onTap: onPeriodTap,
                    ),
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
                      initialIndex: initialTabIndex,
                      children: [
                        _CompletedChallengesTab(
                          challenges: completedChallenges,
                        ),
                        _LeaderboardTab(entries: rankingEntries),
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

class TestnetProfileChallengeData {
  const TestnetProfileChallengeData({
    required this.title,
    required this.leftText,
    required this.rightText,
    required this.fill,
    this.phase = AtomicChallengePhase.completed,
    this.railTreatment = AtomicChallengeRailTreatment.standard,
  });

  final String title;
  final String leftText;
  final String rightText;
  final double? fill;
  final AtomicChallengePhase phase;
  final AtomicChallengeRailTreatment railTreatment;
}

class TestnetProfileRankingEntry {
  const TestnetProfileRankingEntry({
    required this.rank,
    required this.name,
    required this.points,
    this.isCurrentUser = false,
  });

  final String rank;
  final String name;
  final String points;
  final bool isCurrentUser;
}

class _CompletedChallengesTab extends StatelessWidget {
  const _CompletedChallengesTab({required this.challenges});

  final List<TestnetProfileChallengeData> challenges;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.space16,
        vertical: spacing.space12,
      ),
      itemCount: challenges.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.space8),
      itemBuilder: (context, index) {
        final challenge = challenges[index];
        return AtomicChallengeCard(
          title: challenge.title,
          leftText: challenge.leftText,
          rightText: challenge.rightText,
          phase: challenge.phase,
          fill: challenge.fill,
          railTreatment: challenge.railTreatment,
          cardTreatment: AtomicChallengeCardTreatment.listItem,
          onTap: () {},
        );
      },
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab({required this.entries});

  final List<TestnetProfileRankingEntry> entries;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.space16,
        vertical: spacing.space12,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.space4),
      itemBuilder: (context, index) {
        return _LeaderboardRow(entry: entries[index]);
      },
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final TestnetProfileRankingEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final opacity = Theme.of(context).extension<AppOpacity>()!;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: entry.isCurrentUser
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
            RankBadge(rank: entry.rank),
            SizedBox(width: spacing.space16),
            Expanded(
              child: Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium,
              ),
            ),
            SizedBox(width: spacing.space16),
            Text(
              entry.points,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
