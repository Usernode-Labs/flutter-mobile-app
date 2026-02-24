import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/bottom_nav.dart';
import '../src/challenge_card.dart';
import '../src/challenge_category_icon.dart';
import '../src/dropdown_chain.dart';
import '../src/nav_indicator_shapes.dart';
import '../src/score_header.dart';
import '../src/tabs.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent challengesPageComponent() {
  return WidgetbookComponent(
    name: 'Challenges',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final showGlow = context.knobs.boolean(
            label: 'Score glow',
            initialValue: false,
          );
          return _ChallengesPage(showGlow: showGlow);
        },
      ),
    ],
  );
}

class _ChallengesPage extends StatefulWidget {
  const _ChallengesPage({required this.showGlow});

  final bool showGlow;

  @override
  State<_ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<_ChallengesPage> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return ColoredBox(
      color: colors.surface,
      child: Column(
        children: [
          // ─── Top header area ───
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.space16,
                    vertical: spacing.space8,
                  ),
                  child: DropdownChain(
                    items: const [
                      DropdownChainItem(label: 'Season 2'),
                      DropdownChainItem(label: 'DApps Integration'),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing.space16),
                  child: ScoreHeader(
                    score: '8,000',
                    scoreLabel: 'points',
                    rankLabel: 'Rank 44',
                    progress: 0.75,
                    countdownTime: '12 days 5h 3m',
                    ctaLabel: 'View in Leaderboard',
                    variant: widget.showGlow
                        ? ScoreHeaderVariant.glow
                        : ScoreHeaderVariant.standard,
                  ),
                ),
                SizedBox(height: spacing.space16),
              ],
            ),
          ),

          // ─── Bottom content area (white, rounded top) ───
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainerLowest,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(radii.xLarge + 4), // 28px per Figma
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Tabs(
                tabs: const [
                  TabItem(label: 'Active', badgeCount: 2),
                  TabItem(label: 'Completed', badgeCount: 1),
                  TabItem(label: 'Missed'),
                ],
                children: [
                  _buildActiveTab(spacing),
                  _buildCompletedTab(spacing),
                  _buildMissedTab(),
                ],
              ),
            ),
          ),

          // ─── Bottom navigation bar ───
          BottomNav(
            items: [
              BottomNavItem(
                icon: Symbols.cards_star_sharp,
                label: 'Challenges',
                indicatorShape: NavIndicatorShape.circle,
                indicatorColor: semantic.flash.color,
                indicatorFillColor: semantic.flash.colorContainer,
              ),
              BottomNavItem(
                icon: Symbols.action_key_sharp,
                label: 'Apps',
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
        ],
      ),
    );
  }

  Widget _buildActiveTab(AppSpacing spacing) {
    return ListView(
      padding: EdgeInsets.all(spacing.space16),
      children: [
        ChallengeCard(
          title: 'Produce Every Block',
          description:
              'Successfully produce every block assigned to your node during the challenge period.',
          dateRange: 'Jan 15 - Feb 15',
          category: ChallengeCategory.technical,
          categoryIcon: const ChallengeCategoryIcon(
              category: ChallengeCategory.technical),
          variant: ChallengeCardVariant.ongoing,
          earnedPoints: '10,550.1 pts',
          epochPoints: '+50 pts',
        ),
        SizedBox(height: spacing.space12),
        ChallengeCard(
          title: 'Prove Humanity',
          description:
              'Complete the humanity verification process to prove you are a real person.',
          dateRange: 'Jan 15 - Feb 15',
          category: ChallengeCategory.community,
          categoryIcon: const ChallengeCategoryIcon(
              category: ChallengeCategory.community),
          variant: ChallengeCardVariant.active,
          rewardText: 'Up to 1000 pts',
        ),
        SizedBox(height: spacing.space12),
        ChallengeCard(
          title: 'Refer New Testers',
          description:
              'Invite friends to join the testnet and earn points for each successful referral.',
          dateRange: 'Jan 15 - Feb 15',
          category: ChallengeCategory.community,
          categoryIcon: const ChallengeCategoryIcon(
              category: ChallengeCategory.community),
          variant: ChallengeCardVariant.active,
          rewardText: 'Up to 500 pts',
        ),
        SizedBox(height: spacing.space12),
        ChallengeCard(
          title: 'Live Feedback',
          description:
              'Submit feedback on your experience running a node during the testnet.',
          dateRange: 'Jan 1 - Jan 14',
          category: ChallengeCategory.technical,
          categoryIcon: const ChallengeCategoryIcon(
              category: ChallengeCategory.technical),
          variant: ChallengeCardVariant.completed,
          completedPoints: '500 pts',
        ),
      ],
    );
  }

  Widget _buildCompletedTab(AppSpacing spacing) {
    return ListView(
      padding: EdgeInsets.all(spacing.space16),
      children: [
        ChallengeCard(
          title: 'Live Feedback',
          description:
              'Submit feedback on your experience running a node during the testnet.',
          dateRange: 'Jan 1 - Jan 14',
          category: ChallengeCategory.technical,
          categoryIcon: const ChallengeCategoryIcon(
              category: ChallengeCategory.technical),
          variant: ChallengeCardVariant.completed,
          completedPoints: '500 pts',
        ),
      ],
    );
  }

  Widget _buildMissedTab() {
    return Center(
      child: Text(
        'No missed challenges',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
