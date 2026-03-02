import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../tokens/app_opacity.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_spacing.dart';
import 'button.dart';

/// Which text the countdown row displays.
enum CountdownTextMode {
  /// Normal countdown (label + time).
  normal,

  /// Intermediate "CATCHING UP..." during pull-to-refresh.
  catchingUp,

  /// Celebratory "ALL CAUGHT UP!" after refresh completes.
  caughtUp,
}

/// Visual variant for [ScoreHeader].
enum ScoreHeaderVariant {
  /// Plain white circle, no glow.
  standard,

  /// Multi-color glow shadows around circle representing verified
  /// ecosystem membership (technical/flash/community pillars).
  glow,
}

/// A centered score display with circular progress arc, rank label,
/// countdown timer, and CTA button.
///
/// Two variants: [ScoreHeaderVariant.standard] (clean circle) and
/// [ScoreHeaderVariant.glow] (multi-color box shadows representing
/// verified membership across the three ecosystem pillars).
class ScoreHeader extends StatelessWidget {
  const ScoreHeader({
    super.key,
    required this.score,
    required this.scoreLabel,
    this.rankLabel,
    this.progress = 0.0,
    this.progressColor,
    this.countdownLabel = 'ENDS IN',
    this.countdownTime,
    this.ctaLabel,
    this.onCtaTap,
    this.variant = ScoreHeaderVariant.standard,
    this.glowIntensity = 1.0,
    this.technicalGlowIntensity,
    this.flashGlowIntensity,
    this.communityGlowIntensity,
    this.countdownOpacity = 1.0,
    this.countdownTextMode = CountdownTextMode.normal,
  });

  /// The score value displayed prominently, e.g. "8,000".
  final String score;

  /// Label below the score, e.g. "points".
  final String scoreLabel;

  /// Optional rank text above the score, e.g. "Rank 44".
  final String? rankLabel;

  /// Progress arc value from 0.0 to 1.0.
  final double progress;

  /// Color for the progress arc. Defaults to [ColorScheme.primary].
  final Color? progressColor;

  /// Label before the countdown time. Defaults to "ENDS IN".
  final String? countdownLabel;

  /// Countdown time text, e.g. "12 DAYS 5H 3M". Hidden if null.
  final String? countdownTime;

  /// CTA button label, e.g. "View in Leaderboard". Hidden if null.
  final String? ctaLabel;

  /// Called when the CTA button is tapped.
  final VoidCallback? onCtaTap;

  /// Visual variant — standard or glow.
  final ScoreHeaderVariant variant;

  /// Glow intensity from 0.0 (off) to 1.0 (full). Only used with
  /// [ScoreHeaderVariant.glow]. Defaults to 1.0.
  final double glowIntensity;

  /// Per-lobe intensity overrides (0.0–1.0). When non-null and > 0,
  /// the glow painter renders even in [ScoreHeaderVariant.standard],
  /// enabling transient glow effects like pull-to-refresh heartbeats.
  final double? technicalGlowIntensity;
  final double? flashGlowIntensity;
  final double? communityGlowIntensity;

  /// Opacity for the countdown text row (0.0–1.0). Driven externally by
  /// heartbeat animation during pull-to-refresh.
  final double countdownOpacity;

  /// Which text the countdown row displays (normal / catchingUp / caughtUp).
  final CountdownTextMode countdownTextMode;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: spacing.space32),
        _ScoreCircle(
          score: score,
          scoreLabel: scoreLabel,
          rankLabel: rankLabel,
          progress: progress,
          progressColor: progressColor,
          variant: variant,
          glowIntensity: glowIntensity,
          technicalGlowIntensity: technicalGlowIntensity,
          flashGlowIntensity: flashGlowIntensity,
          communityGlowIntensity: communityGlowIntensity,
        ),
        SizedBox(height: spacing.space24),
        _CountdownRow(
          label: countdownLabel ?? 'ENDS IN',
          time: countdownTime ?? '--',
          opacity: countdownOpacity,
          textMode: countdownTextMode,
        ),
        if (ctaLabel != null) SizedBox(height: spacing.space48),
        if (ctaLabel != null)
          Button(
            label: ctaLabel!,
            onTap: onCtaTap,
            size: ButtonSize.small,
            variant: ButtonVariant.surface,
          ),
        SizedBox(height: spacing.space32),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _ScoreCircle — 160px circle with rank/score/label + progress arc
// ---------------------------------------------------------------------------

class _ScoreCircle extends StatelessWidget {
  const _ScoreCircle({
    required this.score,
    required this.scoreLabel,
    this.rankLabel,
    required this.progress,
    this.progressColor,
    required this.variant,
    required this.glowIntensity,
    this.technicalGlowIntensity,
    this.flashGlowIntensity,
    this.communityGlowIntensity,
  });

  final String score;
  final String scoreLabel;
  final String? rankLabel;
  final double progress;
  final Color? progressColor;
  final ScoreHeaderVariant variant;
  final double glowIntensity;
  final double? technicalGlowIntensity;
  final double? flashGlowIntensity;
  final double? communityGlowIntensity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    const circleSize = 160.0;
    final isGlow = variant == ScoreHeaderVariant.glow;

    final resolvedProgressColor = progressColor ?? colors.primary;

    final circle = SizedBox(
      width: circleSize,
      height: circleSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isGlow ? colors.surfaceContainerLowest : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (rankLabel != null)
                  Text(
                    rankLabel!,
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.outline,
                    ),
                  ),
                Text(
                  score,
                  style: textTheme.displaySmall?.copyWith(
                    fontFamily: 'IBMPlexMono',
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  scoreLabel,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.outline,
                  ),
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(circleSize, circleSize),
            painter: _ScoreArcPainter(
              progress: progress,
              color: resolvedProgressColor,
              trackOpacity: Theme.of(context).extension<AppOpacity>()!.subtle,
            ),
          ),
        ],
      ),
    );

    // Render glow when variant is glow OR when any per-lobe override is active.
    final hasPerLobe =
        (technicalGlowIntensity != null && technicalGlowIntensity! > 0) ||
            (flashGlowIntensity != null && flashGlowIntensity! > 0) ||
            (communityGlowIntensity != null && communityGlowIntensity! > 0);

    if (isGlow || hasPerLobe) {
      final semantic = Theme.of(context).extension<AppSemanticColors>()!;
      return CustomPaint(
        painter: _GlowPainter(
          communityColor: _neonify(semantic.community.color),
          flashColor: _neonify(semantic.flash.color),
          technicalColor: _neonify(semantic.technical.color),
          intensity: isGlow ? glowIntensity.clamp(0.0, 1.0) : 0.0,
          technicalIntensity: technicalGlowIntensity,
          flashIntensity: flashGlowIntensity,
          communityIntensity: communityGlowIntensity,
        ),
        isComplex: true,
        child: circle,
      );
    }

    return circle;
  }
}

// ---------------------------------------------------------------------------
// _ScoreArcPainter — circular progress arc from 12 o'clock
// ---------------------------------------------------------------------------

class _ScoreArcPainter extends CustomPainter {
  _ScoreArcPainter({
    required this.progress,
    required this.color,
    required this.trackOpacity,
  });

  final double progress;
  final Color color;
  final double trackOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1; // inset slightly for stroke
    const strokeWidth = 1.5;

    // Track circle
    final trackPaint = Paint()
      ..color = color.withValues(alpha: trackOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final arcPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // start at 12 o'clock
        sweepAngle,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScoreArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackOpacity != trackOpacity;
  }
}

// ---------------------------------------------------------------------------
// _neonify — derive neon variant from semantic token
// ---------------------------------------------------------------------------

Color _neonify(Color base) {
  final hsl = HSLColor.fromColor(base);
  return hsl.withSaturation(1.0).withLightness(0.55).toColor();
}

// ---------------------------------------------------------------------------
// _GlowPainter — additive-blended radial glow behind score circle
// ---------------------------------------------------------------------------

class _GlowPainter extends CustomPainter {
  _GlowPainter({
    required this.communityColor,
    required this.flashColor,
    required this.technicalColor,
    required this.intensity,
    this.technicalIntensity,
    this.flashIntensity,
    this.communityIntensity,
  });

  final Color communityColor;
  final Color flashColor;
  final Color technicalColor;

  /// 0.0 = no glow, 1.0 = full glow. Scales both alpha and radius.
  final double intensity;

  /// Per-lobe intensity overrides. Null = use [intensity].
  final double? technicalIntensity;
  final double? flashIntensity;
  final double? communityIntensity;

  @override
  void paint(Canvas canvas, Size size) {
    final techI = (technicalIntensity ?? intensity).clamp(0.0, 1.0);
    final flashI = (flashIntensity ?? intensity).clamp(0.0, 1.0);
    final commI = (communityIntensity ?? intensity).clamp(0.0, 1.0);
    final maxI = math.max(techI, math.max(flashI, commI));

    if (maxI <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);

    // Oversized bounds so radial gradients can extend beyond the child widget.
    final layerBounds = Rect.fromCenter(
      center: center,
      width: size.width + 600 * maxI,
      height: size.height + 600 * maxI,
    );

    canvas.saveLayer(layerBounds, Paint());

    // -- Layer 0: Sweep gradient base (angular continuity) --
    // Cycles green→amber→blue→green with dwell zones for organic mesh feel.
    // Each color zone uses its own per-lobe alpha.
    final flashSweepAlpha = 0.45 * flashI;
    final commSweepAlpha = 0.45 * commI;
    final techSweepAlpha = 0.45 * techI;
    final sweepRadius = 300 * maxI;
    final sweepPaint = Paint()
      ..blendMode = BlendMode.srcOver
      ..shader = ui.Gradient.sweep(
        center,
        [
          flashColor.withValues(alpha: flashSweepAlpha),
          flashColor.withValues(alpha: flashSweepAlpha),
          communityColor.withValues(alpha: commSweepAlpha),
          communityColor.withValues(alpha: commSweepAlpha),
          technicalColor.withValues(alpha: techSweepAlpha),
          technicalColor.withValues(alpha: techSweepAlpha),
          flashColor.withValues(alpha: flashSweepAlpha),
        ],
        [0.0, 0.083, 0.333, 0.417, 0.667, 0.750, 1.0],
        TileMode.clamp,
        0.0,
        math.pi * 2,
        _rotationMatrix(center, math.pi / 2),
      );
    canvas.drawCircle(center, sweepRadius, sweepPaint);

    // -- Layer 1: Radial fade mask (dstIn) --
    final maskRadius = 330 * maxI;
    final maskPaint = Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = ui.Gradient.radial(
        center,
        maskRadius,
        [
          const Color.fromRGBO(255, 255, 255, 1.0),
          const Color.fromRGBO(255, 255, 255, 0.75),
          const Color.fromRGBO(255, 255, 255, 0.40),
          const Color.fromRGBO(255, 255, 255, 0.10),
          const Color.fromRGBO(255, 255, 255, 0.0),
        ],
        [0.0, 0.30, 0.60, 0.85, 1.0],
      );
    canvas.drawCircle(center, maskRadius, maskPaint);

    // -- Layer 2: Three offset radial lobes (organic asymmetry) --
    _drawLobe(
      canvas,
      center + Offset(-130 * commI, -75 * commI),
      communityColor,
      220,
      0.35,
      commI,
    );
    _drawLobe(
      canvas,
      center + Offset(0, 150 * flashI),
      flashColor,
      220,
      0.35,
      flashI,
    );
    _drawLobe(
      canvas,
      center + Offset(130 * techI, -75 * techI),
      technicalColor,
      220,
      0.35,
      techI,
    );

    // -- Layer 3: Center white lift (subtle luminance boost) --
    final liftRadius = 100 * maxI;
    final liftAlpha = 0.12 * maxI;
    final liftPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        center,
        liftRadius,
        [
          Color.fromRGBO(255, 255, 255, liftAlpha),
          Color.fromRGBO(255, 255, 255, 0),
        ],
        [0.0, 1.0],
      );
    canvas.drawCircle(center, liftRadius, liftPaint);

    canvas.restore();
  }

  /// Rotation matrix for sweep gradient alignment.
  Float64List _rotationMatrix(Offset center, double radians) {
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    final tx = center.dx - cos * center.dx + sin * center.dy;
    final ty = center.dy - sin * center.dx - cos * center.dy;
    return Float64List.fromList([
      cos, sin, 0, 0, // column 0
      -sin, cos, 0, 0, // column 1
      0, 0, 1, 0, // column 2
      tx, ty, 0, 1, // column 3
    ]);
  }

  /// Draws a single radial lobe with 6-stop Gaussian falloff.
  void _drawLobe(
    Canvas canvas,
    Offset center,
    Color color,
    double baseRadius,
    double peakAlpha,
    double lobeIntensity,
  ) {
    if (lobeIntensity <= 0) return;
    final radius = baseRadius * lobeIntensity;
    final alpha = peakAlpha * lobeIntensity;
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(center, radius, [
        color.withValues(alpha: alpha),
        color.withValues(alpha: alpha * 0.85),
        color.withValues(alpha: alpha * 0.55),
        color.withValues(alpha: alpha * 0.25),
        color.withValues(alpha: alpha * 0.08),
        color.withValues(alpha: 0),
      ], [
        0.0,
        0.15,
        0.35,
        0.55,
        0.78,
        1.0,
      ]);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) {
    return oldDelegate.communityColor != communityColor ||
        oldDelegate.flashColor != flashColor ||
        oldDelegate.technicalColor != technicalColor ||
        oldDelegate.intensity != intensity ||
        oldDelegate.technicalIntensity != technicalIntensity ||
        oldDelegate.flashIntensity != flashIntensity ||
        oldDelegate.communityIntensity != communityIntensity;
  }
}

// ---------------------------------------------------------------------------
// _CountdownRow — dot + "ENDS IN" + time text
// ---------------------------------------------------------------------------

class _CountdownRow extends StatelessWidget {
  const _CountdownRow({
    required this.label,
    required this.time,
    required this.opacity,
    required this.textMode,
  });

  final String label;
  final String time;
  final double opacity;
  final CountdownTextMode textMode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    final Widget content;
    switch (textMode) {
      case CountdownTextMode.catchingUp:
        content = Text(
          'CATCHING UP...',
          style: textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        );
      case CountdownTextMode.caughtUp:
        content = Text(
          'ALL CAUGHT UP!',
          style: textTheme.labelSmall?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        );
      case CountdownTextMode.normal:
        content = Row(
          mainAxisSize: MainAxisSize.min,
          spacing: spacing.space8,
          children: [
            Text(
              label.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            Text(
              time.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
    }

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: content,
    );
  }
}
