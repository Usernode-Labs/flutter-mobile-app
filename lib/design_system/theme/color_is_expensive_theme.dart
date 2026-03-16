import 'package:flutter/material.dart';

import '../tokens/app_borders.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

/// "Color is Expensive" Material 3 theme — APCA-driven ink & paper philosophy.
///
/// Near-black primary (#18191B) as the attention locker. Achromatic secondary
/// (neutral-variant palette) and tertiary (pure neutral palette) push all
/// chromatic color exclusively into [AppSemanticColors]. M3 structural roles
/// render grey; a developer must consciously reach for a semantic extension
/// to introduce hue — enforcing "color is expensive."
///
/// Values sourced from `material-theme.json` generated via the APCA pipeline.
class ColorIsExpensiveTheme {
  final TextTheme textTheme;

  const ColorIsExpensiveTheme(this.textTheme);

  // Standard token instances used by the theme builder.
  static final _spacing = AppSpacing.standard();
  static final _radii = AppRadii.standard();
  static final _borders = AppBorders.standard();

  // ---------------------------------------------------------------------------
  // Light schemes
  // ---------------------------------------------------------------------------

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF252627),
      surfaceTint: Color(0xFF252627),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE2E2E4),
      onPrimaryContainer: Color(0xFF1B1B1C),
      secondary: Color(0xFF5C5E64),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFE1E2E8),
      onSecondaryContainer: Color(0xFF191A20),
      tertiary: Color(0xFF757575),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFF5F5F5),
      onTertiaryContainer: Color(0xFF5D5D5D),
      error: Color(0xFFBD0F19),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFBFA9),
      onErrorContainer: Color(0xFF9C0003),
      surface: Color(0xFFEBEBEB),
      onSurface: Color(0xFF1B1B1B),
      onSurfaceVariant: Color(0xFF44474D),
      outline: Color(0xFF74777E),
      outlineVariant: Color(0xFFC4C6CC),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF303030),
      inversePrimary: Color(0xFFC5C6C8),
      primaryFixed: Color(0xFFE2E2E4),
      onPrimaryFixed: Color(0xFF1B1B1C),
      primaryFixedDim: Color(0xFFC5C6C8),
      onPrimaryFixedVariant: Color(0xFF464749),
      secondaryFixed: Color(0xFFE1E2E8),
      onSecondaryFixed: Color(0xFF191A20),
      secondaryFixedDim: Color(0xFFC8CAD0),
      onSecondaryFixedVariant: Color(0xFF44474D),
      tertiaryFixed: Color(0xFFF5F5F5),
      onTertiaryFixed: Color(0xFF5D5D5D),
      tertiaryFixedDim: Color(0xFFE2E2E2),
      onTertiaryFixedVariant: Color(0xFF5D5D5D),
      surfaceDim: Color(0xFFDADADA),
      surfaceBright: Color(0xFFF9F9F9),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF3F3F3),
      surfaceContainer: Color(0xFFEEEEEE),
      surfaceContainerHigh: Color(0xFFE8E8E8),
      surfaceContainerHighest: Color(0xFFE2E2E2),
    );
  }

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF1B1B1C),
      surfaceTint: Color(0xFF252627),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFF252627),
      onPrimaryContainer: Color(0xFFFFFFFF),
      secondary: Color(0xFF44474D),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFF5C5E64),
      onSecondaryContainer: Color(0xFFFFFFFF),
      tertiary: Color(0xFF5D5D5D),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFF757575),
      onTertiaryContainer: Color(0xFFFFFFFF),
      error: Color(0xFF9C0003),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFBD0F19),
      onErrorContainer: Color(0xFFFFFFFF),
      surface: Color(0xFFEBEBEB),
      onSurface: Color(0xFF111111),
      onSurfaceVariant: Color(0xFF393B41),
      outline: Color(0xFF5B5E65),
      outlineVariant: Color(0xFF8E9198),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF303030),
      inversePrimary: Color(0xFFC5C6C8),
      primaryFixed: Color(0xFF76777A),
      onPrimaryFixed: Color(0xFFFFFFFF),
      primaryFixedDim: Color(0xFF515255),
      onPrimaryFixedVariant: Color(0xFFFFFFFF),
      secondaryFixed: Color(0xFF74777E),
      onSecondaryFixed: Color(0xFFFFFFFF),
      secondaryFixedDim: Color(0xFF5B5E65),
      onSecondaryFixedVariant: Color(0xFFFFFFFF),
      tertiaryFixed: Color(0xFF838383),
      onTertiaryFixed: Color(0xFFFFFFFF),
      tertiaryFixedDim: Color(0xFF757575),
      onTertiaryFixedVariant: Color(0xFFFFFFFF),
      surfaceDim: Color(0xFFDADADA),
      surfaceBright: Color(0xFFF9F9F9),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF1F1F1),
      surfaceContainer: Color(0xFFE2E2E2),
      surfaceContainerHigh: Color(0xFFD4D4D4),
      surfaceContainerHighest: Color(0xFFC6C6C6),
    );
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF111112),
      surfaceTint: Color(0xFF252627),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFF1B1B1C),
      onPrimaryContainer: Color(0xFFFFFFFF),
      secondary: Color(0xFF2E3035),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFF44474D),
      onSecondaryContainer: Color(0xFFFFFFFF),
      tertiary: Color(0xFF303030),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFF464646),
      onTertiaryContainer: Color(0xFFFFFFFF),
      error: Color(0xFF750000),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFF9C0003),
      onErrorContainer: Color(0xFFFFFFFF),
      surface: Color(0xFFEBEBEB),
      onSurface: Color(0xFF000000),
      onSurfaceVariant: Color(0xFF000000),
      outline: Color(0xFF2E3035),
      outlineVariant: Color(0xFF44474D),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF303030),
      inversePrimary: Color(0xFFC5C6C8),
      primaryFixed: Color(0xFF1B1B1C),
      onPrimaryFixed: Color(0xFFFFFFFF),
      primaryFixedDim: Color(0xFF111112),
      onPrimaryFixedVariant: Color(0xFFFFFFFF),
      secondaryFixed: Color(0xFF44474D),
      onSecondaryFixed: Color(0xFFFFFFFF),
      secondaryFixedDim: Color(0xFF2E3035),
      onSecondaryFixedVariant: Color(0xFFFFFFFF),
      tertiaryFixed: Color(0xFF464646),
      onTertiaryFixed: Color(0xFFFFFFFF),
      tertiaryFixedDim: Color(0xFF303030),
      onTertiaryFixedVariant: Color(0xFFFFFFFF),
      surfaceDim: Color(0xFFD4D4D4),
      surfaceBright: Color(0xFFF9F9F9),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF1F1F1),
      surfaceContainer: Color(0xFFE2E2E2),
      surfaceContainerHigh: Color(0xFFC6C6C6),
      surfaceContainerHighest: Color(0xFFB9B9B9),
    );
  }

  // ---------------------------------------------------------------------------
  // Dark schemes
  // ---------------------------------------------------------------------------

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFD4D4D6),
      surfaceTint: Color(0xFFC5C6C8),
      onPrimary: Color(0xFF252627),
      primaryContainer: Color(0xFF3A3B3D),
      onPrimaryContainer: Color(0xFFE2E2E4),
      secondary: Color(0xFFC8CAD0),
      onSecondary: Color(0xFF2E3035),
      secondaryContainer: Color(0xFF44474D),
      onSecondaryContainer: Color(0xFFE1E2E8),
      tertiary: Color(0xFFB8B8B8),
      onTertiary: Color(0xFF303030),
      tertiaryContainer: Color(0xFF262626),
      onTertiaryContainer: Color(0xFFB8B8B8),
      error: Color(0xFFFFA28C),
      onError: Color(0xFF240D04),
      errorContainer: Color(0xFF9C0003),
      onErrorContainer: Color(0xFFFFBFA9),
      surface: Color(0xFF212121),
      onSurface: Color(0xFFEBEBEB),
      onSurfaceVariant: Color(0xFFC4C6CC),
      outline: Color(0xFF8E9198),
      outlineVariant: Color(0xFF5B5E65),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFE2E2E2),
      inversePrimary: Color(0xFF252627),
      primaryFixed: Color(0xFFE2E2E4),
      onPrimaryFixed: Color(0xFF1B1B1C),
      primaryFixedDim: Color(0xFFC5C6C8),
      onPrimaryFixedVariant: Color(0xFF3A3B3D),
      secondaryFixed: Color(0xFFE1E2E8),
      onSecondaryFixed: Color(0xFF191A20),
      secondaryFixedDim: Color(0xFFC8CAD0),
      onSecondaryFixedVariant: Color(0xFF44474D),
      tertiaryFixed: Color(0xFFF5F5F5),
      onTertiaryFixed: Color(0xFF5D5D5D),
      tertiaryFixedDim: Color(0xFFE2E2E2),
      onTertiaryFixedVariant: Color(0xFF5D5D5D),
      surfaceDim: Color(0xFF1B1B1B),
      surfaceBright: Color(0xFF3B3B3B),
      surfaceContainerLowest: Color(0xFF111111),
      surfaceContainerLow: Color(0xFF262626),
      surfaceContainer: Color(0xFF262626),
      surfaceContainerHigh: Color(0xFF303030),
      surfaceContainerHighest: Color(0xFF3B3B3B),
    );
  }

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFE2E2E4),
      surfaceTint: Color(0xFFC5C6C8),
      onPrimary: Color(0xFF1B1B1C),
      primaryContainer: Color(0xFF8F9193),
      onPrimaryContainer: Color(0xFFFFFFFF),
      secondary: Color(0xFFE1E2E8),
      onSecondary: Color(0xFF2E3035),
      secondaryContainer: Color(0xFF8E9198),
      onSecondaryContainer: Color(0xFFFFFFFF),
      tertiary: Color(0xFFD4D4D4),
      onTertiary: Color(0xFF303030),
      tertiaryContainer: Color(0xFF5D5D5D),
      onTertiaryContainer: Color(0xFFFFFFFF),
      error: Color(0xFFFFBFA9),
      onError: Color(0xFF600000),
      errorContainer: Color(0xFFFE5646),
      onErrorContainer: Color(0xFFFFFFFF),
      surface: Color(0xFF212121),
      onSurface: Color(0xFFFFFFFF),
      onSurfaceVariant: Color(0xFFE1E2E7),
      outline: Color(0xFFA8ABB2),
      outlineVariant: Color(0xFF8E9198),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFE2E2E2),
      inversePrimary: Color(0xFF252627),
      primaryFixed: Color(0xFFE2E2E4),
      onPrimaryFixed: Color(0xFF111112),
      primaryFixedDim: Color(0xFFC5C6C8),
      onPrimaryFixedVariant: Color(0xFF303032),
      secondaryFixed: Color(0xFFE1E2E8),
      onSecondaryFixed: Color(0xFF191A20),
      secondaryFixedDim: Color(0xFFC8CAD0),
      onSecondaryFixedVariant: Color(0xFF44474D),
      tertiaryFixed: Color(0xFFE2E2E2),
      onTertiaryFixed: Color(0xFF1A1A1A),
      tertiaryFixedDim: Color(0xFFC6C6C6),
      onTertiaryFixedVariant: Color(0xFF464646),
      surfaceDim: Color(0xFF1B1B1B),
      surfaceBright: Color(0xFF474747),
      surfaceContainerLowest: Color(0xFF000000),
      surfaceContainerLow: Color(0xFF1B1B1B),
      surfaceContainer: Color(0xFF262626),
      surfaceContainerHigh: Color(0xFF303030),
      surfaceContainerHighest: Color(0xFF3B3B3B),
    );
  }

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFF0F1F1),
      surfaceTint: Color(0xFFC5C6C8),
      onPrimary: Color(0xFF000000),
      primaryContainer: Color(0xFFD4D4D6),
      onPrimaryContainer: Color(0xFF111112),
      secondary: Color(0xFFF0F1F7),
      onSecondary: Color(0xFF191A20),
      secondaryContainer: Color(0xFFC8CAD0),
      onSecondaryContainer: Color(0xFF191A20),
      tertiary: Color(0xFFF0F0F0),
      onTertiary: Color(0xFF1A1A1A),
      tertiaryContainer: Color(0xFFC6C6C6),
      onTertiaryContainer: Color(0xFF1A1A1A),
      error: Color(0xFFFFE4DA),
      onError: Color(0xFF000000),
      errorContainer: Color(0xFFFF9A83),
      onErrorContainer: Color(0xFF210B03),
      surface: Color(0xFF212121),
      onSurface: Color(0xFFFFFFFF),
      onSurfaceVariant: Color(0xFFFFFFFF),
      outline: Color(0xFFE1E2E7),
      outlineVariant: Color(0xFFC4C6CC),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFE2E2E2),
      inversePrimary: Color(0xFF252627),
      primaryFixed: Color(0xFFE2E2E4),
      onPrimaryFixed: Color(0xFF000000),
      primaryFixedDim: Color(0xFFC5C6C8),
      onPrimaryFixedVariant: Color(0xFF1B1B1C),
      secondaryFixed: Color(0xFFE1E2E8),
      onSecondaryFixed: Color(0xFF000000),
      secondaryFixedDim: Color(0xFFC8CAD0),
      onSecondaryFixedVariant: Color(0xFF191A20),
      tertiaryFixed: Color(0xFFE2E2E2),
      onTertiaryFixed: Color(0xFF000000),
      tertiaryFixedDim: Color(0xFFC6C6C6),
      onTertiaryFixedVariant: Color(0xFF1A1A1A),
      surfaceDim: Color(0xFF1B1B1B),
      surfaceBright: Color(0xFF525252),
      surfaceContainerLowest: Color(0xFF000000),
      surfaceContainerLow: Color(0xFF1B1B1B),
      surfaceContainer: Color(0xFF303030),
      surfaceContainerHigh: Color(0xFF3B3B3B),
      surfaceContainerHighest: Color(0xFF474747),
    );
  }

  // ---------------------------------------------------------------------------
  // ThemeData builders
  // ---------------------------------------------------------------------------

  ThemeData theme(ColorScheme colorScheme) {
    // Platform text themes (blackRedwoodCity, etc.) only carry font-family
    // and color — no geometry. Pre-merge M3 geometry so that explicit style
    // references (listTileTheme, etc.) get concrete font sizes.
    final resolved = Typography.englishLike2021.merge(textTheme);

    return ThemeData(
        useMaterial3: true,
        brightness: colorScheme.brightness,
        colorScheme: colorScheme,
        textTheme: resolved.apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        ),
        scaffoldBackgroundColor: colorScheme.surface,
        canvasColor: colorScheme.surface,

        // --- Icon defaults: weight 300, outline (fill 0), 24px ---
        iconTheme: IconThemeData(
          size: 24,
          weight: 300,
          fill: 0,
          opticalSize: 24,
          color: colorScheme.onSurface,
        ),

        // --- Surface architecture: two-tier grey scaffold / white content ---

        appBarTheme: AppBarTheme(
          centerTitle: false,
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),

        navigationBarTheme: NavigationBarThemeData(
          height: 80, // Explicit M3 default — documents intent, prevents drift
          backgroundColor: colorScheme.surfaceContainerLowest,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),

        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: colorScheme.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          showDragHandle: true,
          shape: RoundedRectangleBorder(
            borderRadius: _radii.borderRadiusTopXXLarge,
          ),
        ),

        cardTheme: CardThemeData(
          color: colorScheme.surfaceContainerLowest,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: _radii.borderRadiusLarge,
          ),
        ),

        dialogTheme: DialogThemeData(
          backgroundColor: colorScheme.surfaceContainerLowest,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: _radii.borderRadiusXLarge,
          ),
        ),

        dividerTheme: DividerThemeData(
          color: colorScheme.onSurface.withValues(alpha: _borders.opacity),
          thickness: _borders.width,
          space: _borders.width,
        ),

        drawerTheme: DrawerThemeData(
          backgroundColor: colorScheme.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),

        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: _radii.borderRadiusMedium,
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: UnderlineInputBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(_radii.small),
              topRight: Radius.circular(_radii.small),
            ),
            borderSide: BorderSide(color: colorScheme.outline),
          ),
          enabledBorder: UnderlineInputBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(_radii.small),
              topRight: Radius.circular(_radii.small),
            ),
            borderSide: BorderSide(color: colorScheme.outline),
          ),
          focusedBorder: UnderlineInputBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(_radii.small),
              topRight: Radius.circular(_radii.small),
            ),
            borderSide: BorderSide(
              color: colorScheme.primary,
              width: 2,
            ),
          ),
          errorBorder: UnderlineInputBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(_radii.small),
              topRight: Radius.circular(_radii.small),
            ),
            borderSide: BorderSide(color: colorScheme.error),
          ),
          focusedErrorBorder: UnderlineInputBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(_radii.small),
              topRight: Radius.circular(_radii.small),
            ),
            borderSide: BorderSide(
              color: colorScheme.error,
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.all(_spacing.space16),
        ),

        expansionTileTheme: ExpansionTileThemeData(
          tilePadding: EdgeInsets.symmetric(
            horizontal: _spacing.space16,
            vertical: _spacing.space12,
          ),
          childrenPadding: EdgeInsets.fromLTRB(
            _spacing.space16,
            0,
            _spacing.space16,
            _spacing.space16,
          ),
          shape: const RoundedRectangleBorder(),
          collapsedShape: const RoundedRectangleBorder(),
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          iconColor: colorScheme.onSurfaceVariant,
          collapsedIconColor: colorScheme.onSurfaceVariant,
          clipBehavior: Clip.none,
        ),

        // Layout: all M3 defaults (removed: titleAlignment, minVerticalPadding,
        // minTileHeight, visualDensity, vertical contentPadding).
        // See CONSTRAINTS.md § ListTile Layout Constraint.
        listTileTheme: ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(
            horizontal: _spacing.space16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: _radii.borderRadiusMedium,
          ),
          titleTextStyle: resolved.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
          ),
          subtitleTextStyle: resolved.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          leadingAndTrailingTextStyle: resolved.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
  }

  ThemeData light() => theme(lightScheme());
  ThemeData lightMediumContrast() => theme(lightMediumContrastScheme());
  ThemeData lightHighContrast() => theme(lightHighContrastScheme());
  ThemeData dark() => theme(darkScheme());
  ThemeData darkMediumContrast() => theme(darkMediumContrastScheme());
  ThemeData darkHighContrast() => theme(darkHighContrastScheme());
}
