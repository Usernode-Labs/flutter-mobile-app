import 'package:flutter/material.dart' hide ThemeMode;
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/theme/color_is_expensive_theme.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';

import 'components.g.dart';

void main() {
  final cieTheme = ColorIsExpensiveTheme(ThemeData.light().textTheme);

  ThemeData _withSemanticColors(ThemeData base, AppSemanticColors semantic) {
    return base.copyWith(
      extensions: [
        ...DesignSystemTheme.standardExtensions(semanticColors: semantic),
      ],
    );
  }

  runWidgetbook(
    Config(
      components: components,
      appBuilder: (context, child) {
        final theme = Theme.of(context);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: ColoredBox(color: theme.scaffoldBackgroundColor, child: child),
        );
      },
      addons: [
        MaterialThemeAddon({
          'Light': _withSemanticColors(
            cieTheme.light(),
            AppSemanticColors.light(),
          ),
          'Light Medium Contrast': _withSemanticColors(
            cieTheme.lightMediumContrast(),
            AppSemanticColors.lightMediumContrast(),
          ),
          'Light High Contrast': _withSemanticColors(
            cieTheme.lightHighContrast(),
            AppSemanticColors.lightHighContrast(),
          ),
          'Dark': _withSemanticColors(
            cieTheme.dark(),
            AppSemanticColors.dark(),
          ),
          'Dark Medium Contrast': _withSemanticColors(
            cieTheme.darkMediumContrast(),
            AppSemanticColors.darkMediumContrast(),
          ),
          'Dark High Contrast': _withSemanticColors(
            cieTheme.darkHighContrast(),
            AppSemanticColors.darkHighContrast(),
          ),
        }),
        ViewportAddon([
          Viewports.none,
          AndroidViewports.samsungGalaxyS20,
          AndroidViewports.samsungGalaxyA50,
          AndroidViewports.smallTablet,
          AndroidViewports.mediumTablet,
        ]),
        AlignmentAddon(),
        TextScaleAddon(),
      ],
    ),
  );
}
