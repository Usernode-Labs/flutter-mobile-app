import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_elevation.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';

// ── Enums ──

enum ChallengeCardVariant {
  active,
  ongoing,
  completed,
  missed,
}

enum ChallengeCategory {
  technical,
  community,
  flash,
}

// ── Widget ──

class ChallengeCard extends StatefulWidget {
  const ChallengeCard({
    super.key,
    required this.title,
    required this.description,
    required this.dateRange,
    required this.category,
    required this.categoryIcon,
    this.variant = ChallengeCardVariant.active,
    this.rewardIcon,
    this.rewardText,
    this.earnedPoints,
    this.epochPoints,
    this.completedPoints,
    this.onTap,
  });

  final String title;
  final String description;
  final String dateRange;
  final ChallengeCategory category;
  final Widget categoryIcon;
  final ChallengeCardVariant variant;
  final IconData? rewardIcon;
  final String? rewardText;
  final String? earnedPoints;
  final String? epochPoints;
  final String? completedPoints;
  final VoidCallback? onTap;

  @override
  State<ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<ChallengeCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _borderController;

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(ChallengeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variant != widget.variant) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.variant == ChallengeCardVariant.ongoing &&
        _borderController == null) {
      _borderController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 4000),
      )..repeat();
    } else if (widget.variant != ChallengeCardVariant.ongoing &&
        _borderController != null) {
      _borderController!.dispose();
      _borderController = null;
    }
  }

  @override
  void dispose() {
    _borderController?.dispose();
    super.dispose();
  }

  SemanticColorGroup _categoryColors(AppSemanticColors semantic) {
    switch (widget.category) {
      case ChallengeCategory.technical:
        return semantic.technical;
      case ChallengeCategory.community:
        return semantic.community;
      case ChallengeCategory.flash:
        return semantic.flash;
    }
  }

  Color _contentColor(ColorScheme colors) {
    switch (widget.variant) {
      case ChallengeCardVariant.active:
      case ChallengeCardVariant.ongoing:
        return colors.onSurface;
      case ChallengeCardVariant.completed:
      case ChallengeCardVariant.missed:
        return colors.onSurfaceVariant;
    }
  }

  Color _cardBackground(ColorScheme colors) {
    switch (widget.variant) {
      case ChallengeCardVariant.active:
      case ChallengeCardVariant.ongoing:
      case ChallengeCardVariant.completed:
        return colors.surfaceContainerLowest;
      case ChallengeCardVariant.missed:
        return colors.surfaceContainerLow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final elevation = Theme.of(context).extension<AppElevation>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final catColors = _categoryColors(semantic);

    final borderRadius = BorderRadius.circular(radii.largeIncreased);

    Widget card = Container(
      decoration: BoxDecoration(
        color: _cardBackground(colors),
        borderRadius: borderRadius,
        border: widget.variant == ChallengeCardVariant.active
            ? Border.all(color: colors.outlineVariant, width: 1)
            : null,
        boxShadow: elevation.low > 0
            ? [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.05),
                  blurRadius: elevation.low * 2,
                  offset: Offset(0, elevation.low),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Content section
          Padding(
            padding: EdgeInsets.only(
              top: spacing.space16,
              bottom: spacing.space24,
              left: spacing.space16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: date range | category + icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        widget.dateRange.toUpperCase(),
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          letterSpacing: 0.28,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(right: spacing.space16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.category.name.toUpperCase(),
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              letterSpacing: 0.28,
                            ),
                          ),
                          SizedBox(width: spacing.space8),
                          SizedBox(
                            width: sizing.iconContainerRegular,
                            height: sizing.iconContainerRegular,
                            child: widget.categoryIcon,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing.space8),
                // Title
                Text(
                  widget.title,
                  style: textTheme.titleMedium?.copyWith(
                    color: _contentColor(colors),
                  ),
                ),
                SizedBox(height: spacing.space8),
                // Description
                Text(
                  widget.description,
                  style: textTheme.bodyMedium?.copyWith(
                    color: _contentColor(colors),
                  ),
                ),
              ],
            ),
          ),
          // Reward bar
          _buildRewardBar(
            colors: colors,
            textTheme: textTheme,
            spacing: spacing,
            sizing: sizing,
            catColors: catColors,
          ),
        ],
      ),
    );

    // Wrap ongoing variant with animated border
    if (widget.variant == ChallengeCardVariant.ongoing) {
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      card = _OngoingBorderWrapper(
        animation: reduceMotion ? null : _borderController,
        categoryColor: catColors.color,
        borderRadius: radii.largeIncreased,
        child: card,
      );
    }

    // Tap handler
    if (widget.onTap != null) {
      card = GestureDetector(onTap: widget.onTap, child: card);
    }

    return card;
  }

  Widget _buildRewardBar({
    required ColorScheme colors,
    required TextTheme textTheme,
    required AppSpacing spacing,
    required AppSizing sizing,
    required SemanticColorGroup catColors,
  }) {
    final rewardStyle = textTheme.bodySmall;

    switch (widget.variant) {
      case ChallengeCardVariant.active:
        return Padding(
          padding: EdgeInsets.all(spacing.space16),
          child: Row(
            children: [
              Icon(
                widget.rewardIcon ?? Symbols.rocket_launch_sharp,
                size: sizing.iconSmall,
                color: colors.onSurface,
                weight: 300,
                opticalSize: 20,
              ),
              if (widget.rewardText != null) ...[
                SizedBox(width: spacing.space4),
                Text(
                  widget.rewardText!,
                  style: rewardStyle?.copyWith(color: colors.onSurface),
                ),
              ],
            ],
          ),
        );

      case ChallengeCardVariant.ongoing:
        return Container(
          color: catColors.color,
          padding: EdgeInsets.all(spacing.space16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.check_circle_sharp,
                      size: sizing.iconSmall,
                      color: catColors.onColor,
                      weight: 300,
                      opticalSize: 20,
                    ),
                    SizedBox(width: spacing.space4),
                    Flexible(
                      child: Text(
                        'Earned ${widget.earnedPoints ?? ''}',
                        style: rewardStyle?.copyWith(color: catColors.onColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing.space8),
              Flexible(
                child: Text(
                  'Current Epoch ${widget.epochPoints ?? ''}',
                  style: rewardStyle?.copyWith(color: catColors.onColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );

      case ChallengeCardVariant.completed:
        return Container(
          color: colors.surfaceContainerHigh,
          padding: EdgeInsets.all(spacing.space16),
          child: Row(
            children: [
              Icon(
                Symbols.check_circle_sharp,
                size: sizing.iconSmall,
                color: colors.onSurface,
                weight: 300,
                opticalSize: 20,
              ),
              SizedBox(width: spacing.space4),
              Text(
                'Completed',
                style: rewardStyle?.copyWith(color: colors.onSurface),
              ),
              if (widget.completedPoints != null) ...[
                SizedBox(width: spacing.space4),
                Text(
                  widget.completedPoints!,
                  style: rewardStyle?.copyWith(color: colors.onSurface),
                ),
              ],
            ],
          ),
        );

      case ChallengeCardVariant.missed:
        return Container(
          color: colors.surfaceContainerHigh,
          padding: EdgeInsets.all(spacing.space16),
          child: Row(
            children: [
              Icon(
                Symbols.event_busy_sharp,
                size: sizing.iconSmall,
                color: colors.onSurfaceVariant,
                weight: 300,
                opticalSize: 20,
              ),
              SizedBox(width: spacing.space4),
              Text(
                'Missed',
                style: rewardStyle?.copyWith(color: colors.onSurfaceVariant),
              ),
              if (widget.completedPoints != null) ...[
                SizedBox(width: spacing.space4),
                Text(
                  widget.completedPoints!,
                  style: rewardStyle?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ],
          ),
        );
    }
  }
}

// ── Ongoing border wrapper ──

class _OngoingBorderWrapper extends StatelessWidget {
  const _OngoingBorderWrapper({
    required this.animation,
    required this.categoryColor,
    required this.borderRadius,
    required this.child,
  });

  final Animation<double>? animation;
  final Color categoryColor;
  final double borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Reduced motion fallback: solid border
    if (animation == null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: categoryColor, width: 2),
        ),
        child: child,
      );
    }

    return AnimatedBuilder(
      animation: animation!,
      builder: (context, child) {
        return CustomPaint(
          painter: _SweepBorderPainter(
            progress: animation!.value,
            color: categoryColor,
            borderRadius: borderRadius,
            strokeWidth: 2,
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// ── Sweep gradient border painter ──

class _SweepBorderPainter extends CustomPainter {
  _SweepBorderPainter({
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

    // Subtle base track — the "rail" the comet runs on
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withValues(alpha: 0.12);
    canvas.drawRRect(rrect, trackPaint);

    // Comet trail — a tight ~20% arc with a fading tail and bright head
    // 0%–70%: transparent (most of the perimeter)
    // 70%–85%: faint glow building up
    // 85%–97%: bright head
    // 97%–100%: sharp cutoff back to transparent
    final sweep = SweepGradient(
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0),
        color.withValues(alpha: 0.15),
        color.withValues(alpha: 0.5),
        color,
        color.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.70, 0.80, 0.90, 0.97, 1.0],
      transform: GradientRotation(progress * math.pi * 2),
    );

    final cometPaint = Paint()
      ..shader = sweep.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(rrect, cometPaint);
  }

  @override
  bool shouldRepaint(_SweepBorderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.borderRadius != borderRadius;
}
