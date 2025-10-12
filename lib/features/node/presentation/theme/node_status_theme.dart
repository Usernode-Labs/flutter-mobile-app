import 'package:flutter/material.dart';

/// Theme class for Node Status Screen inspired by Fitness App Diary Theme
class NodeStatusTheme {
  NodeStatusTheme._();

  // Background colors
  static const Color background = Color(0xFFF2F3F8);
  static const Color white = Color(0xFFFFFFFF);
  static const Color nearlyWhite = Color(0xFFFAFAFA);

  // Primary colors
  static const Color nearlyDarkBlue = Color(0xFF2633C5);
  static const Color nearlyBlue = Color(0xFF00B6F0);

  // Text colors
  static const Color darkerText = Color(0xFF17262A);
  static const Color darkText = Color(0xFF253840);
  static const Color lightText = Color(0xFF4A6572);
  static const Color grey = Color(0xFF3A5160);
  static const Color deactivatedText = Color(0xFF767676);

  // Accent colors for progress/status
  static const Color accentBlue = Color(0xFF87A0E5);
  static const Color accentPink = Color(0xFFF56E98);
  static const Color accentYellow = Color(0xFFF1B440);
  static const Color accentGreen = Color(0xFF4CAF50);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);

  // Font
  static const String fontName = 'Roboto';

  // Text styles
  static const TextStyle display1 = TextStyle(
    fontFamily: fontName,
    fontWeight: FontWeight.bold,
    fontSize: 36,
    letterSpacing: 0.4,
    height: 0.9,
    color: darkerText,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: fontName,
    fontWeight: FontWeight.bold,
    fontSize: 24,
    letterSpacing: 0.27,
    color: darkerText,
  );

  static const TextStyle title = TextStyle(
    fontFamily: fontName,
    fontWeight: FontWeight.bold,
    fontSize: 16,
    letterSpacing: 0.18,
    color: darkerText,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: fontName,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    letterSpacing: -0.04,
    color: darkText,
  );

  static const TextStyle body1 = TextStyle(
    fontFamily: fontName,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    letterSpacing: -0.05,
    color: darkText,
  );

  static const TextStyle body2 = TextStyle(
    fontFamily: fontName,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    letterSpacing: 0.2,
    color: darkText,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontName,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    letterSpacing: 0.2,
    color: lightText,
  );

  static const TextStyle sectionHeader = TextStyle(
    fontFamily: fontName,
    fontWeight: FontWeight.w500,
    fontSize: 18,
    letterSpacing: 0.5,
    color: lightText,
  );

  // Card decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    color: white,
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(8.0),
      bottomLeft: Radius.circular(8.0),
      bottomRight: Radius.circular(8.0),
      topRight: Radius.circular(8.0),
    ),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: grey.withValues(alpha: 0.2),
        offset: const Offset(1.1, 1.1),
        blurRadius: 10.0,
      ),
    ],
  );

  // Mini card decoration (for nested cards)
  static BoxDecoration miniCardDecoration = BoxDecoration(
    color: nearlyWhite,
    borderRadius: BorderRadius.circular(8.0),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: grey.withValues(alpha: 0.1),
        offset: const Offset(0.5, 0.5),
        blurRadius: 4.0,
      ),
    ],
  );

  // Helper to create gradient for progress bars
  static LinearGradient progressGradient(Color color) {
    return LinearGradient(
      colors: [
        color.withValues(alpha: 0.5),
        color,
      ],
    );
  }

  // Helper to create hex color from string
  static Color hexColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
