import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';

part 'atomic_challenge_card.stories.g.dart';

const meta = MetaWithArgs<AtomicChallengeCard, AtomicChallengeCardInput>(
  path: 'challenges',
);

enum AtomicChallengePhase { open, inProgress, pendingFinalization, completed }

enum AtomicChallengeRailTreatment { standard, technicalOngoing }

enum AtomicChallengeCardTreatment { card, listItem }

class AtomicChallengeCardInput {
  const AtomicChallengeCardInput({
    this.title = 'Give Kudos',
    this.leftText = '2 / 5',
    this.rightText = '400 / 1,500 pts',
    this.phase = AtomicChallengePhase.inProgress,
    this.fill = 0.4,
    this.cardWidth = 358,
    this.featured = false,
    this.railTreatment = AtomicChallengeRailTreatment.standard,
  });

  final String title;
  final String leftText;
  final String rightText;
  final AtomicChallengePhase phase;
  final double? fill;
  final double cardWidth;
  final bool featured;
  final AtomicChallengeRailTreatment railTreatment;
}

final defaults = _Defaults(
  builder: (context, args) {
    return AtomicChallengeCard(
      title: args.title,
      leftText: args.leftText,
      rightText: args.rightText,
      phase: args.phase,
      fill: args.fill,
      featured: args.featured,
      railTreatment: args.railTreatment,
      onTap: () {},
    );
  },
  setup: (context, child, args) {
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: args.cardWidth, child: child),
    );
  },
);

_Args _atomicArgs({
  required String title,
  required String leftText,
  required String rightText,
  required AtomicChallengePhase phase,
  required double? fill,
  double cardWidth = 358,
  bool featured = false,
  AtomicChallengeRailTreatment railTreatment =
      AtomicChallengeRailTreatment.standard,
  bool featuredTogglable = true,
}) {
  if (!featuredTogglable) {
    return _Args.fixed(
      title: title,
      leftText: leftText,
      rightText: rightText,
      phase: phase,
      fill: fill,
      cardWidth: cardWidth,
      featured: featured,
      railTreatment: railTreatment,
    );
  }

  return _Args(
    title: Arg.fixed(title),
    leftText: Arg.fixed(leftText),
    rightText: Arg.fixed(rightText),
    phase: Arg.fixed(phase),
    fill: Arg.fixed(fill),
    cardWidth: Arg.fixed(cardWidth),
    featured: BoolArg(featured),
    railTreatment: Arg.fixed(railTreatment),
  );
}

final $AtomicRail = _Story(
  name: 'Atomic rail',
  args: _Args(
    title: StringArg('Give Kudos'),
    leftText: StringArg('2 / 5'),
    rightText: StringArg('400 / 1,500 pts'),
    phase: EnumArg(
      AtomicChallengePhase.inProgress,
      values: AtomicChallengePhase.values,
    ),
    fill: NullableDoubleArg(
      0.4,
      style: const SliderDoubleArgStyle(min: 0, max: 1, divisions: 20),
    ),
    cardWidth: DoubleArg(
      358,
      style: const SliderDoubleArgStyle(min: 280, max: 430, divisions: 30),
    ),
    featured: BoolArg(false),
    railTreatment: EnumArg(
      AtomicChallengeRailTreatment.standard,
      values: AtomicChallengeRailTreatment.values,
    ),
  ),
  scenarios: [
    _Scenario(
      name: 'One step open',
      args: _atomicArgs(
        title: 'Fill in Survey',
        leftText: '0 / 1',
        rightText: '500 pts',
        phase: AtomicChallengePhase.open,
        fill: 0,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'One step pending',
      args: _atomicArgs(
        title: 'Fill in Survey',
        leftText: '1 / 1',
        rightText: 'pending 500 pts',
        phase: AtomicChallengePhase.pendingFinalization,
        fill: 1,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'One step completed',
      args: _atomicArgs(
        title: 'Fill in Survey',
        leftText: '1 / 1',
        rightText: 'completed 500 pts',
        phase: AtomicChallengePhase.completed,
        fill: 1,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Counted open',
      args: _atomicArgs(
        title: 'Give Kudos',
        leftText: '0 / 5',
        rightText: '0 / 1,500 pts',
        phase: AtomicChallengePhase.open,
        fill: 0,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Counted progress',
      args: _atomicArgs(
        title: 'Give Kudos',
        leftText: '2 / 5',
        rightText: '400 / 1,500 pts',
        phase: AtomicChallengePhase.inProgress,
        fill: 0.4,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Counted pending',
      args: _atomicArgs(
        title: 'Give Kudos',
        leftText: '5 / 5',
        rightText: 'pending 1,500 pts',
        phase: AtomicChallengePhase.pendingFinalization,
        fill: 1,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Submitted review',
      args: _atomicArgs(
        title: 'Propose an app change',
        leftText: 'Submitted',
        rightText: 'waiting review',
        phase: AtomicChallengePhase.pendingFinalization,
        fill: null,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Continuous atomic',
      args: _atomicArgs(
        title: 'Produce blocks this month',
        leftText: '90% success',
        rightText: '4,500 / 6,500 pts',
        phase: AtomicChallengePhase.inProgress,
        fill: 0.9,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Background block production',
      args: _atomicArgs(
        title: 'Produce Every Block',
        leftText: '90% success',
        rightText: 'Earned 10,550.1 pts',
        phase: AtomicChallengePhase.inProgress,
        fill: null,
        railTreatment: AtomicChallengeRailTreatment.technicalOngoing,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Economic eligible',
      args: _atomicArgs(
        title: 'Opinion Market',
        leftText: 'Eligible',
        rightText: '2,500 / 5,000 pts',
        phase: AtomicChallengePhase.inProgress,
        fill: 0.5,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Featured action',
      args: _atomicArgs(
        title: 'Propose an app change',
        leftText: '0 / 1',
        rightText: '500 pts',
        phase: AtomicChallengePhase.open,
        fill: 0,
        featured: true,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Featured progress',
      args: _atomicArgs(
        title: 'Give Kudos',
        leftText: '2 / 5',
        rightText: '400 / 1,500 pts',
        phase: AtomicChallengePhase.inProgress,
        fill: 0.4,
        featured: true,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Featured completed',
      args: _atomicArgs(
        title: 'Propose an app change',
        leftText: '1 / 1',
        rightText: 'earned 500 pts',
        phase: AtomicChallengePhase.completed,
        fill: 1,
        featured: true,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Narrow long title',
      args: _atomicArgs(
        title: 'Submit a dApp improvement proposal',
        leftText: '0 / 1',
        rightText: '500 pts',
        phase: AtomicChallengePhase.open,
        fill: 0,
        cardWidth: 300,
        featuredTogglable: false,
      ),
    ),
  ],
);

final $BackgroundBlockProduction = _Story(
  name: 'Background block production',
  args: _atomicArgs(
    title: 'Produce Every Block',
    leftText: '90% success',
    rightText: 'Earned 10,550.1 pts',
    phase: AtomicChallengePhase.inProgress,
    fill: null,
    railTreatment: AtomicChallengeRailTreatment.technicalOngoing,
    featuredTogglable: false,
  ),
);

/// Widgetbook-only exploration of the atomic challenge rail model.
///
/// Each card represents exactly one earning mechanic and one verification path.
/// Pending labels are reserved for the finalization gap after the user action
/// is complete.
class AtomicChallengeCard extends StatelessWidget {
  const AtomicChallengeCard({
    super.key,
    required this.title,
    required this.leftText,
    required this.rightText,
    required this.phase,
    required this.fill,
    required this.onTap,
    this.featured = false,
    this.railTreatment = AtomicChallengeRailTreatment.standard,
    this.cardTreatment = AtomicChallengeCardTreatment.card,
  });

  final String title;
  final String leftText;
  final String rightText;
  final AtomicChallengePhase phase;
  final double? fill;
  final VoidCallback onTap;
  final bool featured;
  final AtomicChallengeRailTreatment railTreatment;
  final AtomicChallengeCardTreatment cardTreatment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final borders = Theme.of(context).extension<AppBorders>()!;
    final borderRadius = featured
        ? radii.borderRadiusXLarge
        : radii.borderRadiusLargeIncreased;
    final cardColor = featured
        ? semantic.premium.colorSurface
        : colors.surfaceContainerLowest;
    final borderSide = featured
        ? BorderSide.none
        : BorderSide(color: colors.outlineVariant, width: borders.width);

    if (cardTreatment == AtomicChallengeCardTreatment.listItem) {
      return Semantics(
        button: true,
        label: '$title, $leftText, $rightText',
        child: InkWell(
          onTap: onTap,
          borderRadius: radii.borderRadiusMedium,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.space8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: featured
                      ? textTheme.titleMedium?.copyWith(
                          color: semantic.premium.onColorSurface,
                        )
                      : textTheme.titleMedium,
                ),
                SizedBox(height: spacing.space8),
                _AtomicRail(
                  leftText: leftText,
                  rightText: rightText,
                  phase: phase,
                  fill: fill,
                  featured: featured,
                  treatment: railTreatment,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      color: cardColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: borderSide,
      ),
      child: Semantics(
        button: true,
        label: '$title, $leftText, $rightText',
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.space16,
              spacing.space16,
              spacing.space16,
              spacing.space16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: featured
                      ? textTheme.titleMedium?.copyWith(
                          color: semantic.premium.onColorSurface,
                        )
                      : textTheme.titleMedium,
                ),
                SizedBox(height: spacing.space8),
                _AtomicRail(
                  leftText: leftText,
                  rightText: rightText,
                  phase: phase,
                  fill: fill,
                  featured: featured,
                  treatment: railTreatment,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AtomicRail extends StatelessWidget {
  const _AtomicRail({
    required this.leftText,
    required this.rightText,
    required this.phase,
    required this.fill,
    required this.featured,
    required this.treatment,
  });

  final String leftText;
  final String rightText;
  final AtomicChallengePhase phase;
  final double? fill;
  final bool featured;
  final AtomicChallengeRailTreatment treatment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final borders = Theme.of(context).extension<AppBorders>()!;
    final opacity = Theme.of(context).extension<AppOpacity>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final textTheme = Theme.of(context).textTheme;
    final railColors = _railColors(context);
    final clampedFill = fill?.clamp(0.0, 1.0).toDouble();
    final showProgress =
        treatment != AtomicChallengeRailTreatment.technicalOngoing &&
        clampedFill != null &&
        clampedFill > 0 &&
        phase != AtomicChallengePhase.open;
    final borderRadius = radii.borderRadiusLarge;
    final progressValue = showProgress ? clampedFill : 0.0;

    final rail = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: treatment == AtomicChallengeRailTreatment.technicalOngoing
            ? null
            : featured && phase != AtomicChallengePhase.completed
            ? Border.all(
                color: colors.onSurface.withValues(alpha: opacity.secondary),
                width: borders.width,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          height: spacing.space48,
          child: Stack(
            fit: StackFit.expand,
            children: [
              LinearProgressIndicator(
                value: progressValue,
                minHeight: spacing.space48,
                backgroundColor: railColors.track,
                color: railColors.fill,
                borderRadius: borderRadius,
                semanticsLabel: 'Challenge progress',
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.space16),
                child: Row(
                  children: [
                    Flexible(
                      flex: 2,
                      fit: FlexFit.tight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (phase == AtomicChallengePhase.completed) ...[
                            Icon(
                              Symbols.check_circle_sharp,
                              size: sizing.iconSmall,
                              color: railColors.leftText,
                            ),
                            SizedBox(width: spacing.space4),
                          ],
                          Flexible(
                            child: _RailLeftText(
                              value: leftText,
                              color: railColors.leftText,
                              subduedColor: railColors.leftSubtleText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: spacing.space12),
                    Flexible(
                      flex: 3,
                      fit: FlexFit.tight,
                      child: Text(
                        rightText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: textTheme.labelMedium?.copyWith(
                          color: railColors.rightText,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (treatment == AtomicChallengeRailTreatment.technicalOngoing) {
      final semantic = Theme.of(context).extension<AppSemanticColors>()!;
      return _OngoingRailFrame(
        color: semantic.technical.color,
        borderRadius: radii.large,
        child: rail,
      );
    }

    return rail;
  }

  ({
    Color track,
    Color fill,
    Color leftText,
    Color leftSubtleText,
    Color rightText,
  })
  _railColors(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    if (treatment == AtomicChallengeRailTreatment.technicalOngoing) {
      return (
        track: colors.surfaceContainerLowest,
        fill: Colors.transparent,
        leftText: colors.onSurface,
        leftSubtleText: colors.onSurfaceVariant,
        rightText: colors.onSurface,
      );
    }

    if (featured) {
      return switch (phase) {
        AtomicChallengePhase.open => (
          track: Colors.transparent,
          fill: Colors.transparent,
          leftText: semantic.premium.onColorSurface,
          leftSubtleText: semantic.premium.onColorSurface.withValues(
            alpha: 0.58,
          ),
          rightText: semantic.premium.onColorSurface,
        ),
        AtomicChallengePhase.inProgress => (
          track: Colors.transparent,
          fill: semantic.premium.color,
          leftText: semantic.premium.onColor,
          leftSubtleText: semantic.premium.onColor.withValues(alpha: 0.58),
          rightText: semantic.premium.onColorSurface,
        ),
        AtomicChallengePhase.pendingFinalization => (
          track: semantic.premium.colorContainer,
          fill: semantic.premium.colorContainer,
          leftText: semantic.premium.onColorContainer,
          leftSubtleText: semantic.premium.onColorContainer.withValues(
            alpha: 0.58,
          ),
          rightText: semantic.premium.onColorContainer,
        ),
        AtomicChallengePhase.completed => (
          track: semantic.premium.color,
          fill: semantic.premium.color,
          leftText: semantic.premium.onColor,
          leftSubtleText: semantic.premium.onColor.withValues(alpha: 0.58),
          rightText: semantic.premium.onColor,
        ),
      };
    }

    return switch (phase) {
      AtomicChallengePhase.open => (
        track: colors.surfaceContainerHighest,
        fill: Colors.transparent,
        leftText: colors.onSurface,
        leftSubtleText: colors.onSurfaceVariant,
        rightText: colors.onSurfaceVariant,
      ),
      AtomicChallengePhase.inProgress => (
        track: colors.surfaceContainerLowest,
        fill: semantic.success.colorSurface,
        leftText: colors.onSurface,
        leftSubtleText: colors.onSurfaceVariant,
        rightText: colors.onSurfaceVariant,
      ),
      AtomicChallengePhase.pendingFinalization => (
        track: semantic.success.colorSurface,
        fill: semantic.success.colorSurface,
        leftText: colors.onSurface,
        leftSubtleText: colors.onSurfaceVariant,
        rightText: semantic.success.onColorSurface,
      ),
      AtomicChallengePhase.completed => (
        track: semantic.success.color,
        fill: semantic.success.color,
        leftText: semantic.success.onColor,
        leftSubtleText: semantic.success.onColor.withValues(alpha: 0.58),
        rightText: semantic.success.onColor.withValues(alpha: 0.72),
      ),
    };
  }
}

class _RailLeftText extends StatelessWidget {
  const _RailLeftText({
    required this.value,
    required this.color,
    required this.subduedColor,
  });

  static final _fractionPattern = RegExp(
    r'^\s*(\d+(?:[.,]\d+)?)\s*/\s*(\d+(?:[.,]\d+)?)\s*$',
  );

  final String value;
  final Color color;
  final Color subduedColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final match = _fractionPattern.firstMatch(value);

    if (match == null) {
      return Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.labelLarge?.copyWith(
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }

    final primaryStyle = textTheme.titleSmall?.copyWith(
      color: color,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final secondaryStyle = textTheme.titleSmall?.copyWith(
      color: subduedColor,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: match.group(1), style: primaryStyle),
          TextSpan(text: ' / ', style: secondaryStyle),
          TextSpan(text: match.group(2), style: secondaryStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _OngoingRailFrame extends StatefulWidget {
  const _OngoingRailFrame({
    required this.color,
    required this.borderRadius,
    required this.child,
  });

  final Color color;
  final double borderRadius;
  final Widget child;

  @override
  State<_OngoingRailFrame> createState() => _OngoingRailFrameState();
}

class _OngoingRailFrameState extends State<_OngoingRailFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: widget.color, width: 2),
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          foregroundPainter: _OngoingRailPainter(
            progress: _controller.value,
            color: widget.color,
            borderRadius: widget.borderRadius,
            strokeWidth: 2,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _OngoingRailPainter extends CustomPainter {
  _OngoingRailPainter({
    required this.progress,
    required this.color,
    required this.borderRadius,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double borderRadius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(borderRadius),
    );

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withValues(alpha: 0.18);
    canvas.drawRRect(rrect, trackPaint);

    final cometGradient = SweepGradient(
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0),
        color.withValues(alpha: 0.18),
        color.withValues(alpha: 0.52),
        color,
        color.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.70, 0.80, 0.90, 0.97, 1.0],
      transform: GradientRotation(progress * math.pi * 2),
    );
    final cometPaint = Paint()
      ..shader = cometGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRRect(rrect, cometPaint);
  }

  @override
  bool shouldRepaint(_OngoingRailPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.borderRadius != borderRadius;
}
