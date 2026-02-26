import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  // Additional colors from node_status theme
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

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff2633C5), // node_status nearlyDarkBlue
      surfaceTint: Color(0xff2633C5),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xffe8ecff),
      onPrimaryContainer: Color(0xff1e3a8a),
      secondary: Color(0xff00B6F0), // node_status nearlyBlue
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffe0f7ff),
      onSecondaryContainer: Color(0xff0086b3),
      tertiary: Color(0xff4CAF50), // node_status success/accentGreen
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffd1fae5),
      onTertiaryContainer: Color(0xff2e7d32),
      error: Color(0xffF44336), // node_status error
      onError: Color(0xffffffff),
      errorContainer: Color(0xfffecaca),
      onErrorContainer: Color(0xffc62828),
      surface: Color(0xffF2F3F8), // node_status background
      onSurface: Color(0xff17262A), // node_status darkerText
      onSurfaceVariant: Color(0xff4A6572), // node_status lightText
      outline: Color(0xffcbd5e1),
      outlineVariant: Color(0xffe2e8f0),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff253840), // node_status darkText
      inversePrimary: Color(0xffadc6ff),
      primaryFixed: Color(0xffe8ecff),
      onPrimaryFixed: Color(0xff1e3a8a),
      primaryFixedDim: Color(0xffc7d2fe),
      onPrimaryFixedVariant: Color(0xff2633C5),
      secondaryFixed: Color(0xffe0f7ff),
      onSecondaryFixed: Color(0xff003d5c),
      secondaryFixedDim: Color(0xff87ceeb),
      onSecondaryFixedVariant: Color(0xff00B6F0),
      tertiaryFixed: Color(0xffd1fae5),
      onTertiaryFixed: Color(0xff1b5e20),
      tertiaryFixedDim: Color(0xffa7f3d0),
      onTertiaryFixedVariant: Color(0xff4CAF50),
      surfaceDim: Color(0xffe2e8f0),
      surfaceBright: Color(0xffffffff), // node_status white
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffFAFAFA), // node_status nearlyWhite
      surfaceContainer: Color(0xfff1f5f9),
      surfaceContainerHigh: Color(0xffe8ecf0),
      surfaceContainerHighest: Color(0xffe2e8f0),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff4c5fc7),
      surfaceTint: Color(0xff667eea),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff8294ff),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff5a3680),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff9061b9),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff059669),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff34d399),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xffdc2626),
      onError: Color(0xffffffff),
      errorContainer: Color(0xfff87171),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfff8f9fa),
      onSurface: Color(0xff1e293b),
      onSurfaceVariant: Color(0xff475569),
      outline: Color(0xff94a3b8),
      outlineVariant: Color(0xffcbd5e1),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff1e293b),
      inversePrimary: Color(0xffc7d2fe),
      primaryFixed: Color(0xff8294ff),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff6875f5),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff9061b9),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff7c3aed),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff34d399),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff10b981),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffe2e8f0),
      surfaceBright: Color(0xffffffff),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff8fafc),
      surfaceContainer: Color(0xfff1f5f9),
      surfaceContainerHigh: Color(0xffe8ecf0),
      surfaceContainerHighest: Color(0xffe2e8f0),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme());
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff1e3a8a),
      surfaceTint: Color(0xff667eea),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff3730a3),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff4c1d95),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff6b21a8),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff065f46),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff047857),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff991b1b),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffb91c1c),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfff8f9fa),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff1e293b),
      outline: Color(0xff475569),
      outlineVariant: Color(0xff64748b),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff1e293b),
      inversePrimary: Color(0xffe0e7ff),
      primaryFixed: Color(0xff3730a3),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff1e40af),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff6b21a8),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff581c87),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff047857),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff065f46),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffd1d5db),
      surfaceBright: Color(0xffffffff),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff3f4f6),
      surfaceContainer: Color(0xffe5e7eb),
      surfaceContainerHigh: Color(0xffd1d5db),
      surfaceContainerHighest: Color(0xffc4c9cf),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xff87A0E5), // node_status accentBlue adapted for dark
      surfaceTint: Color(0xff87A0E5),
      onPrimary: Color(0xff0d1b4d),
      primaryContainer: Color(0xff2633C5),
      onPrimaryContainer: Color(0xffc7d2fe),
      secondary: Color(0xff64D5FF), // node_status nearlyBlue adapted for dark
      onSecondary: Color(0xff003d5c),
      secondaryContainer: Color(0xff00779e),
      onSecondaryContainer: Color(0xffe0f7ff),
      tertiary: Color(0xff81C784), // node_status success adapted for dark
      onTertiary: Color(0xff1b5e20),
      tertiaryContainer: Color(0xff2e7d32),
      onTertiaryContainer: Color(0xffc8e6c9),
      error: Color(0xffEF9A9A), // node_status error adapted for dark
      onError: Color(0xff5d1010),
      errorContainer: Color(0xffc62828),
      onErrorContainer: Color(0xffffcdd2),
      surface: Color(0xff1a1c24), // dark equivalent of node_status background
      onSurface: Color(0xffe2e8f0),
      onSurfaceVariant: Color(0xffb0bec5),
      outline: Color(0xff475569),
      outlineVariant: Color(0xff334155),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe2e8f0),
      inversePrimary: Color(0xff2633C5),
      primaryFixed: Color(0xffc7d2fe),
      onPrimaryFixed: Color(0xff0d1b4d),
      primaryFixedDim: Color(0xff87A0E5),
      onPrimaryFixedVariant: Color(0xff2633C5),
      secondaryFixed: Color(0xffe0f7ff),
      onSecondaryFixed: Color(0xff003d5c),
      secondaryFixedDim: Color(0xff87ceeb),
      onSecondaryFixedVariant: Color(0xff00779e),
      tertiaryFixed: Color(0xffc8e6c9),
      onTertiaryFixed: Color(0xff1b5e20),
      tertiaryFixedDim: Color(0xff81C784),
      onTertiaryFixedVariant: Color(0xff2e7d32),
      surfaceDim: Color(0xff0c0e13),
      surfaceBright: Color(0xff2d3748),
      surfaceContainerLowest: Color(0xff0a0b0f),
      surfaceContainerLow: Color(0xff1e2028),
      surfaceContainer: Color(0xff24262f),
      surfaceContainerHigh: Color(0xff2a2d36),
      surfaceContainerHighest: Color(0xff33353e),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffc7d2fe),
      surfaceTint: Color(0xffadc6ff),
      onPrimary: Color(0xff1e40af),
      primaryContainer: Color(0xff8b9ff9),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xfff5d0fe),
      onSecondary: Color(0xff581c87),
      secondaryContainer: Color(0xffc084fc),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xff86efac),
      onTertiary: Color(0xff064e3b),
      tertiaryContainer: Color(0xff4ade80),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xfffca5a5),
      onError: Color(0xff7f1d1d),
      errorContainer: Color(0xfff87171),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff111318),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffe2e8f0),
      outline: Color(0xff94a3b8),
      outlineVariant: Color(0xff64748b),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe2e8f0),
      inversePrimary: Color(0xff4c5fc7),
      primaryFixed: Color(0xffe8ecff),
      onPrimaryFixed: Color(0xff1e3a8a),
      primaryFixedDim: Color(0xffc7d2fe),
      onPrimaryFixedVariant: Color(0xff3730a3),
      secondaryFixed: Color(0xfff3e8ff),
      onSecondaryFixed: Color(0xff4c1d95),
      secondaryFixedDim: Color(0xffe9d5ff),
      onSecondaryFixedVariant: Color(0xff6b21a8),
      tertiaryFixed: Color(0xffd1fae5),
      onTertiaryFixed: Color(0xff065f46),
      tertiaryFixedDim: Color(0xffa7f3d0),
      onTertiaryFixedVariant: Color(0xff047857),
      surfaceDim: Color(0xff0c0e13),
      surfaceBright: Color(0xff383b47),
      surfaceContainerLowest: Color(0xff000000),
      surfaceContainerLow: Color(0xff1a1b20),
      surfaceContainer: Color(0xff252730),
      surfaceContainerHigh: Color(0xff30323d),
      surfaceContainerHighest: Color(0xff3b3d48),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme());
  }

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xfffcfcff),
      surfaceTint: Color(0xffadc6ff),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xffc7d2fe),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xfffff9fe),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xfff5d0fe),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xfff0fdf4),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xffa7f3d0),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xfffff5f5),
      onError: Color(0xff000000),
      errorContainer: Color(0xfffecaca),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff111318),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffffffff),
      outline: Color(0xffe2e8f0),
      outlineVariant: Color(0xffcbd5e1),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe2e8f0),
      inversePrimary: Color(0xff1e3a8a),
      primaryFixed: Color(0xffeef2ff),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xffc7d2fe),
      onPrimaryFixedVariant: Color(0xff1e40af),
      secondaryFixed: Color(0xfff9f5ff),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xfff5d0fe),
      onSecondaryFixedVariant: Color(0xff581c87),
      tertiaryFixed: Color(0xffd1fae5),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xffa7f3d0),
      onTertiaryFixedVariant: Color(0xff064e3b),
      surfaceDim: Color(0xff0c0e13),
      surfaceBright: Color(0xff4b4e5a),
      surfaceContainerLowest: Color(0xff000000),
      surfaceContainerLow: Color(0xff1e2028),
      surfaceContainer: Color(0xff30323d),
      surfaceContainerHigh: Color(0xff3e4149),
      surfaceContainerHighest: Color(0xff4a4c56),
    );
  }

  ThemeData darkHighContrast() {
    return theme(darkHighContrastScheme());
  }

  // Helper methods for internal network colors
  static Color getInternalNetworkBackgroundColor(bool isDark) {
    return isDark
        ? internalNetworkDarkBackground
        : internalNetworkLightBackground;
  }

  static Color getInternalNetworkBorderColor(bool isDark) {
    return isDark ? internalNetworkDarkBorder : internalNetworkLightBorder;
  }

  ThemeData theme(ColorScheme colorScheme) => ThemeData(
        useMaterial3: true,
        brightness: colorScheme.brightness,
        colorScheme: colorScheme,
        textTheme: textTheme.apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        ),
        scaffoldBackgroundColor: colorScheme.surface,
        canvasColor: colorScheme.surface,
        iconTheme: const IconThemeData(
          weight: 300,
          opticalSize: 20,
        ),
        cardTheme: CardThemeData(
          color: colorScheme.surfaceBright,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide.none,
          ),
          shadowColor: colorScheme.outline.withValues(alpha: 0.2),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            elevation: WidgetStateProperty.all(0),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: colorScheme.surface,
          indicatorColor: colorScheme.surfaceContainerHighest,
          elevation: 0,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              color:
                  selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            );
          }),
        ),
      );

  List<ExtendedColor> get extendedColors => [];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
