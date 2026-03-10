import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/app_semantic_colors.dart';
import 'challenge_card.dart';

/// Renders the abstract geometric icon for a [ChallengeCategory].
///
/// Each category has a unique shape (polygon, cookie, circle) rendered via
/// [CustomPainter] with three colour layers derived from the category's
/// semantic colour group: outer fill at [SemanticColorGroup.colorSurface],
/// inner fill at [SemanticColorGroup.colorContainer], and a fully-saturated
/// stroke outline at [SemanticColorGroup.color].
///
/// When [muted] is `true` the category colour is replaced with neutral surface
/// tones (`surfaceDim` for fills, `outline` for strokes) — useful for missed
/// or inactive states.
class ChallengeCategoryIcon extends StatelessWidget {
  const ChallengeCategoryIcon({
    super.key,
    required this.category,
    this.size,
    this.muted = false,
  });

  final ChallengeCategory category;
  final double? size;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    final Color innerColor;
    final Color outerColor;
    final Color strokeColor;

    if (muted) {
      innerColor = colors.surfaceDim;
      outerColor = colors.surfaceDim;
      strokeColor = colors.outline;
    } else {
      final group = switch (category) {
        ChallengeCategory.technical => semantic.technical,
        ChallengeCategory.community => semantic.community,
        ChallengeCategory.flash => semantic.flash,
      };
      innerColor = group.colorContainer;
      outerColor = group.colorSurface;
      strokeColor = group.color;
    }

    return CustomPaint(
      size: Size.square(size ?? 48),
      painter: _CategoryIconPainter(
        category: category,
        innerColor: innerColor,
        outerColor: outerColor,
        strokeColor: strokeColor,
      ),
    );
  }
}

// ── Shared path helpers ──

Path _polygon(double size, List<Offset> vertices) {
  final path = Path();
  for (var i = 0; i < vertices.length; i++) {
    final x = vertices[i].dx * size;
    final y = vertices[i].dy * size;
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
}

Path _cookiePath(Offset center, double radius, {double scallop = 0.15}) {
  const n = 7;
  const startAngle = -math.pi / 2;
  const segments = 70;

  final path = Path();
  for (var i = 0; i <= segments; i++) {
    final theta = startAngle + 2 * math.pi * i / segments;
    final r =
        radius * (1 - scallop / 2 * (1 - math.cos(n * (theta - startAngle))));
    final x = center.dx + r * math.cos(theta);
    final y = center.dy + r * math.sin(theta);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
}

void _drawDashedPath(
  Canvas canvas,
  Path path,
  Paint paint, {
  required double dash,
  required double gap,
}) {
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = math.min(distance + dash, metric.length);
      canvas.drawPath(metric.extractPath(distance, end), paint);
      distance += dash + gap;
    }
  }
}

// ── Normalized vertex data (from 47×47 SVG viewBox) ──

// Inner fill polygon (6 vertices)
const _kTechInner = [
  Offset(0.35676, 0.14179),
  Offset(0.73974, 0.20275),
  Offset(0.87947, 0.57158),
  Offset(0.63622, 0.87945),
  Offset(0.25325, 0.81849),
  Offset(0.11352, 0.44966),
];

// Outer/surface fill polygon (8 vertices)
const _kTechOuter = [
  Offset(0.39843, 0.99298),
  Offset(0.07607, 0.77822),
  Offset(0.00000, 0.39843),
  Offset(0.21476, 0.07607),
  Offset(0.59455, 0.00000),
  Offset(0.91691, 0.21476),
  Offset(0.99298, 0.59455),
  Offset(0.77822, 0.91691),
];

// Stroke polygon (7 vertices)
const _kTechStroke = [
  Offset(0.58065, 0.25543),
  Offset(0.73756, 0.42198),
  Offset(0.70597, 0.64923),
  Offset(0.50965, 0.76606),
  Offset(0.29646, 0.68450),
  Offset(0.22692, 0.46596),
  Offset(0.35339, 0.27500),
];

// ── Painter ──

class _CategoryIconPainter extends CustomPainter {
  const _CategoryIconPainter({
    required this.category,
    required this.innerColor,
    required this.outerColor,
    required this.strokeColor,
  });

  final ChallengeCategory category;
  final Color innerColor;
  final Color outerColor;
  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    switch (category) {
      case ChallengeCategory.technical:
        _paintTechnical(canvas, size);
      case ChallengeCategory.flash:
        _paintFlash(canvas, size);
      case ChallengeCategory.community:
        _paintCommunity(canvas, size);
    }
  }

  void _paintTechnical(Canvas canvas, Size size) {
    final s = size.shortestSide;
    // Drawing order matches original SVG: outer fill → inner fill → stroke
    canvas.drawPath(
      _polygon(s, _kTechOuter),
      Paint()..color = outerColor,
    );
    canvas.drawPath(
      _polygon(s, _kTechInner),
      Paint()..color = innerColor,
    );
    canvas.drawPath(
      _polygon(s, _kTechStroke),
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = s / 47,
    );
  }

  void _paintFlash(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = size.center(Offset.zero);
    // Outer fill circle
    canvas.drawCircle(
      center,
      s * 0.5,
      Paint()..color = outerColor,
    );
    // Inner fill circle
    canvas.drawCircle(
      center,
      s * 0.405,
      Paint()..color = innerColor,
    );
    // Dashed stroke circle
    final dashOval = Path()
      ..addOval(Rect.fromCircle(center: center, radius: s * 0.25));
    _drawDashedPath(
      canvas,
      dashOval,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = s / 48
        ..strokeCap = StrokeCap.round,
      dash: s * 4 / 48,
      gap: s * 4 / 48,
    );
  }

  void _paintCommunity(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = size.center(Offset.zero);
    // Drawing order: outer fill → inner fill → stroke
    canvas.drawPath(
      _cookiePath(center, s * 0.5),
      Paint()..color = outerColor,
    );
    canvas.drawPath(
      _cookiePath(center, s * 0.425),
      Paint()..color = innerColor,
    );
    canvas.drawPath(
      _cookiePath(center, s * 0.275),
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = s / 48
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CategoryIconPainter old) =>
      category != old.category ||
      innerColor != old.innerColor ||
      outerColor != old.outerColor ||
      strokeColor != old.strokeColor;
}
