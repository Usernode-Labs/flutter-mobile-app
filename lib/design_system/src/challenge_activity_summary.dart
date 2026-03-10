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

    final illustration = CustomPaint(
      size: const Size(210, 118),
      painter: _TrioIllustrationPainter(
        flashFill: semantic.flash.colorContainer,
        flashStroke: semantic.flash.onColorContainer,
        technicalFill: semantic.technical.colorContainer,
        technicalStroke: semantic.technical.onColorContainer,
        communityFill: semantic.community.colorContainer,
        communityStroke: semantic.community.onColorContainer,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: SizedBox(
            height: 128,
            width: double.infinity,
            child: Center(child: illustration),
          ),
        ),
        SizedBox(height: spacing.space4),
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
        SizedBox(height: spacing.space12),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: spacing.space12,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: IntrinsicWidth(
                child: _Pill(
                  icon: Symbols.check_circle,
                  label: '$completedCount Done',
                  iconColor: colors.onSurface,
                  textColor: colors.onSurface,
                  backgroundColor: colors.surfaceContainerLow,
                  borderRadius: radii.full,
                  spacing: spacing,
                  sizing: sizing,
                  onTap: onViewCompleted,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: IntrinsicWidth(
                child: _Pill(
                  icon: Symbols.disabled_by_default,
                  label: '$missedCount Missed',
                  iconColor: colors.onSurfaceVariant,
                  textColor: colors.onSurfaceVariant,
                  backgroundColor: colors.surfaceContainerLow,
                  borderRadius: radii.full,
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

// ── Trio illustration painter (210×118) ──

class _TrioIllustrationPainter extends CustomPainter {
  const _TrioIllustrationPainter({
    required this.flashFill,
    required this.flashStroke,
    required this.technicalFill,
    required this.technicalStroke,
    required this.communityFill,
    required this.communityStroke,
  });

  final Color flashFill;
  final Color flashStroke;
  final Color technicalFill;
  final Color technicalStroke;
  final Color communityFill;
  final Color communityStroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 210, size.height / 118);

    _paintFlash(canvas);
    _paintTechnical(canvas);
    _paintCommunity(canvas);

    canvas.restore();
  }

  void _paintFlash(Canvas canvas) {
    const center = Offset(128.764, 85.334);
    // Solid fill circle
    canvas.drawCircle(center, 26.22, Paint()..color = flashFill);
    // 0.3 opacity circle
    canvas.drawCircle(
      center,
      32.334,
      Paint()..color = flashFill.withValues(alpha: 0.3),
    );
    // Dashed stroke circle
    final dashPath = Path()
      ..addOval(
        Rect.fromCircle(center: const Offset(129.222, 85.334), radius: 16.167),
      );
    _drawDashedPath(
      canvas,
      dashPath,
      Paint()
        ..color = flashStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
      dash: 4,
      gap: 4,
    );
  }

  void _paintTechnical(Canvas canvas) {
    // Group opacity 0.6
    canvas.saveLayer(
      null,
      Paint()..color = const Color.fromRGBO(0, 0, 0, 0.6),
    );

    // Inner fill (solid)
    canvas.drawPath(
      Path()
        ..moveTo(34.8504, 13.8506)
        ..lineTo(72.2621, 19.8056)
        ..lineTo(85.9121, 55.8351)
        ..lineTo(62.1505, 85.9095)
        ..lineTo(24.7389, 79.9545)
        ..lineTo(11.0889, 43.925)
        ..close(),
      Paint()..color = technicalFill,
    );

    // Outer fill (0.3 opacity)
    canvas.drawPath(
      Path()
        ..moveTo(38.9211, 97)
        ..lineTo(7.43127, 76.021)
        ..lineTo(0, 38.9211)
        ..lineTo(20.979, 7.43127)
        ..lineTo(58.0789, 0)
        ..lineTo(89.5687, 20.979)
        ..lineTo(97, 58.0789)
        ..lineTo(76.021, 89.5687)
        ..close(),
      Paint()..color = technicalFill.withValues(alpha: 0.3),
    );

    // Stroke
    canvas.drawPath(
      Path()
        ..moveTo(56.7217, 24.9521)
        ..lineTo(72.0494, 41.2218)
        ..lineTo(68.9635, 63.4214)
        ..lineTo(49.7862, 74.8343)
        ..lineTo(28.9602, 66.867)
        ..lineTo(22.1672, 45.5187)
        ..lineTo(34.5215, 26.8644)
        ..close(),
      Paint()
        ..color = technicalStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    canvas.restore();
  }

  void _paintCommunity(Canvas canvas) {
    // Group opacity 0.5
    canvas.saveLayer(
      null,
      Paint()..color = const Color.fromRGBO(0, 0, 0, 0.5),
    );

    const center = Offset(179, 30);
    // Outer cookie (0.3 opacity)
    canvas.drawPath(
      _cookiePath(center, 29.5),
      Paint()..color = communityFill.withValues(alpha: 0.3),
    );
    // Inner cookie (solid)
    canvas.drawPath(
      _cookiePath(center, 25.1),
      Paint()..color = communityFill,
    );
    // Stroke cookie
    canvas.drawPath(
      _cookiePath(center, 21.2),
      Paint()
        ..color = communityStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.96
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrioIllustrationPainter old) =>
      flashFill != old.flashFill ||
      flashStroke != old.flashStroke ||
      technicalFill != old.technicalFill ||
      technicalStroke != old.technicalStroke ||
      communityFill != old.communityFill ||
      communityStroke != old.communityStroke;
}

// ── Shared path helpers ──

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

// ── Pill widget ──

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
        spacing: spacing.space4,
        children: [
          Icon(
            icon,
            size: sizing.iconSmall,
            color: iconColor,
          ),
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: content,
    );
  }
}
