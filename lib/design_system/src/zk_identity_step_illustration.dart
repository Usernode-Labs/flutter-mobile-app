import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated line-art illustration for each step of the ZK Identity flow.
///
/// Ultra-minimal technical drawing style: thin strokes, simple geometry,
/// generous negative space. Achromatic — resolves colors from [ColorScheme].
///
/// [stepIndex] 0–4:
///   0 = Check App, 1 = Confirm Scanned, 2 = Ready to Verify,
///   3 = Verification, 4 = Result.
class ZkIdentityStepIllustration extends StatefulWidget {
  const ZkIdentityStepIllustration({
    super.key,
    required this.stepIndex,
  });

  final int stepIndex;

  @override
  State<ZkIdentityStepIllustration> createState() =>
      _ZkIdentityStepIllustrationState();
}

class _ZkIdentityStepIllustrationState extends State<ZkIdentityStepIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.stepIndex == 4
          ? const Duration(milliseconds: 800)
          : const Duration(seconds: 8),
    );
    if (widget.stepIndex == 4) {
      _controller.forward();
    } else {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(ZkIdentityStepIllustration old) {
    super.didUpdateWidget(old);
    if (old.stepIndex != widget.stepIndex) {
      _controller.stop();
      _controller.duration = widget.stepIndex == 4
          ? const Duration(milliseconds: 800)
          : const Duration(seconds: 8);
      _controller.reset();
      if (widget.stepIndex == 4) {
        _controller.forward();
      } else {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final illustrationWidth = constraints.maxWidth * 0.618;
        final illustrationHeight = illustrationWidth * 0.75;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              size: Size(illustrationWidth, illustrationHeight),
              painter: _StepPainter(
                progress: _controller.value,
                stepIndex: widget.stepIndex,
                lineColor: colorScheme.onSurface,
                dimColor: colorScheme.outlineVariant,
              ),
            );
          },
        );
      },
    );
  }
}

// ── Painter ──────────────────────────────────────────────────────────────────

class _StepPainter extends CustomPainter {
  const _StepPainter({
    required this.progress,
    required this.stepIndex,
    required this.lineColor,
    required this.dimColor,
  });

  final double progress;
  final int stepIndex;
  final Color lineColor;
  final Color dimColor;

  /// All hard-coded dimensions were designed for a 200×150 reference canvas.
  /// Denominator 110 makes the main 100-wide frame fill ~91% of the canvas.
  double _scale(Size size) => size.width / 110;

  @override
  void paint(Canvas canvas, Size size) {
    switch (stepIndex) {
      case 0:
        _paintCheckApp(canvas, size);
      case 1:
        _paintConfirmScanned(canvas, size);
      case 2:
        _paintReadyToVerify(canvas, size);
      case 3:
        _paintVerification(canvas, size);
      case 4:
        _paintResult(canvas, size);
    }
  }

  // Step 0 — Sharp rect frame + scan line.
  void _paintCheckApp(Canvas canvas, Size size) {
    final s = _scale(size);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final stroke = _stroke(lineColor);

    // Frame (background — dim).
    final frame = Rect.fromCenter(
      center: Offset(cx, cy),
      width: 100 * s,
      height: 80 * s,
    );
    canvas.drawRect(frame, _stroke(dimColor));

    // Scan line sweeps top→bottom (4s cycle) — emphasized.
    final scanT = (progress * 8 / 4) % 1.0;
    final scanY = frame.top + 1 + scanT * (frame.height - 2);
    canvas.drawLine(
      Offset(frame.left + 1, scanY),
      Offset(frame.right - 1, scanY),
      stroke,
    );
  }

  // Step 1 — Vertical data lines, staggered.
  void _paintConfirmScanned(Canvas canvas, Size size) {
    final s = _scale(size);
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Outer frame.
    final frame = Rect.fromCenter(
      center: Offset(cx, cy),
      width: 100 * s,
      height: 80 * s,
    );
    canvas.drawRect(frame, _stroke(lineColor));

    // Data lines — thin verticals, irregular spacing/height.
    const xOffsets = [-30.0, -18.0, -8.0, 6.0, 22.0];
    const heights = [48.0, 32.0, 56.0, 40.0, 44.0];
    final cycle = (progress * 8 / 5) % 1.0;

    for (var i = 0; i < 5; i++) {
      final delay = i * 0.06;
      final alpha = ((cycle - delay) / 0.12).clamp(0.0, 1.0);
      if (alpha <= 0) continue;

      final x = cx + xOffsets[i] * s;
      final h = heights[i] * s;
      final top = frame.top + (frame.height - h) / 2;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + h),
        _stroke(lineColor.withValues(alpha: alpha)),
      );
    }
  }

  // Step 2 — Two offset overlapping sharp rects.
  void _paintReadyToVerify(Canvas canvas, Size size) {
    final s = _scale(size);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final drift = 3 * s * math.sin(progress * 2 * math.pi);

    // Back rect (dim).
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx - 8 * s + drift, cy - 6 * s - drift),
        width: 80 * s,
        height: 64 * s,
      ),
      _stroke(dimColor),
    );

    // Front rect (lineColor).
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx + 8 * s - drift, cy + 6 * s + drift),
        width: 80 * s,
        height: 64 * s,
      ),
      _stroke(lineColor),
    );
  }

  // Step 3 — Circle + dashed orbit + travelling dot.
  void _paintVerification(Canvas canvas, Size size) {
    final s = _scale(size);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);

    // Small center circle.
    canvas.drawCircle(center, 4 * s, _stroke(lineColor));

    // Dashed orbit.
    final orbitR = 40.0 * s;
    final orbit = Path()
      ..addOval(Rect.fromCircle(center: center, radius: orbitR));
    _drawDashed(canvas, orbit, _stroke(dimColor), dash: 4 * s, gap: 4 * s);

    // Orbiting dot (6s period).
    final angle = -math.pi / 2 + progress * 2 * math.pi * 8 / 6;
    canvas.drawCircle(
      Offset(cx + orbitR * math.cos(angle), cy + orbitR * math.sin(angle)),
      3 * s,
      Paint()..color = lineColor,
    );
  }

  // Step 4 — Checkmark drawn on once.
  void _paintResult(Canvas canvas, Size size) {
    final s = _scale(size);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final t = Curves.easeOut.transform(progress);

    // Circle outline fades in.
    canvas.drawCircle(
      Offset(cx, cy),
      32 * s,
      _stroke(lineColor.withValues(alpha: t)),
    );

    // Checkmark drawn on via path metrics.
    final check = Path()
      ..moveTo(cx - 14 * s, cy + 1 * s)
      ..lineTo(cx - 4 * s, cy + 12 * s)
      ..lineTo(cx + 16 * s, cy - 10 * s);
    final metric = check.computeMetrics().first;
    final len = metric.length * t;
    if (len > 0) {
      canvas.drawPath(
        metric.extractPath(0, len),
        Paint()
          ..color = lineColor.withValues(alpha: t)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Paint _stroke(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  static void _drawDashed(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = math.min(d + dash, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_StepPainter old) =>
      progress != old.progress ||
      stepIndex != old.stepIndex ||
      lineColor != old.lineColor ||
      dimColor != old.dimColor;
}
