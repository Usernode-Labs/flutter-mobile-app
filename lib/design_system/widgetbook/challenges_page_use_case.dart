import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/bottom_nav.dart';
import '../src/challenge_card.dart';
import '../src/challenge_category_icon.dart';
import '../src/dropdown_chain.dart';
import '../src/dropdown_chip.dart';
import '../src/nav_indicator_shapes.dart';
import '../src/score_header.dart';
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

/// Spacer height matching ScoreHeader's natural size.
/// 32 top + 160 circle + 16 gap + 16 countdown + 48 gap + 40 button + 32 bottom.
const _kSpacerHeight = 344.0;

/// M3 TabBar height.
const _kTabBarHeight = 48.0;

/// Chip row intrinsic height.
const _kChipHeight = 32.0;

/// Tab definitions.
const _kTabLabels = ['Active', 'Completed', 'Missed'];
const _kTabBadges = [2, 1, 0];

class _ChallengesPage extends StatefulWidget {
  const _ChallengesPage({required this.showGlow});

  final bool showGlow;

  @override
  State<_ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<_ChallengesPage>
    with TickerProviderStateMixin {
  int _navIndex = 0;
  double _scrollFraction = 0.0;
  late TabController _tabController;

  // Heartbeat glow controllers — one per pillar lobe.
  late final AnimationController _technicalGlow;
  late final AnimationController _flashGlow;
  late final AnimationController _communityGlow;
  late final AnimationController _fadeOut;

  double _technicalValue = 0.0;
  double _flashValue = 0.0;
  double _communityValue = 0.0;
  bool _isRefreshAnimating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _kTabLabels.length, vsync: this);
    _technicalGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flashGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _communityGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeOut = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _technicalGlow.dispose();
    _flashGlow.dispose();
    _communityGlow.dispose();
    _fadeOut.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Heartbeat TweenSequence: lub-dub pattern.
  static TweenSequence<double> _heartbeatSequence(double peak, double hold) =>
      TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: peak), weight: 16),
        TweenSequenceItem(
            tween: Tween(begin: peak, end: peak * 0.6), weight: 16),
        TweenSequenceItem(
            tween: Tween(begin: peak * 0.6, end: peak * 0.6), weight: 12),
        TweenSequenceItem(
            tween: Tween(begin: peak * 0.6, end: peak * 0.85), weight: 16),
        TweenSequenceItem(
            tween: Tween(begin: peak * 0.85, end: hold), weight: 40),
      ]);

  Future<void> _runHeartbeat(
    AnimationController controller,
    TweenSequence<double> sequence,
    void Function(double) setter,
  ) {
    controller.reset();
    final animation = sequence.animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );
    void listener() => setState(() => setter(animation.value));
    animation.addListener(listener);
    return controller.forward().then((_) => animation.removeListener(listener));
  }

  Future<void> _simulateRefresh() async {
    if (_isRefreshAnimating) return;

    setState(() => _isRefreshAnimating = true);
    _fadeOut.value = 1.0;

    final isGlow = widget.showGlow;
    final peak = isGlow ? 1.0 : 0.45;
    final hold = isGlow ? 0.7 : 0.30;
    final completionPeak = isGlow ? 1.0 : 0.55;

    final staggerSeq = _heartbeatSequence(peak, hold);

    _runHeartbeat(_technicalGlow, staggerSeq, (v) => _technicalValue = v);
    await Future.delayed(const Duration(milliseconds: 350));
    _runHeartbeat(_flashGlow, staggerSeq, (v) => _flashValue = v);
    await Future.delayed(const Duration(milliseconds: 350));
    _runHeartbeat(_communityGlow, staggerSeq, (v) => _communityValue = v);

    // Simulate data load delay.
    await Future.delayed(const Duration(milliseconds: 800));

    // Completion heartbeat — all three in unison.
    final completionSeq = _heartbeatSequence(completionPeak, hold);
    await Future.wait([
      _runHeartbeat(_technicalGlow, completionSeq, (v) => _technicalValue = v),
      _runHeartbeat(_flashGlow, completionSeq, (v) => _flashValue = v),
      _runHeartbeat(_communityGlow, completionSeq, (v) => _communityValue = v),
    ]);

    if (isGlow) {
      setState(() => _isRefreshAnimating = false);
    } else {
      _fadeOut.value = 1.0;
      void fadeListener() {
        setState(() {
          final f = _fadeOut.value;
          _technicalValue = hold * f;
          _flashValue = hold * f;
          _communityValue = hold * f;
        });
      }

      _fadeOut.addListener(fadeListener);
      await _fadeOut.reverse(from: 1.0);
      _fadeOut.removeListener(fadeListener);
      setState(() {
        _technicalValue = 0.0;
        _flashValue = 0.0;
        _communityValue = 0.0;
        _isRefreshAnimating = false;
      });
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final fraction =
        (notification.metrics.pixels / _kSpacerHeight).clamp(0.0, 1.0);
    if (fraction != _scrollFraction) {
      setState(() => _scrollFraction = fraction);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final safeTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: ColoredBox(
        color: colors.surface,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Layer 1 — parallax ScoreHeader behind scroll surface
            Transform.translate(
              offset: Offset(0, -_scrollFraction * _kSpacerHeight * 0.4),
              child: Padding(
                padding: EdgeInsets.only(
                  top: safeTop + spacing.space8 + _kChipHeight + spacing.space8,
                  left: spacing.space16,
                  right: spacing.space16,
                ),
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
                  technicalGlowIntensity:
                      _isRefreshAnimating ? _technicalValue : null,
                  flashGlowIntensity: _isRefreshAnimating ? _flashValue : null,
                  communityGlowIntensity:
                      _isRefreshAnimating ? _communityValue : null,
                ),
              ),
            ),

            // Layer 2 — scrolling surface
            NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    // Pinned chip bar
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _ChipBarDelegate(
                        topPadding: safeTop,
                        spacing: spacing,
                        scrollFraction: _scrollFraction,
                      ),
                    ),
                    // Transparent spacer revealing ScoreHeader
                    const SliverToBoxAdapter(
                      child: SizedBox(height: _kSpacerHeight),
                    ),
                    // Pinned surface tab bar
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SurfaceTabBarDelegate(
                        tabController: _tabController,
                        scrollFraction: _scrollFraction,
                      ),
                    ),
                  ];
                },
                body: ColoredBox(
                  color: colors.surfaceContainerLowest,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActiveTab(spacing),
                      _buildCompletedTab(spacing),
                      _buildMissedTab(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
      floatingActionButton: FloatingActionButton.small(
        onPressed: _isRefreshAnimating ? null : _simulateRefresh,
        tooltip: 'Simulate refresh',
        child: _isRefreshAnimating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
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

// ---------------------------------------------------------------------------
// _ChipBarDelegate — pinned DropdownChain with lerping background
// ---------------------------------------------------------------------------

class _ChipBarDelegate extends SliverPersistentHeaderDelegate {
  _ChipBarDelegate({
    required this.topPadding,
    required this.spacing,
    required this.scrollFraction,
  });

  final double topPadding;
  final AppSpacing spacing;
  final double scrollFraction;

  @override
  double get maxExtent =>
      topPadding + spacing.space8 + _kChipHeight + spacing.space8;

  @override
  double get minExtent => maxExtent;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colors = Theme.of(context).colorScheme;
    final bgColor = Color.lerp(
        colors.surfaceContainerLowest.withValues(alpha: 0),
        colors.surfaceContainerLowest,
        scrollFraction)!;
    final chipBorder = Color.lerp(colors.outlineVariant.withValues(alpha: 0),
        colors.outlineVariant, scrollFraction)!;

    return ColoredBox(
      color: bgColor,
      child: Padding(
        padding: EdgeInsets.only(
          top: topPadding + spacing.space8,
          left: spacing.space16,
          right: spacing.space16,
          bottom: spacing.space8,
        ),
        child: DropdownChain(
          items: [
            DropdownChainItem(
                label: 'Season 2',
                variant: ChipVariant.surface,
                borderColor: chipBorder),
            DropdownChainItem(
                label: 'DApps Integration',
                variant: ChipVariant.surface,
                borderColor: chipBorder),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_ChipBarDelegate oldDelegate) =>
      oldDelegate.scrollFraction != scrollFraction ||
      oldDelegate.topPadding != topPadding;
}

// ---------------------------------------------------------------------------
// _SurfaceTabBarDelegate — pinned white surface with animating corner radius
// ---------------------------------------------------------------------------

class _SurfaceTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SurfaceTabBarDelegate({
    required this.tabController,
    required this.scrollFraction,
  });

  final TabController tabController;
  final double scrollFraction;

  static const _kTopInset = 8.0;

  @override
  double get maxExtent => _kTopInset + _kTabBarHeight;

  @override
  double get minExtent => _kTopInset + _kTabBarHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cornerRadius = 28.0 * (1.0 - scrollFraction);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(cornerRadius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.only(top: _kTopInset),
        child: TabBar(
          controller: tabController,
          labelColor: colors.onSurface,
          unselectedLabelColor: colors.outline,
          labelStyle: textTheme.titleSmall,
          unselectedLabelStyle: textTheme.titleSmall,
          indicatorColor: colors.primary,
          indicatorWeight: 3,
          dividerColor: colors.outlineVariant,
          dividerHeight: 1,
          tabs: [
            for (int i = 0; i < _kTabLabels.length; i++) _buildTab(context, i),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context, int index) {
    final badge = _kTabBadges[index];
    if (badge <= 0) return Tab(text: _kTabLabels[index]);

    return Tab(
      child: ListenableBuilder(
        listenable: tabController,
        builder: (context, _) {
          final colors = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;
          final spacing = Theme.of(context).extension<AppSpacing>()!;
          final isActive = tabController.index == index;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _kTabLabels[index],
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              SizedBox(width: spacing.space4),
              Container(
                height: 16,
                constraints: const BoxConstraints(minWidth: 16),
                padding: EdgeInsets.symmetric(horizontal: spacing.space4),
                decoration: ShapeDecoration(
                  color: isActive ? colors.onSurface : colors.outline,
                  shape: const StadiumBorder(),
                ),
                child: Center(
                  child: Text(
                    '$badge',
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.surface,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(_SurfaceTabBarDelegate oldDelegate) =>
      oldDelegate.scrollFraction != scrollFraction ||
      oldDelegate.tabController != tabController;
}
