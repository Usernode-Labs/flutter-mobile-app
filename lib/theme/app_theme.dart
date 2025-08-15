import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  // 🔥 UPDATED: Material 3 Color Scheme with colors from screenshot
  static final ColorScheme _lightColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF007AFF),
    brightness: Brightness.light,
  ).copyWith(
    // Custom overrides for crypto app - updated colors from screenshot
    surface: Colors.white,
    surfaceContainerHighest: const Color(0xFFF2F2F7),
    outline: const Color(0xFFE5E5EA),
  );

  // 🔥 NEW: Material 3 Typography with proper scaling
  static final TextTheme _textTheme = Typography.englishLike2021.copyWith(
    displayLarge: const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: Colors.black,
      letterSpacing: -0.5,
    ),
    displayMedium: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: Colors.black,
      letterSpacing: -0.5,
    ),
    headlineMedium: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Colors.black,
      letterSpacing: -0.25,
    ),
    titleLarge: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Colors.black,
    ),
    titleMedium: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    ),
    bodyLarge: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: Colors.black,
      height: 1.5,
    ),
    bodyMedium: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Colors.black,
      height: 1.4,
    ),
  );

  // 🔥 UPDATED: Material 3 App Bar
  static final AppBarTheme _appBarTheme = AppBarTheme(
    backgroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 1, // 🔥 NEW: Material 3 elevation
    centerTitle: false,
    titleTextStyle: _textTheme.headlineMedium,
    iconTheme: const IconThemeData(color: Color(0xFF1C1C1E)),
    systemOverlayStyle: SystemUiOverlayStyle.dark,
  );

  // 🔥 UPDATED: Material 3 Navigation Bar (instead of BottomNavigationBar)
  static final NavigationBarThemeData _navigationBarTheme =
      NavigationBarThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 8,
    indicatorColor: const Color(0xFFFFFFFF),
    shadowColor: Colors.grey.withOpacity(0.3),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: Color(0xFF007AFF));
      }
      return const TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 12,
        color: Colors.black87,
      );
    }),
    // Icon styling
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(
          color: Colors.blue,
          size: 28,
        );
      }
      return const IconThemeData(
        color: Colors.black87,
        size: 24,
      );
    }),
  );

  // 🔥 UPDATED: Material 3 Cards
  static final CardThemeData _cardTheme = CardThemeData(
    color: Colors.white,
    elevation: 1, // 🔥 REDUCED: Material 3 uses lower elevation
    shadowColor: const Color(0x0A000000),
    surfaceTintColor:
        const Color(0xFF007AFF), // 🔥 NEW: Material 3 surface tint
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    margin: const EdgeInsets.symmetric(
        horizontal: 0, vertical: 6), // 🔥 CHANGED: Remove horizontal margin
  );

  // 🔥 UPDATED: Material 3 Filled Buttons
  static final FilledButtonThemeData _filledButtonTheme = FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF007AFF),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      textStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.25,
      ),
    ),
  );

  // Main Material 3 theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: _lightColorScheme,
    textTheme: _textTheme,
    appBarTheme: _appBarTheme,
    navigationBarTheme: _navigationBarTheme, // 🔥 NEW: Navigation Bar theme
    cardTheme: _cardTheme,
    filledButtonTheme: _filledButtonTheme, // 🔥 NEW: Filled Button theme
    scaffoldBackgroundColor: Colors.white,
    dividerColor: const Color(0xFFF2F2F7),

    // 🔥 NEW: Material 3 specific themes
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF2F2F7),
      selectedColor: const Color(0xFF007AFF).withOpacity(0.12),
      labelStyle: const TextStyle(color: Color(0xFF1C1C1E)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color(0xFF007AFF),
      linearTrackColor: Color(0xFFF2F2F7),
    ),
  );

  // Splash screen colors
  static const Color splashBackgroundColor = Color(0xFF007AFF);
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFF007AFF),
      Color(0xFF5856D6),
      Color(0xFF30D158),
    ],
    stops: [0.0, 0.7, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // App-specific colors
  static const Color nodeIconColor = Color(0xFF8E8E93);
  static const Color multiplierColor = Color(0xFF007AFF);
  static const Color successCheckColor = Color(0xFF30D158);
  static const Color pendingIconColor = Color(0xFFFF9500);

  // 🔥 ADDED BACK: Custom text styles for backward compatibility
  static const TextStyle nodeStatusStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Color(0xFF1C1C1E),
  );

  static const TextStyle nodeSubtitleStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Color(0xFF8E8E93),
  );

  static const TextStyle multiplierStyle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: Color(0xFF1C1C1E),
  );

  static const TextStyle activityTitleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Color(0xFF1C1C1E),
  );

  static const TextStyle activitySubtitleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Color(0xFF8E8E93),
  );
}
