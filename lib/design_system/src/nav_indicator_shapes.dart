import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Which geometric shape to use as a navigation indicator.
enum NavIndicatorShape {
  /// Perfect circle inscribed in a centered square.
  circle,

  /// Irregular asymmetric hexagon (crystal) from SVG reference.
  hexagon,

  /// Organic near-circle blob with subtle radial variation.
  blob,
}

/// Returns the [ShapeBorder] for a given [NavIndicatorShape].
ShapeBorder shapeBorderFor(NavIndicatorShape shape) {
  return switch (shape) {
    NavIndicatorShape.circle => const CircleIndicatorBorder(),
    NavIndicatorShape.hexagon => const HexagonIndicatorBorder(),
    NavIndicatorShape.blob => const BlobIndicatorBorder(),
  };
}

/// Computes a centered square inscribed in [rect].
///
/// The SVG references are all 32x32 viewBox, so we inscribe a square with
/// `side = min(width, height)` centered within the rect M3 provides.
Rect _centeredSquare(Rect rect) {
  final side = math.min(rect.width, rect.height);
  return Rect.fromCenter(center: rect.center, width: side, height: side);
}

/// Circle indicator — perfect circle inscribed in a centered square.
class CircleIndicatorBorder extends ShapeBorder {
  const CircleIndicatorBorder();

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addOval(_centeredSquare(rect));
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is CircleIndicatorBorder) return this;
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is CircleIndicatorBorder) return b;
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) => other is CircleIndicatorBorder;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Irregular asymmetric hexagon (crystal) from Vector-2.svg.
///
/// SVG vertices in a 32x32 viewBox:
///   (10.16, 0)  (26.16, 2.64)  (32, 18.64)
///   (21.84, 32) (5.84, 29.36)  (0, 13.36)
class HexagonIndicatorBorder extends ShapeBorder {
  const HexagonIndicatorBorder();

  // Vertices normalized to 0..1 from the 32x32 SVG.
  static const _vertices = [
    Offset(0.3175, 0.0000), // 10.16 / 32, 0 / 32
    Offset(0.8175, 0.0825), // 26.16 / 32, 2.64 / 32
    Offset(1.0000, 0.5825), // 32 / 32, 18.64 / 32
    Offset(0.6825, 1.0000), // 21.84 / 32, 32 / 32
    Offset(0.1825, 0.9175), // 5.84 / 32, 29.36 / 32
    Offset(0.0000, 0.4175), // 0 / 32, 13.36 / 32
  ];

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final sq = _centeredSquare(rect);
    final path = Path();

    for (var i = 0; i < _vertices.length; i++) {
      final v = _vertices[i];
      final x = sq.left + v.dx * sq.width;
      final y = sq.top + v.dy * sq.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is HexagonIndicatorBorder) return this;
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is HexagonIndicatorBorder) return b;
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) => other is HexagonIndicatorBorder;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Organic near-circle blob from Vector-1.svg.
///
/// 16 anchor points at regular angular intervals with pronounced radial
/// variation (±8-15% from nominal radius), connected with quadratic bezier
/// midpoint smoothing to produce a smooth organic blob.
class BlobIndicatorBorder extends ShapeBorder {
  const BlobIndicatorBorder();

  // 16 radial fractions for an organic near-circle.
  // Values range from ~0.85 to ~1.09, producing clearly visible wobble.
  static const _radii = [
    1.00, 0.91, 1.06, 0.88, // 0° → 67.5°
    1.00, 1.09, 0.91, 1.03, // 90° → 157.5°
    0.94, 0.88, 1.09, 0.97, // 180° → 247.5°
    1.06, 0.91, 1.00, 0.85, // 270° → 337.5°
  ];

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final sq = _centeredSquare(rect);
    final cx = sq.center.dx;
    final cy = sq.center.dy;
    final r = sq.width / 2;

    final n = _radii.length;
    final points = <Offset>[];
    for (var i = 0; i < n; i++) {
      final angle = math.pi * 2 * i / n;
      final rr = r * _radii[i];
      points.add(Offset(cx + rr * math.cos(angle), cy + rr * math.sin(angle)));
    }

    final path = Path();
    // Start at midpoint between last and first point for smooth closure.
    final startMid = Offset(
      (points.last.dx + points.first.dx) / 2,
      (points.last.dy + points.first.dy) / 2,
    );
    path.moveTo(startMid.dx, startMid.dy);

    for (var i = 0; i < n; i++) {
      final p = points[i];
      final next = points[(i + 1) % n];
      final mid = Offset((p.dx + next.dx) / 2, (p.dy + next.dy) / 2);
      path.quadraticBezierTo(p.dx, p.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is BlobIndicatorBorder) return this;
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is BlobIndicatorBorder) return b;
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) => other is BlobIndicatorBorder;

  @override
  int get hashCode => runtimeType.hashCode;
}
