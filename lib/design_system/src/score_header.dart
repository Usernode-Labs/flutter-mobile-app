import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../tokens/app_opacity.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_spacing.dart';
import 'button.dart';

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

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ScoreCircle(
          score: score,
          scoreLabel: scoreLabel,
          rankLabel: rankLabel,
          progress: progress,
          progressColor: progressColor,
          variant: variant,
          glowIntensity: glowIntensity,
        ),
        SizedBox(height: spacing.space24),
        if (countdownTime != null)
          _CountdownRow(
            label: countdownLabel ?? 'ENDS IN',
            time: countdownTime!,
          ),
        if (countdownTime != null) SizedBox(height: spacing.space24),
        if (ctaLabel != null)
          Button(
            label: ctaLabel!,
            onTap: onCtaTap,
          ),
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
  });

  final String score;
  final String scoreLabel;
  final String? rankLabel;
  final double progress;
  final Color? progressColor;
  final ScoreHeaderVariant variant;
  final double glowIntensity;

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
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (rankLabel != null)
                  Text(
                    rankLabel!,
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                Text(
                  score,
                  style: textTheme.displaySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  scoreLabel,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
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

    if (isGlow) {
      final semantic = Theme.of(context).extension<AppSemanticColors>()!;
      return CustomPaint(
        painter: _GlowPainter(
          communityColor: _neonify(semantic.community.color),
          flashColor: _neonify(semantic.flash.color),
          technicalColor: _neonify(semantic.technical.color),
          intensity: glowIntensity.clamp(0.0, 1.0),
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
  });

  final Color communityColor;
  final Color flashColor;
  final Color technicalColor;

  /// 0.0 = no glow, 1.0 = full glow. Scales both alpha and radius.
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);

    // Oversized bounds so radial gradients can extend beyond the child widget.
    final layerBounds = Rect.fromCenter(
      center: center,
      width: size.width + 400 * intensity,
      height: size.height + 400 * intensity,
    );

    canvas.saveLayer(layerBounds, Paint());

    // -- Community green (centered) --
    _drawGlow(canvas, center, communityColor, 140, 0.55, BlendMode.srcOver);
    _drawGlow(canvas, center, communityColor, 250, 0.25, BlendMode.plus);

    // -- Flash amber (offset right / down) --
    _drawGlow(
      canvas,
      center + Offset(80 * intensity, 60 * intensity),
      flashColor,
      120,
      0.50,
      BlendMode.plus,
    );
    _drawGlow(
      canvas,
      center + Offset(150 * intensity, 100 * intensity),
      flashColor,
      200,
      0.22,
      BlendMode.plus,
    );

    // -- Technical blue (offset left / up) --
    _drawGlow(
      canvas,
      center + Offset(-80 * intensity, -60 * intensity),
      technicalColor,
      120,
      0.50,
      BlendMode.plus,
    );
    _drawGlow(
      canvas,
      center + Offset(-150 * intensity, -100 * intensity),
      technicalColor,
      200,
      0.22,
      BlendMode.plus,
    );

    canvas.restore();
  }

  void _drawGlow(
    Canvas canvas,
    Offset center,
    Color color,
    double baseRadius,
    double baseAlpha,
    BlendMode blendMode,
  ) {
    final radius = baseRadius * intensity;
    final alpha = baseAlpha * intensity;
    final paint = Paint()
      ..blendMode = blendMode
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          color.withValues(alpha: alpha),
          color.withValues(alpha: alpha * 0.4),
          color.withValues(alpha: 0),
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) {
    return oldDelegate.communityColor != communityColor ||
        oldDelegate.flashColor != flashColor ||
        oldDelegate.technicalColor != technicalColor ||
        oldDelegate.intensity != intensity;
  }
}

// ---------------------------------------------------------------------------
// _CountdownRow — dot + "ENDS IN" + time text
// ---------------------------------------------------------------------------

class _CountdownRow extends StatelessWidget {
  const _CountdownRow({
    required this.label,
    required this.time,
  });

  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        SizedBox(width: spacing.space4),
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
}
