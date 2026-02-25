import 'package:flutter/material.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import 'challenge_card.dart';
import 'challenge_category_icon.dart';
import 'top_app_bar.dart';

/// A named record for description sections in [ChallengeDetailPage].
typedef ChallengeDetailSection = ({String title, String body});

/// A full-page detail view for a blockchain challenge.
///
/// Renders a [TopAppBar] (large) with category icon, title, and subtitle,
/// followed by a reward card, description sections, and a total reward card.
///
/// When [entranceAnimation] is provided, body content staggers in after the
/// animation completes — letting the Hero title land first before revealing
/// the rest of the page.
///
/// This is a presentation-only widget: all data comes through constructor
/// parameters. The feature screen in `lib/features/` wires state to this widget.
class ChallengeDetailPage extends StatefulWidget {
  const ChallengeDetailPage({
    super.key,
    required this.title,
    required this.category,
    required this.dateRange,
    required this.rewardCard,
    required this.sections,
    required this.totalRewardHeading,
    required this.totalRewardBody,
    this.onBackTap,
    this.titleHeroTag,
    this.iconHeroTag,
    this.entranceAnimation,
  });

  /// Challenge title, e.g. "Produce Every Block".
  final String title;

  /// Challenge category — drives the icon in the app bar.
  final ChallengeCategory category;

  /// Subtitle text for the app bar, e.g. "Technical · Jan 12 - Jan 30".
  final String dateRange;

  /// The reward card widget (typically a [ChallengeRewardCard]).
  final Widget rewardCard;

  /// Flexible list of description sections (e.g. Why, Task, Requirements).
  final List<ChallengeDetailSection> sections;

  /// Heading for the total reward card, e.g. "Total Reward Up to 6,500 pts".
  final String totalRewardHeading;

  /// Body text for the total reward card.
  final String totalRewardBody;

  /// Called when the back button is tapped.
  final VoidCallback? onBackTap;

  /// When non-null, enables a shared element transition for the title text.
  final String? titleHeroTag;

  /// When non-null, enables a shared element transition for the category icon.
  final String? iconHeroTag;

  /// Route animation that drives staggered entrance of body content.
  /// When provided, body content waits for this animation to complete
  /// before staggering in. Pass `ModalRoute.of(context)?.animation`.
  final Animation<double>? entranceAnimation;

  @override
  State<ChallengeDetailPage> createState() => _ChallengeDetailPageState();
}

class _ChallengeDetailPageState extends State<ChallengeDetailPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stagger;
  late final List<Animation<double>> _fadeAnimations;
  late final List<Animation<Offset>> _slideAnimations;

  static const _itemCount = 3;
  static const _staggerDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(vsync: this, duration: _staggerDuration);

    _fadeAnimations = List.generate(_itemCount, (i) {
      final start = i * 0.2;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _stagger,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _slideAnimations = List.generate(_itemCount, (i) {
      final start = i * 0.2;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _stagger,
        curve: Interval(start, end, curve: Curves.easeOut),
      ));
    });

    _bindEntranceAnimation();
  }

  void _bindEntranceAnimation() {
    final entrance = widget.entranceAnimation;
    if (entrance == null || entrance.isCompleted) {
      _stagger.value = 1.0;
      return;
    }
    entrance.addStatusListener(_onEntranceStatus);
  }

  void _onEntranceStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _stagger.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion && _stagger.value < 1.0) {
      _stagger.value = 1.0;
    }
  }

  @override
  void dispose() {
    widget.entranceAnimation?.removeStatusListener(_onEntranceStatus);
    _stagger.dispose();
    super.dispose();
  }

  Widget _staggerItem(int index, Widget child) {
    if (widget.entranceAnimation == null) return child;
    return SlideTransition(
      position: _slideAnimations[index],
      child: FadeTransition(
        opacity: _fadeAnimations[index],
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return CustomScrollView(
      slivers: [
        TopAppBar(
          title: widget.title,
          size: TopAppBarSize.large,
          subtitle: widget.dateRange,
          image: ChallengeCategoryIcon(category: widget.category),
          onLeadingTap: widget.onBackTap,
          titleHeroTag: widget.titleHeroTag,
          imageHeroTag: widget.iconHeroTag,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              left: spacing.space16,
              right: spacing.space16,
              bottom: spacing.space32,
            ),
            child: Column(
              children: [
                _staggerItem(0, widget.rewardCard),
                SizedBox(height: spacing.space16),
                _staggerItem(1, _SectionsCard(sections: widget.sections)),
                SizedBox(height: spacing.space16),
                _staggerItem(
                  2,
                  _TotalRewardCard(
                    heading: widget.totalRewardHeading,
                    body: widget.totalRewardBody,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A white card rendering a flexible list of [ChallengeDetailSection]s.
class _SectionsCard extends StatelessWidget {
  const _SectionsCard({required this.sections});

  final List<ChallengeDetailSection> sections;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: radii.borderRadiusLargeIncreased,
      ),
      padding: EdgeInsets.all(spacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < sections.length; i++) ...[
            if (i > 0) SizedBox(height: spacing.space16),
            Text(
              sections[i].title,
              style: textTheme.labelLarge?.copyWith(
                color: colors.onSurface,
              ),
            ),
            SizedBox(height: spacing.space4),
            Text(
              sections[i].body,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A white card with a reward formula heading and body text.
class _TotalRewardCard extends StatelessWidget {
  const _TotalRewardCard({
    required this.heading,
    required this.body,
  });

  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: radii.borderRadiusLargeIncreased,
      ),
      padding: EdgeInsets.all(spacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: textTheme.labelLarge?.copyWith(
              color: colors.onSurface,
            ),
          ),
          SizedBox(height: spacing.space4),
          Text(
            body,
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
