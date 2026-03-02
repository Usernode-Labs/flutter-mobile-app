import 'package:flutter/material.dart';

/// Static color constants extracted from the deleted [MaterialTheme].
///
/// These are legacy accent / status colors that predate the design-system
/// [AppSemanticColors] extension. New code should prefer semantic tokens;
/// these constants exist only so existing screens compile without change.
class LegacyColors {
  LegacyColors._();

  // Accent colors
  static const Color accentPink = Color(0xFFF56E98);
  static const Color accentYellow = Color(0xFFF1B440);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color grey = Color(0xFF3A5160);
  static const Color deactivatedText = Color(0xFF767676);

  // Dark mode equivalents
  static const Color accentPinkDark = Color(0xFFFF9EB8);
  static const Color accentYellowDark = Color(0xFFFFD666);
  static const Color warningColorDark = Color(0xFFFFB74D);
  static const Color greyDark = Color(0xFF78909C);
  static const Color deactivatedTextDark = Color(0xFF9E9E9E);

  // Internal network colors (amber/warm theme)
  static const Color internalNetworkLightBackground = Color(0xFFFFF4E6);
  static const Color internalNetworkLightBorder = Color(0xFFE5C878);
  static const Color internalNetworkDarkBackground = Color(0xFF3D2914);
  static const Color internalNetworkDarkBorder = Color(0xFF8B7355);

  // Helper methods for internal network colors
  static Color getInternalNetworkBackgroundColor(bool isDark) {
    return isDark
        ? internalNetworkDarkBackground
        : internalNetworkLightBackground;
  }

  static Color getInternalNetworkBorderColor(bool isDark) {
    return isDark ? internalNetworkDarkBorder : internalNetworkLightBorder;
  }
}
