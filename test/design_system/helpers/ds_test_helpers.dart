import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Creates a [ThemeData] with all design system extensions registered.
ThemeData themeWithExtensions() {
  final cieTheme = ColorIsExpensiveTheme(ThemeData.light().textTheme);
  return cieTheme.light().copyWith(
        extensions: DesignSystemTheme.standardExtensions(
          semanticColors: AppSemanticColors.light(),
        ),
      );
}

/// Wraps [child] in a themed [MaterialApp] for widget tests.
Widget wrap(Widget child) {
  return MaterialApp(
    theme: themeWithExtensions(),
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}
