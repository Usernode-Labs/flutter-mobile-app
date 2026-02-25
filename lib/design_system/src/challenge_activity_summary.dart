import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';

class ChallengeActivitySummary extends StatelessWidget {
  const ChallengeActivitySummary({
    super.key,
    required this.completedCount,
    required this.missedCount,
    required this.totalCount,
    this.onViewCompleted,
    this.onViewMissed,
  });

  final int completedCount;
  final int missedCount;
  final int totalCount;
  final VoidCallback? onViewCompleted;
  final VoidCallback? onViewMissed;

  String get _headline {
    if (completedCount > 0) return 'All caught up!';
    if (missedCount > 0) return 'No challenges completed';
    return 'No challenges yet';
  }

  String get _summary {
    if (totalCount > 0) {
      final tackled = completedCount + missedCount;
      return "You've tackled $tackled of $totalCount challenges this season.";
    }
    return 'Check back soon for new challenges.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 160,
          width: double.infinity,
          child: CustomPaint(
            painter: _ShapeClusterPainter(
              technicalColor: semantic.technical.color,
              technicalContainer: semantic.technical.colorContainer,
              flashColor: semantic.flash.color,
              flashContainer: semantic.flash.colorContainer,
              communityColor: semantic.community.color,
              communityContainer: semantic.community.colorContainer,
            ),
          ),
        ),
        SizedBox(height: spacing.space24),
        Text(
          _headline,
          style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: spacing.space8),
        Text(
          _summary,
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: spacing.space24),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: IntrinsicWidth(
                child: _Pill(
                  icon: Symbols.check_circle_sharp,
                  label: '$completedCount Done',
                  iconColor: colors.onSurface,
                  textColor: colors.onSurface,
                  backgroundColor: colors.surfaceContainerHigh,
                  borderRadius: radii.small,
                  spacing: spacing,
                  sizing: sizing,
                  onTap: onViewCompleted,
                ),
              ),
            ),
            SizedBox(width: spacing.space12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: IntrinsicWidth(
                child: _Pill(
                  icon: Symbols.event_busy_sharp,
                  label: '$missedCount Missed',
                  iconColor: colors.onSurfaceVariant,
                  textColor: colors.onSurfaceVariant,
                  backgroundColor: colors.surfaceContainerHigh,
                  borderRadius: radii.small,
                  spacing: spacing,
                  sizing: sizing,
                  onTap: onViewMissed,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shape cluster painter
// ---------------------------------------------------------------------------

class _ShapeClusterPainter extends CustomPainter {
  _ShapeClusterPainter({
    required this.technicalColor,
    required this.technicalContainer,
    required this.flashColor,
    required this.flashContainer,
    required this.communityColor,
    required this.communityContainer,
  });

  final Color technicalColor;
  final Color technicalContainer;
  final Color flashColor;
  final Color flashContainer;
  final Color communityColor;
  final Color communityContainer;

  // Hexagon vertices normalized 0..1 (from nav_indicator_shapes.dart).
  static const _hexVertices = [
    Offset(0.3175, 0.0000),
    Offset(0.8175, 0.0825),
    Offset(1.0000, 0.5825),
    Offset(0.6825, 1.0000),
    Offset(0.1825, 0.9175),
    Offset(0.0000, 0.4175),
  ];

  // Blob radial fractions (from nav_indicator_shapes.dart).
  static const _blobRadii = [
    1.00,
    0.91,
    1.06,
    0.88,
    1.00,
    1.09,
    0.91,
    1.03,
    0.94,
    0.88,
    1.09,
    0.97,
    1.06,
    0.91,
    1.00,
    0.85,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Z-order: blob (back) → hexagon → circle (front).
    _drawShape(
      canvas,
      center: center,
      offset: const Offset(-20, 8),
      rotation: 15 * math.pi / 180,
      path: _blobPath(80),
      fill: communityContainer,
      stroke: communityColor,
    );
    _drawShape(
      canvas,
      center: center,
      offset: const Offset(-28, -20),
      rotation: -8 * math.pi / 180,
      path: _hexagonPath(88),
      fill: technicalContainer,
      stroke: technicalColor,
    );
    _drawShape(
      canvas,
      center: center,
      offset: const Offset(24, -4),
      rotation: 0,
      path: _circlePath(72),
      fill: flashContainer,
      stroke: flashColor,
    );
  }

  void _drawShape(
    Canvas canvas, {
    required Offset center,
    required Offset offset,
    required double rotation,
    required Path path,
    required Color fill,
    required Color stroke,
  }) {
    canvas.save();
    canvas.translate(center.dx + offset.dx, center.dy + offset.dy);
    if (rotation != 0) canvas.rotate(rotation);

    canvas.drawPath(
      path,
      Paint()
        ..color = fill
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75,
    );

    canvas.restore();
  }

  static Path _hexagonPath(double size) {
    final half = size / 2;
    final path = Path();
    for (var i = 0; i < _hexVertices.length; i++) {
      final v = _hexVertices[i];
      final x = v.dx * size - half;
      final y = v.dy * size - half;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  static Path _circlePath(double size) {
    final half = size / 2;
    return Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: half));
  }

  static Path _blobPath(double size) {
    final r = size / 2;
    final n = _blobRadii.length;
    final points = <Offset>[];
    for (var i = 0; i < n; i++) {
      final angle = math.pi * 2 * i / n;
      final rr = r * _blobRadii[i];
      points.add(Offset(rr * math.cos(angle), rr * math.sin(angle)));
    }

    final path = Path();
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
  bool shouldRepaint(covariant _ShapeClusterPainter oldDelegate) {
    return technicalColor != oldDelegate.technicalColor ||
        technicalContainer != oldDelegate.technicalContainer ||
        flashColor != oldDelegate.flashColor ||
        flashContainer != oldDelegate.flashContainer ||
        communityColor != oldDelegate.communityColor ||
        communityContainer != oldDelegate.communityContainer;
  }
}

// ---------------------------------------------------------------------------
// Pill widget
// ---------------------------------------------------------------------------

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.textColor,
    required this.backgroundColor,
    required this.borderRadius,
    required this.spacing,
    required this.sizing,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;
  final Color backgroundColor;
  final double borderRadius;
  final AppSpacing spacing;
  final AppSizing sizing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    );

    Widget content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.space12,
        vertical: spacing.space8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: sizing.iconSmall,
            color: iconColor,
            weight: 300,
            opticalSize: 20,
          ),
          SizedBox(width: spacing.space4),
          Flexible(
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: textColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: backgroundColor,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: content,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: content,
    );
  }
}
