import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/bottom_nav.dart';
import '../src/challenge_card.dart';
import '../src/challenge_category_icon.dart';
import '../src/challenge_category_tile.dart';
import '../src/dropdown_chain.dart';
import '../src/leaderboard_stats_card.dart';
import '../src/nav_indicator_shapes.dart';
import '../src/rank_badge.dart';
import '../src/top_app_bar.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent leaderboardPageComponent() {
  return WidgetbookComponent(
    name: 'Leaderboard',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final participantCount = context.knobs.double
              .slider(
                label: 'Participant count',
                initialValue: 9,
                min: 3,
                max: 20,
              )
              .round();

          return _LeaderboardPage(participantCount: participantCount);
        },
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Mock data
// ---------------------------------------------------------------------------

const _mockParticipants = [
  ('namaah', '10,000'),
  ('madmax', '8,500'),
  ('boscrypto', '7,200'),
  ('discordhandle', '6,100'),
  ('validator99', '5,000'),
  ('blockrunner', '4,800'),
  ('nodehero', '4,200'),
  ('cryptoqueen', '3,900'),
  ('stakingpro', '3,500'),
  ('minaguy', '3,200'),
  ('chain_master', '2,900'),
  ('proof_of_work', '2,600'),
  ('solo_validator', '2,300'),
  ('defi_wizard', '2,000'),
  ('epoch_runner', '1,800'),
  ('block_smith', '1,500'),
  ('hash_hunter', '1,200'),
  ('node_ninja', '900'),
  ('test_pilot', '600'),
  ('new_member', '300'),
];

List<int> _bellCurveCounts(int count) {
  final center = count / 2;
  final sigma = count / 4;
  return List.generate(count, (i) {
    final x = (i - center) / sigma;
    return (math.exp(-0.5 * x * x) * 45).round().clamp(1, 50);
  });
}

List<String> _mockScoreLabels(int bucketCount, int minPts, int maxPts) {
  final fmt = NumberFormat('#,##0');
  final bucketWidth = (maxPts - minPts) / bucketCount;
  return List.generate(bucketCount, (i) {
    final lo = (minPts + i * bucketWidth).round();
    final hi = i == bucketCount - 1
        ? maxPts
        : (minPts + (i + 1) * bucketWidth).round();
    return '${fmt.format(lo)}–${fmt.format(hi)} pts';
  });
}

// ---------------------------------------------------------------------------
// Page widget
// ---------------------------------------------------------------------------

class _LeaderboardPage extends StatefulWidget {
  const _LeaderboardPage({required this.participantCount});

  final int participantCount;

  @override
  State<_LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<_LeaderboardPage> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    final participants = _mockParticipants.take(widget.participantCount);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar
          const TopAppBar(
            title: 'Leaderboard',
            leading: SizedBox.shrink(),
          ),

          // Filter chip row
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.space16,
                vertical: spacing.space8,
              ),
              child: DropdownChain(
                items: const [
                  DropdownChainItem(label: 'All Seasons'),
                  DropdownChainItem(label: 'All Phases'),
                ],
              ),
            ),
          ),

          // Stats card
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.space16),
              child: LeaderboardStatsCard(
                totalPoints: '18,000',
                totalPointsLabel: 'TOTAL POINTS',
                rank: '34',
                rankLabel: 'RANK',
                distributionCounts: _bellCurveCounts(16),
                userBucketIndex: 6,
                minScoreLabel: '0',
                userScoreLabel: '8,000',
                maxScoreLabel: '15,000',
                calloutTitle: 'Better than 45% of participants',
                calloutBody:
                    "You're in the top 55%! Keep completing challenges to secure your position.",
                bucketScoreLabels: _mockScoreLabels(16, 0, 15000),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: SizedBox(height: spacing.space16),
          ),

          // Challenge category tiles
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.space16),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLowest,
                  borderRadius: radii.borderRadiusLargeIncreased,
                ),
                padding: EdgeInsets.symmetric(vertical: spacing.space8),
                child: Column(
                  children: [
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: spacing.space16),
                      child: const ChallengeCategoryTile(
                        categoryIcon: ChallengeCategoryIcon(
                          category: ChallengeCategory.technical,
                          size: 40,
                        ),
                        categoryName: 'Technical',
                        remainingCount: 3,
                        completedCount: 2,
                        pointsLabel: '4,525 pts',
                        challenges: [
                          ChallengeCategoryItem(
                            title: 'Run a validator node',
                            isCompleted: true,
                          ),
                          ChallengeCategoryItem(
                            title: 'Submit 10 transactions',
                            isCompleted: true,
                          ),
                          ChallengeCategoryItem(
                            title: 'Deploy a smart contract',
                            isCompleted: false,
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: colors.surfaceContainerHighest),
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: spacing.space16),
                      child: const ChallengeCategoryTile(
                        categoryIcon: ChallengeCategoryIcon(
                          category: ChallengeCategory.community,
                          size: 40,
                        ),
                        categoryName: 'Community',
                        remainingCount: 1,
                        completedCount: 3,
                        pointsLabel: '6,200 pts',
                        challenges: [
                          ChallengeCategoryItem(
                            title: 'Invite 5 friends',
                            isCompleted: true,
                          ),
                          ChallengeCategoryItem(
                            title: 'Post in Discord',
                            isCompleted: true,
                          ),
                          ChallengeCategoryItem(
                            title: 'Host a workshop',
                            isCompleted: false,
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: colors.surfaceContainerHighest),
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: spacing.space16),
                      child: const ChallengeCategoryTile(
                        categoryIcon: ChallengeCategoryIcon(
                          category: ChallengeCategory.flash,
                          size: 40,
                        ),
                        categoryName: 'Flash',
                        remainingCount: 2,
                        completedCount: 1,
                        pointsLabel: '1,800 pts',
                        challenges: [
                          ChallengeCategoryItem(
                            title: 'Daily check-in streak',
                            isCompleted: true,
                          ),
                          ChallengeCategoryItem(
                            title: 'Weekend sprint',
                            isCompleted: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: SizedBox(height: spacing.space16),
          ),

          // Participants list card
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.space16),
              child: DecoratedBox(
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
                    ...participants.indexed.map((entry) {
                      final (index, participant) = entry;
                      final (name, points) = participant;
                      return ListTile(
                        leading: RankBadge(rank: '${index + 1}'),
                        title: Text(name),
                        trailing: Text('$points pts'),
                        onTap: () {},
                      );
                    }),
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
      bottomNavigationBar: BottomNav(
        items: [
          BottomNavItem(
            icon: Symbols.cards_star_sharp,
            label: 'Challenges',
            indicatorShape: NavIndicatorShape.circle,
            indicatorColor: semantic.flash.color,
            indicatorFillColor: semantic.flash.colorContainer,
          ),
          BottomNavItem(
            icon: Symbols.leaderboard_sharp,
            label: 'Leaderboard',
            indicatorShape: NavIndicatorShape.blob,
            indicatorColor: semantic.community.color,
            indicatorFillColor: semantic.community.colorContainer,
          ),
          BottomNavItem(
            icon: Symbols.account_balance_wallet_sharp,
            label: 'Wallet',
            indicatorShape: NavIndicatorShape.circle,
            indicatorColor: semantic.flash.color,
            indicatorFillColor: semantic.flash.colorContainer,
          ),
          BottomNavItem(
            icon: Symbols.check_circle_sharp,
            label: 'Node',
            indicatorShape: NavIndicatorShape.hexagon,
            indicatorColor: semantic.technical.color,
            indicatorFillColor: semantic.technical.colorContainer,
          ),
          BottomNavItem(
            icon: Symbols.settings_sharp,
            label: 'Settings',
            indicatorShape: NavIndicatorShape.hexagon,
            indicatorColor: semantic.technical.color,
            indicatorFillColor: semantic.technical.colorContainer,
          ),
        ],
        selectedIndex: _navIndex,
        onItemSelected: (index) => setState(() => _navIndex = index),
      ),
    );
  }
}
