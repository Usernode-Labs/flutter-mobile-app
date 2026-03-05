import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/app_semantic_colors.dart';

/// Generates a unique gradient avatar with a two-letter monogram for a dApp.
///
/// Colors are drawn from [AppSemanticColors] (technical, flash, community) so
/// avatars feel native to the design system across light/dark themes. Each seed
/// deterministically picks two semantic colors and a gradient angle.
///
/// The monogram is derived from [seed]: first letters of the first two words,
/// or the first two characters if single-word.
class DappAvatar extends StatelessWidget {
  const DappAvatar({super.key, required this.seed, this.size});

  final String seed;

  /// Optional explicit size. When provided, wraps the avatar in a [SizedBox].
  final double? size;

  /// The 3 semantic group pairs: (0,1), (0,2), (1,2).
  static const _pairs = [
    (0, 1),
    (0, 2),
    (1, 2),
  ];

  /// Deterministic hash from seed string, producing a well-distributed int.
  static int _hash(String seed) {
    // djb2 hash — simple, deterministic, good distribution.
    var hash = 5381;
    for (var i = 0; i < seed.length; i++) {
      hash = ((hash << 5) + hash) + seed.codeUnitAt(i);
      hash &= 0x7FFFFFFF; // keep positive 31-bit
    }
    return hash;
  }

  static final _whitespace = RegExp(r'\s+');

  /// Extracts a two-letter monogram from a name.
  ///
  /// Multi-word: first letter of each of the first two words.
  /// Single-word: first two characters.
  static String _monogram(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '??';

    final words = trimmed.split(_whitespace);
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return trimmed.length >= 2
        ? trimmed.substring(0, 2).toUpperCase()
        : trimmed[0].toUpperCase();
  }

  /// Picks white or black text based on the average luminance of the two
  /// gradient colors — ensures WCAG AA contrast against the midpoint.
  static Color _contrastForeground(Color c1, Color c2) {
    final avgLuminance = (c1.computeLuminance() + c2.computeLuminance()) / 2;
    return avgLuminance > 0.4 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final textTheme = theme.textTheme;

    final groups = [semantic.technical, semantic.flash, semantic.community];

    final h = _hash(seed);

    // Pick pair (3 options), roles (4 combos) → 12 combos.
    final pairIndex = h % _pairs.length;
    final pair = _pairs[pairIndex];

    final roleBits = (h >> 2) & 0x3; // 2 bits → 4 combos
    final color1 = (roleBits & 1) == 0
        ? groups[pair.$1].color
        : groups[pair.$1].colorContainer;
    final color2 = (roleBits >> 1) == 0
        ? groups[pair.$2].color
        : groups[pair.$2].colorContainer;

    // Gradient angle from hash (8 steps of 45°).
    final angleBits = (h >> 4) & 0x7;
    final angle = angleBits * math.pi / 4;

    final monogram = _monogram(seed);

    Widget avatar = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment(math.cos(angle), math.sin(angle)),
          end: Alignment(math.cos(angle + math.pi), math.sin(angle + math.pi)),
          colors: [color1, color2],
        ),
      ),
      child: Center(
        child: Text(
          monogram,
          style: textTheme.labelLarge?.copyWith(
            color: _contrastForeground(color1, color2),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    if (size != null) {
      avatar = SizedBox(width: size, height: size, child: avatar);
    }

    return avatar;
  }
}
