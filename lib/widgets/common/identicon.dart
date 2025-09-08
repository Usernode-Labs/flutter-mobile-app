import 'package:flutter/material.dart';

/// Simple, dependency-free identicon generator based on a 5x5 mirrored grid.
/// Color and pattern are derived deterministically from the provided seed.
class Identicon extends StatelessWidget {
  final String seed;
  final double size;
  final double padding;

  const Identicon({
    super.key,
    required this.seed,
    this.size = 40,
    this.padding = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _IdenticonPainter(seed, padding: padding),
      ),
    );
  }
}

class _IdenticonPainter extends CustomPainter {
  final String seed;
  final double padding;

  _IdenticonPainter(this.seed, {required this.padding});

  // FNV-1a 32-bit hash for deterministic bytes
  int _fnv1a32(String input) {
    const int fnvPrime = 0x01000193;
    int hash = 0x811C9DC5;
    for (final unit in input.codeUnits) {
      hash ^= unit & 0xff;
      hash = (hash * fnvPrime) & 0xffffffff;
    }
    return hash;
  }

  List<int> _bytesFromSeed(String s) {
    final b = <int>[];
    var h = _fnv1a32(s);
    for (int i = 0; i < 16; i++) {
      h = _fnv1a32('$h-$i');
      b.add((h >> 24) & 0xff);
      b.add((h >> 16) & 0xff);
      b.add((h >> 8) & 0xff);
      b.add(h & 0xff);
    }
    return b;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bytes = _bytesFromSeed(seed);
    // Pick hue/sat/lightness from bytes
    final hue = (bytes[0] % 360).toDouble();
    final sat = 0.65 + (bytes[1] / 255) * 0.25; // 0.65..0.9
    final light = 0.45 + (bytes[2] / 255) * 0.15; // 0.45..0.6
    final color = HSLColor.fromAHSL(1, hue, sat, light).toColor();
    final bg = Colors.transparent;

    final paint = Paint()..color = color;
    final bgPaint = Paint()..color = bg;

    final grid = 5;
    final cell = Size(
      (size.width - padding * 2) / grid,
      (size.height - padding * 2) / grid,
    );

    // Background
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Build a 5x5 pattern, mirroring columns (0..2 -> 4..3)
    int byteIndex = 3; // start a bit after color bytes
    for (int y = 0; y < grid; y++) {
      int rowBits = bytes[byteIndex++];
      for (int x = 0; x < (grid / 2).ceil(); x++) {
        final bit = (rowBits >> x) & 1;
        if (bit == 1) {
          // Left side
          final rectL = Rect.fromLTWH(
              padding + x * cell.width, padding + y * cell.height, cell.width, cell.height);
          canvas.drawRect(rectL, paint);
          // Mirror to right side
          final mx = grid - 1 - x;
          if (mx != x) {
            final rectR = Rect.fromLTWH(
                padding + mx * cell.width, padding + y * cell.height, cell.width, cell.height);
            canvas.drawRect(rectR, paint);
          }
        }
      }
    }

    // Optional rounded mask
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8));
    canvas.clipRRect(r);
  }

  @override
  bool shouldRepaint(covariant _IdenticonPainter oldDelegate) => oldDelegate.seed != seed || oldDelegate.padding != padding;
}

