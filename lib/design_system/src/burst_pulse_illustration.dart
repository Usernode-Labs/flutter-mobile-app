import 'package:flutter/material.dart';

import 'paint_helpers.dart';

/// Outcome of a single burst transaction, used to style the ring.
enum BurstRingOutcome { succeeded, failed }

/// Expanding concentric rings animation for the burst transactions screen.
///
/// Each entry in [rings] emits a ring from the center that expands and fades
/// over 2.5 seconds. Succeeded rings are solid; failed rings are dashed.
///
/// Presentation-only: the screen builds [rings] from provider state.
class BurstPulseIllustration extends StatefulWidget {
  const BurstPulseIllustration({
    super.key,
    required this.rings,
    this.active = true,
  });

  /// Ordered list of ring outcomes, grows as transactions complete.
  final List<BurstRingOutcome> rings;

  /// Set to false when the burst finishes. Stops the animation once all rings
  /// have expired.
  final bool active;

  @override
  State<BurstPulseIllustration> createState() => _BurstPulseIllustrationState();
}

class _BurstPulseIllustrationState extends State<BurstPulseIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Stopwatch _stopwatch = Stopwatch();
  final List<_RingState> _ringStates = [];
  int _prevRingCount = 0;
  int _totalEmitted = 0;

  static const _ringLifetime = 2.5; // seconds
  static const _shadeSteps = 5;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _prevRingCount = widget.rings.length;
    _appendNewRings(widget.rings.length);
    if (widget.rings.isNotEmpty) {
      _startAnimating();
    }
  }

  @override
  void didUpdateWidget(BurstPulseIllustration old) {
    super.didUpdateWidget(old);

    final newCount = widget.rings.length - _prevRingCount;
    if (newCount > 0) {
      if (!_stopwatch.isRunning) _startAnimating();
      _appendNewRings(newCount);
      _prevRingCount = widget.rings.length;
    }

    if (!widget.active) {
      _maybeStopIfExpired();
    }
  }

  void _appendNewRings(int count) {
    final now = _stopwatch.elapsedMilliseconds / 1000.0;
    final startIndex = widget.rings.length - count;
    for (var i = startIndex; i < widget.rings.length; i++) {
      final shade = (_totalEmitted % _shadeSteps) / (_shadeSteps - 1);
      _ringStates.add(_RingState(
        birthTime: now,
        outcome: widget.rings[i],
        shade: shade,
      ));
      _totalEmitted++;
    }
  }

  void _startAnimating() {
    _stopwatch.start();
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  void _maybeStopIfExpired() {
    if (_ringStates.isEmpty) {
      _stopAnimating();
      return;
    }
    final now = _stopwatch.elapsedMilliseconds / 1000.0;
    final allExpired =
        _ringStates.every((ring) => (now - ring.birthTime) > _ringLifetime);
    if (allExpired) {
      _stopAnimating();
    }
  }

  void _stopAnimating() {
    _stopwatch.stop();
    if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final now = _stopwatch.elapsedMilliseconds / 1000.0;

        _ringStates.removeWhere(
          (ring) => (now - ring.birthTime) > _ringLifetime,
        );

        if (!widget.active && _ringStates.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _stopAnimating();
          });
        }

        return CustomPaint(
          size: Size.infinite,
          painter: _BurstPulsePainter(
            rings: List.unmodifiable(_ringStates),
            now: now,
            ringLifetime: _ringLifetime,
            lineColor: colorScheme.onSurface,
            dimColor: colorScheme.outlineVariant,
          ),
        );
      },
    );
  }
}

class _RingState {
  const _RingState({
    required this.birthTime,
    required this.outcome,
    required this.shade,
  });

  final double birthTime;
  final BurstRingOutcome outcome;

  /// 0.0-1.0 value used to lerp between lineColor and dimColor.
  final double shade;
}

class _BurstPulsePainter extends CustomPainter {
  const _BurstPulsePainter({
    required this.rings,
    required this.now,
    required this.ringLifetime,
    required this.lineColor,
    required this.dimColor,
  });

  final List<_RingState> rings;
  final double now;
  final double ringLifetime;
  final Color lineColor;
  final Color dimColor;

  double _scale(Size size) => size.shortestSide / 100;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = _scale(size);
    final center = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(
      center,
      2 * scale,
      Paint()..color = lineColor,
    );

    for (final ring in rings) {
      final age = now - ring.birthTime;
      if (age < 0 || age > ringLifetime) continue;

      final t = age / ringLifetime;
      final radius = 48 * Curves.easeOut.transform(t) * scale;
      final opacity = 0.8 * (1.0 - Curves.easeIn.transform(t));
      if (opacity <= 0 || radius <= 0) continue;

      final baseColor = Color.lerp(lineColor, dimColor, ring.shade)!;

      if (ring.outcome == BurstRingOutcome.succeeded) {
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = baseColor.withValues(alpha: opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      } else {
        final failColor = Color.lerp(dimColor, lineColor, ring.shade * 0.3)!;
        final path = Path()
          ..addOval(Rect.fromCircle(center: center, radius: radius));
        drawDashedPath(
          canvas,
          path,
          Paint()
            ..color = failColor.withValues(alpha: opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
          dash: 4 * scale,
          gap: 4 * scale,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPulsePainter old) => true;
}
