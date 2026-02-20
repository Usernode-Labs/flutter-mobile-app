import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/core/config/theme.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';

void main() {
  runApp(const WidgetbookApp());
}

class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    final materialTheme = MaterialTheme(ThemeData.light().textTheme);

    return Widgetbook.material(
      addons: [
        ThemeAddon<ThemeData>(
          themes: [
            WidgetbookTheme(name: 'Light', data: materialTheme.light()),
            WidgetbookTheme(name: 'Dark', data: materialTheme.dark()),
            WidgetbookTheme(
              name: 'Light High Contrast',
              data: materialTheme.lightHighContrast(),
            ),
            WidgetbookTheme(
              name: 'Dark High Contrast',
              data: materialTheme.darkHighContrast(),
            ),
          ],
          themeBuilder: (context, theme, child) {
            return DesignSystemTheme(
              child: Theme(data: theme, child: child),
            );
          },
        ),
        ViewportAddon([
          IosViewports.iPhone13,
          IosViewports.iPadPro11Inches,
          AndroidViewports.samsungGalaxyS20,
        ]),
        TextScaleAddon(min: 1.0, max: 2.0),
      ],
      directories: [],
    );
  }
}
