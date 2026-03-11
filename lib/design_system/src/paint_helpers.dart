import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// Generates a scalloped "cookie" path with [n]=7 lobes.
Path cookiePath(Offset center, double radius, {double scallop = 0.15}) {
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

/// Draws [path] as a dashed line with the given [dash] and [gap] lengths.
void drawDashedPath(
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
