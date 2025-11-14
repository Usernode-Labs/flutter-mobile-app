import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/slot_heatmap.dart';

/// A simple, time-scaled horizontal timeline for won slots.
/// Renders a line with markers positioned by expectedTimeMs.
class SlotTimeline extends StatelessWidget {
  final List<SlotHeatmapData> slots;
  final int? bestTipGlobalSlot;
  final double height;

  const SlotTimeline({
    super.key,
    required this.slots,
    this.bestTipGlobalSlot,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const SizedBox.shrink();
    }

    // Determine min/max time from won slots
    final times = slots
        .map((s) => s.slot.expectedTimeMs.toInt())
        .where((t) => t > 0)
        .toList()
      ..sort();
    if (times.isEmpty) return const SizedBox.shrink();

    final minMs = times.first;
    final maxMs = times.last;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final span = (maxMs - minMs).clamp(1, 1 << 62);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final width = constraints.maxWidth;
        final lineY = height / 2;

        return Stack(
          children: [
            SizedBox(
              height: height,
              width: width,
              child: CustomPaint(
                painter: _TimelinePainter(
                  lineY: lineY,
                  lineColor: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),

            // Now marker
            Positioned(
              left: ((nowMs - minMs) / span) * width,
              top: 0,
              bottom: 0,
              child: _NowMarker(),
            ),

            // Slot markers
            ...slots.map((s) {
              final t = s.slot.expectedTimeMs.toInt();
              final left = ((t - minMs) / span) * width;
              final isBest = bestTipGlobalSlot != null &&
                  s.slot.globalSlot == bestTipGlobalSlot;
              return Positioned(
                left: left.clamp(0, width - 8),
                top: lineY - 6,
                child: _SlotDot(status: s.status, isBestTip: isBest),
              );
            }),
          ],
        );
      },
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final double lineY;
  final Color lineColor;

  _TimelinePainter({required this.lineY, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = lineColor
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), p);
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      oldDelegate.lineY != lineY || oldDelegate.lineColor != lineColor;
}

class _SlotDot extends StatelessWidget {
  final SlotHeatmapStatus status;
  final bool isBestTip;

  const _SlotDot({required this.status, this.isBestTip = false});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case SlotHeatmapStatus.produced:
        color = Colors.green;
        break;
      case SlotHeatmapStatus.pending:
        color = Colors.blue;
        break;
      case SlotHeatmapStatus.missed:
        color = Colors.red;
        break;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isBestTip)
          Icon(Icons.star,
              size: 12, color: Theme.of(context).colorScheme.primary),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
          ),
        ),
      ],
    );
  }
}

class _NowMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Column(
      children: [
        Icon(Icons.arrow_drop_down, color: color, size: 18),
        Expanded(
          child: Container(width: 2, color: color.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}
