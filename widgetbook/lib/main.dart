import 'package:flutter/material.dart' hide ThemeMode;
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/theme/color_is_expensive_theme.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';

import 'components.g.dart';

Config buildWidgetbookConfig() {
  final cieTheme = ColorIsExpensiveTheme(ThemeData.light().textTheme);

  ThemeData withSemanticColors(ThemeData base, AppSemanticColors semantic) {
    return base.copyWith(
      extensions: [
        ...DesignSystemTheme.standardExtensions(semanticColors: semantic),
      ],
    );
  }

  return Config(
    components: components,
    appBuilder: (context, child) {
      final theme = Theme.of(context);
      return LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.hasBoundedWidth ? constraints.maxWidth : 412.0;
          final height =
              constraints.hasBoundedHeight ? constraints.maxHeight : 915.0;

          return SizedBox(
            width: width,
            height: height,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: ColoredBox(
                color: theme.scaffoldBackgroundColor,
                child: child,
              ),
            ),
          );
        },
      );
    },
    addons: [
      MaterialThemeAddon({
        'Light': withSemanticColors(
          cieTheme.light(),
          AppSemanticColors.light(),
        ),
        'Light Medium Contrast': withSemanticColors(
          cieTheme.lightMediumContrast(),
          AppSemanticColors.lightMediumContrast(),
        ),
        'Light High Contrast': withSemanticColors(
          cieTheme.lightHighContrast(),
          AppSemanticColors.lightHighContrast(),
        ),
        'Dark': withSemanticColors(cieTheme.dark(), AppSemanticColors.dark()),
        'Dark Medium Contrast': withSemanticColors(
          cieTheme.darkMediumContrast(),
          AppSemanticColors.darkMediumContrast(),
        ),
        'Dark High Contrast': withSemanticColors(
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
  );
}

void main() {
  runWidgetbook(buildWidgetbookConfig());
}
