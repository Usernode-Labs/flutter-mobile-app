import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_borders.dart';
import '../tokens/app_opacity.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';

/// Lifecycle phase of an atomic challenge, driving the rail's visual treatment.
///
/// - [open]: the user has not made progress yet.
/// - [inProgress]: measurable progress exists but the challenge is not complete.
/// - [pendingFinalization]: the user action/metric is complete, but verification
///   or final point assignment is still pending.
/// - [completed]: final points have been assigned.
enum AtomicChallengePhase { open, inProgress, pendingFinalization, completed }

/// Visual treatment for the progress rail.
///
/// - [standard]: a filled progress rail for bounded metrics.
/// - [checkbox]: a state-only rail for binary (done / not done) mechanics.
/// - [technicalOngoing]: an animated frame for continuous background work
///   (e.g. block production) with no bounded fill.
enum AtomicChallengeRailTreatment { standard, checkbox, technicalOngoing }

/// Whether the card renders its own [Material] container or an inline list item.
enum AtomicChallengeCardTreatment { card, listItem }

/// A compact, scannable challenge card for the Fair Rewards challenge surface.
///
/// Each card represents exactly one earning mechanic and one verification path.
/// The card is presentation-only — it carries a title and one progress/reward
/// rail, with the whole card as the tap target. Task instructions, requirements,
/// and CTAs live on the challenge detail page, not here.
///
/// Pending labels are reserved for the finalization gap after the user action is
/// complete (see [AtomicChallengePhase.pendingFinalization]).
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

  /// Challenge title (goal).
  final String title;

  /// Metric/progress/status text, e.g. `0 / 1`, `2 / 5`, `Submitted`,
  /// `90% success`.
  final String leftText;

  /// Reward/status text, e.g. `500 pts`, `400 / 1,500 pts`, `pending 500 pts`,
  /// `waiting review`.
  final String rightText;

  /// Lifecycle phase driving the rail treatment.
  final AtomicChallengePhase phase;

  /// Bounded progress fraction. `null` means a state-only rail (no fake
  /// progress); when present it is clamped to `0..1`.
  final double? fill;

  /// Whole-card tap target.
  final VoidCallback onTap;

  /// Premium "featured" treatment for the most relevant challenge.
  final bool featured;

  /// Progress rail treatment.
  final AtomicChallengeRailTreatment railTreatment;

  /// Container vs inline list-item rendering.
  final AtomicChallengeCardTreatment cardTreatment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final borders = Theme.of(context).extension<AppBorders>()!;
    final borderRadius = radii.borderRadiusLargeIncreased;
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
          borderRadius: radii.borderRadiusFull,
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
                AtomicChallengeRail(
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

    return Material(
      color: cardColor,
      elevation: 0,
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
                AtomicChallengeRail(
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

/// The progress/reward rail rendered inside an [AtomicChallengeCard] and reused
/// as the hero element on the challenge detail screen.
class AtomicChallengeRail extends StatelessWidget {
  const AtomicChallengeRail({
    super.key,
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
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    if (treatment == AtomicChallengeRailTreatment.checkbox) {
      return _CheckboxChallengeRail(
        leftText: leftText,
        rightText: rightText,
        phase: phase,
        featured: featured,
      );
    }

    final showProgress =
        treatment != AtomicChallengeRailTreatment.technicalOngoing &&
            clampedFill != null &&
            clampedFill > 0 &&
            phase != AtomicChallengePhase.open;
    final borderRadius = radii.borderRadiusFull;
    final progressValue = showProgress ? clampedFill : 0.0;
    final showFilledTextOverlay =
        showProgress && phase == AtomicChallengePhase.inProgress;
    final filledTextColor =
        featured ? semantic.premium.onColor : semantic.success.onColor;

    Widget railContent({
      required Color leftTextColor,
      required Color leftSubtleTextColor,
      required Color rightTextColor,
    }) {
      return Padding(
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
                      color: leftTextColor,
                    ),
                    SizedBox(width: spacing.space4),
                  ],
                  Flexible(
                    child: _RailLeftText(
                      value: leftText,
                      color: leftTextColor,
                      subduedColor: leftSubtleTextColor,
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
                  color: rightTextColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final rail = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: treatment == AtomicChallengeRailTreatment.technicalOngoing
            ? null
            : featured && phase != AtomicChallengePhase.completed
                ? Border.all(
                    color:
                        colors.onSurface.withValues(alpha: opacity.secondary),
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
              railContent(
                leftTextColor: railColors.leftText,
                leftSubtleTextColor: railColors.leftSubtleText,
                rightTextColor: railColors.rightText,
              ),
              if (showFilledTextOverlay)
                ExcludeSemantics(
                  child: ClipRect(
                    clipper: _FractionalWidthClipper(progressValue),
                    child: railContent(
                      leftTextColor: filledTextColor,
                      leftSubtleTextColor:
                          filledTextColor.withValues(alpha: 0.58),
                      rightTextColor: filledTextColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (treatment == AtomicChallengeRailTreatment.technicalOngoing) {
      final semantic = Theme.of(context).extension<AppSemanticColors>()!;
      return OngoingRailFrame(
        color: semantic.technical.color,
        borderRadius: radii.full,
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
  }) _railColors(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final clampedFill = fill?.clamp(0.0, 1.0).toDouble();
    final hasVisibleProgress = clampedFill != null &&
        clampedFill > 0 &&
        phase != AtomicChallengePhase.open;

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
        AtomicChallengePhase.inProgress => hasVisibleProgress
            ? (
                track: Colors.transparent,
                fill: semantic.premium.color,
                leftText: semantic.premium.onColorSurface,
                leftSubtleText: semantic.premium.onColorSurface.withValues(
                  alpha: 0.58,
                ),
                rightText: semantic.premium.onColorSurface,
              )
            : (
                track: Colors.transparent,
                fill: Colors.transparent,
                leftText: semantic.premium.onColorSurface,
                leftSubtleText: semantic.premium.onColorSurface.withValues(
                  alpha: 0.58,
                ),
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
          fill: semantic.success.color,
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

class _FractionalWidthClipper extends CustomClipper<Rect> {
  const _FractionalWidthClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * fraction, size.height);
  }

  @override
  bool shouldReclip(_FractionalWidthClipper oldClipper) {
    return oldClipper.fraction != fraction;
  }
}

class _CheckboxChallengeRail extends StatelessWidget {
  const _CheckboxChallengeRail({
    required this.leftText,
    required this.rightText,
    required this.phase,
    required this.featured,
  });

  final String leftText;
  final String rightText;
  final AtomicChallengePhase phase;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final borders = Theme.of(context).extension<AppBorders>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final textTheme = Theme.of(context).textTheme;
    final state = _stateColors(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: state.background,
        borderRadius: radii.borderRadiusFull,
        border: Border.all(color: state.border, width: borders.width),
      ),
      child: SizedBox(
        height: spacing.space48,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.space16),
          child: Row(
            children: [
              Icon(_icon, size: sizing.iconSmall, color: state.icon),
              SizedBox(width: spacing.space8),
              Expanded(
                flex: 2,
                child: Text(
                  leftText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(color: state.leftText),
                ),
              ),
              SizedBox(width: spacing.space12),
              Expanded(
                flex: 3,
                child: Text(
                  rightText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: textTheme.labelMedium?.copyWith(
                    color: state.rightText,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _icon {
    return switch (phase) {
      AtomicChallengePhase.pendingFinalization =>
        Symbols.radio_button_checked_sharp,
      AtomicChallengePhase.completed => Symbols.task_alt_sharp,
      _ => Symbols.radio_button_unchecked_sharp,
    };
  }

  ({
    Color background,
    Color border,
    Color icon,
    Color leftText,
    Color rightText,
  }) _stateColors(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final opacity = Theme.of(context).extension<AppOpacity>()!;

    if (phase == AtomicChallengePhase.completed) {
      if (featured) {
        return (
          background: semantic.premium.color,
          border: semantic.premium.color,
          icon: semantic.premium.onColor,
          leftText: semantic.premium.onColor,
          rightText: semantic.premium.onColor.withValues(alpha: 0.72),
        );
      }

      return (
        background: semantic.success.color,
        border: semantic.success.color,
        icon: semantic.success.onColor,
        leftText: semantic.success.onColor,
        rightText: semantic.success.onColor.withValues(alpha: 0.72),
      );
    }

    if (featured) {
      return (
        background: Colors.transparent,
        border: semantic.premium.onColorSurface.withValues(
          alpha: opacity.secondary,
        ),
        icon: semantic.premium.onColorSurface,
        leftText: semantic.premium.onColorSurface,
        rightText: semantic.premium.onColorSurface,
      );
    }

    return (
      background: Colors.transparent,
      border: colors.outlineVariant,
      icon: colors.onSurfaceVariant,
      leftText: colors.onSurface,
      rightText: colors.onSurfaceVariant,
    );
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

/// An animated "comet trail" frame used to convey continuous background work
/// (e.g. block production). Falls back to a solid border when reduced motion is
/// enabled.
class OngoingRailFrame extends StatefulWidget {
  const OngoingRailFrame({
    super.key,
    required this.color,
    required this.borderRadius,
    required this.child,
    this.strokeWidth = 2,
  });

  final Color color;
  final double borderRadius;
  final Widget child;
  final double strokeWidth;

  @override
  State<OngoingRailFrame> createState() => _OngoingRailFrameState();
}

class _OngoingRailFrameState extends State<OngoingRailFrame>
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
          border: Border.all(color: widget.color, width: widget.strokeWidth),
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
            strokeWidth: widget.strokeWidth,
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
