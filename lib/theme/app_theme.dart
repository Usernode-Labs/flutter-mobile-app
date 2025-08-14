import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  // 🔥 UPDATED: Material 3 Color Scheme with colors from screenshot
  static final ColorScheme _lightColorScheme = ColorScheme.fromSeed(
    seedColor: Color(0xFF007AFF),
    brightness: Brightness.light,
  ).copyWith(
    // Custom overrides for crypto app - updated colors from screenshot
    surface: Colors.white,
    surfaceVariant: Color(0xFFF2F2F7),
    outline: Color(0xFFE5E5EA),
  );

  // 🔥 NEW: Material 3 Typography with proper scaling
  static final TextTheme _textTheme = Typography.englishLike2021.copyWith(
    displayLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1C1C1E),
      letterSpacing: -0.5,
    ),
    headlineMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1C1C1E),
      letterSpacing: -0.25,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1C1C1E),
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: Color(0xFF1C1C1E),
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Color(0xFF8E8E93),
      height: 1.4,
    ),
  );

  // 🔥 UPDATED: Material 3 App Bar
  static final AppBarTheme _appBarTheme = AppBarTheme(
    backgroundColor: Color(0xFFFAFAFA),
    elevation: 0,
    scrolledUnderElevation: 1, // 🔥 NEW: Material 3 elevation
    centerTitle: false,
    titleTextStyle: _textTheme.headlineMedium,
    iconTheme: IconThemeData(color: Color(0xFF1C1C1E)),
    systemOverlayStyle: SystemUiOverlayStyle.dark,
  );

  // 🔥 UPDATED: Material 3 Navigation Bar (instead of BottomNavigationBar)
  static final NavigationBarThemeData _navigationBarTheme =
      NavigationBarThemeData(
    backgroundColor: Colors.white,
    elevation: 8,
    indicatorColor: Color(0xFF007AFF).withOpacity(0.12),
    labelTextStyle: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: Color(0xFF007AFF),
        );
      }
      return TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 12,
        color: Color(0xFF8E8E93),
      );
    }),
  );

  // 🔥 UPDATED: Material 3 Cards
  static final CardTheme _cardTheme = CardTheme(
    color: Colors.white,
    elevation: 1, // 🔥 REDUCED: Material 3 uses lower elevation
    shadowColor: Color(0x0A000000),
    surfaceTintColor: Color(0xFF007AFF), // 🔥 NEW: Material 3 surface tint
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    margin: EdgeInsets.symmetric(
        horizontal: 0, vertical: 6), // 🔥 CHANGED: Remove horizontal margin
  );

  // 🔥 UPDATED: Material 3 Filled Buttons
  static final FilledButtonThemeData _filledButtonTheme = FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: Color(0xFF007AFF),
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      textStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.25,
      ),
    ),
  );

  // Main Material 3 theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true, // 🔥 IMPORTANT: Enable Material 3
    colorScheme: _lightColorScheme,
    textTheme: _textTheme,
    appBarTheme: _appBarTheme,
    navigationBarTheme: _navigationBarTheme, // 🔥 NEW: Navigation Bar theme
    cardTheme: _cardTheme,
    filledButtonTheme: _filledButtonTheme, // 🔥 NEW: Filled Button theme
    scaffoldBackgroundColor: Color(0xFFFAFAFA),
    dividerColor: Color(0xFFF2F2F7),

    // 🔥 NEW: Material 3 specific themes
    chipTheme: ChipThemeData(
      backgroundColor: Color(0xFFF2F2F7),
      selectedColor: Color(0xFF007AFF).withOpacity(0.12),
      labelStyle: TextStyle(color: Color(0xFF1C1C1E)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
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
