import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/core/config/theme.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';

import 'app_button_use_case.dart';
import 'app_card_use_case.dart';
import 'app_text_field_use_case.dart';
import 'app_action_button_use_case.dart';
import 'app_bottom_sheet_use_case.dart';
import 'app_progress_bar_use_case.dart';
import 'app_bar_use_case.dart';
import 'app_drawer_use_case.dart';
import 'node_status_icon_use_case.dart';
import 'produced_block_card_use_case.dart';
import 'won_slot_item_use_case.dart';

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
      directories: [
        WidgetbookFolder(
          name: 'Core Widgets',
          children: [
            appButtonComponent(),
            appCardComponent(),
            appTextFieldComponent(),
            appActionButtonComponent(),
            appBottomSheetComponent(),
            appProgressBarComponent(),
          ],
        ),
        WidgetbookFolder(
          name: 'Navigation',
          children: [
            appBarComponent(),
            appDrawerComponent(),
          ],
        ),
        WidgetbookFolder(
          name: 'Domain Widgets',
          children: [
            nodeStatusIconComponent(),
            producedBlockCardComponent(),
            wonSlotItemComponent(),
          ],
        ),
      ],
    );
  }
}
