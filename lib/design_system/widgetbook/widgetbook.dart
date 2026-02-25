import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/theme/color_is_expensive_theme.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';

import 'bottom_nav_use_case.dart';
import 'button_use_case.dart';
import 'challenge_activity_summary_use_case.dart';
import 'challenge_card_use_case.dart';
import 'challenge_detail_page_use_case.dart';
import 'challenges_page_use_case.dart';
import 'color_catalog.dart';
import 'dropdown_chain_use_case.dart';
import 'dropdown_chip_use_case.dart';
import 'dropdown_sheet_use_case.dart';
import 'leaderboard_stats_card_use_case.dart';
import 'list_tile_use_case.dart';
import 'score_header_use_case.dart';
import 'tabs_use_case.dart';
import 'top_app_bar_use_case.dart';

void main() {
  runApp(const WidgetbookApp());
}

class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    final cieTheme = ColorIsExpensiveTheme(ThemeData.light().textTheme);

    ThemeData withSemanticColors(ThemeData base, AppSemanticColors semantic) {
      return base.copyWith(
        extensions: [
          ...DesignSystemTheme.standardExtensions(semanticColors: semantic),
        ],
      );
    }

    return Widgetbook.material(
      addons: [
        ThemeAddon<ThemeData>(
          themes: [
            WidgetbookTheme(
              name: 'Light',
              data: withSemanticColors(
                  cieTheme.light(), AppSemanticColors.light()),
            ),
            WidgetbookTheme(
              name: 'Light Medium Contrast',
              data: withSemanticColors(cieTheme.lightMediumContrast(),
                  AppSemanticColors.lightMediumContrast()),
            ),
            WidgetbookTheme(
              name: 'Light High Contrast',
              data: withSemanticColors(cieTheme.lightHighContrast(),
                  AppSemanticColors.lightHighContrast()),
            ),
            WidgetbookTheme(
              name: 'Dark',
              data:
                  withSemanticColors(cieTheme.dark(), AppSemanticColors.dark()),
            ),
            WidgetbookTheme(
              name: 'Dark Medium Contrast',
              data: withSemanticColors(cieTheme.darkMediumContrast(),
                  AppSemanticColors.darkMediumContrast()),
            ),
            WidgetbookTheme(
              name: 'Dark High Contrast',
              data: withSemanticColors(cieTheme.darkHighContrast(),
                  AppSemanticColors.darkHighContrast()),
            ),
          ],
          themeBuilder: (context, theme, child) {
            return Theme(
              data: theme,
              child: ColoredBox(
                color: theme.scaffoldBackgroundColor,
                child: child,
              ),
            );
          },
        ),
        ViewportAddon([
          Viewports.none,
          AndroidViewports.samsungGalaxyS20, // 360w — compact
          AndroidViewports.samsungGalaxyA50, // 412w — standard
          AndroidViewports.smallTablet, // 800w — small tablet
          AndroidViewports.mediumTablet, // 1024w — 10" tablet
        ]),
        AlignmentAddon(),
        TextScaleAddon(min: 1.0, max: 2.0),
      ],
      directories: [
        WidgetbookCategory(
          name: 'Foundations',
          children: [
            WidgetbookComponent(
              name: 'Color System',
              useCases: [
                WidgetbookUseCase(
                  name: 'Core Roles',
                  builder: (context) => const CoreRolesCatalog(),
                ),
                WidgetbookUseCase(
                  name: 'Surface & Neutral',
                  builder: (context) => const SurfaceNeutralCatalog(),
                ),
                WidgetbookUseCase(
                  name: 'Semantic Colors',
                  builder: (context) => const SemanticColorsCatalog(),
                ),
                WidgetbookUseCase(
                  name: 'Guidelines',
                  builder: (context) => const GuidelinesCatalog(),
                ),
              ],
            ),
          ],
        ),
        WidgetbookCategory(
          name: 'Widgets',
          children: [
            bottomNavComponent(),
            buttonComponent(),
            challengeActivitySummaryComponent(),
            challengeCardComponent(),
            dropdownChainComponent(),
            dropdownChipComponent(),
            dropdownSheetComponent(),
            leaderboardStatsCardComponent(),
            listTileComponent(),
            scoreHeaderComponent(),
            tabsComponent(),
            topAppBarComponent(),
          ],
        ),
        WidgetbookCategory(
          name: 'Pages',
          children: [
            challengeDetailPageComponent(),
            challengesPageComponent(),
          ],
        ),
      ],
    );
  }
}
