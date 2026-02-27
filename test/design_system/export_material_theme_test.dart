// ignore_for_file: deprecated_member_use
//
// Exports the "Color is Expensive" design system theme as a Material Theme
// Builder-compatible JSON file.
//
// Run:  flutter test test/design_system/export_material_theme_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:crypto_mobile_app/design_system/theme/color_is_expensive_theme.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

String _hexFromArgb(int argb) =>
    '#${argb.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

Map<String, String> _schemeToMap(ColorScheme s) => {
      'primary': _hex(s.primary),
      'surfaceTint': _hex(s.surfaceTint),
      'onPrimary': _hex(s.onPrimary),
      'primaryContainer': _hex(s.primaryContainer),
      'onPrimaryContainer': _hex(s.onPrimaryContainer),
      'secondary': _hex(s.secondary),
      'onSecondary': _hex(s.onSecondary),
      'secondaryContainer': _hex(s.secondaryContainer),
      'onSecondaryContainer': _hex(s.onSecondaryContainer),
      'tertiary': _hex(s.tertiary),
      'onTertiary': _hex(s.onTertiary),
      'tertiaryContainer': _hex(s.tertiaryContainer),
      'onTertiaryContainer': _hex(s.onTertiaryContainer),
      'error': _hex(s.error),
      'onError': _hex(s.onError),
      'errorContainer': _hex(s.errorContainer),
      'onErrorContainer': _hex(s.onErrorContainer),
      'background': _hex(s.background),
      'onBackground': _hex(s.onBackground),
      'surface': _hex(s.surface),
      'onSurface': _hex(s.onSurface),
      'surfaceVariant': _hex(s.surfaceVariant),
      'onSurfaceVariant': _hex(s.onSurfaceVariant),
      'outline': _hex(s.outline),
      'outlineVariant': _hex(s.outlineVariant),
      'shadow': _hex(s.shadow),
      'scrim': _hex(s.scrim),
      'inverseSurface': _hex(s.inverseSurface),
      'inverseOnSurface': _hex(s.onInverseSurface),
      'inversePrimary': _hex(s.inversePrimary),
      'primaryFixed': _hex(s.primaryFixed),
      'onPrimaryFixed': _hex(s.onPrimaryFixed),
      'primaryFixedDim': _hex(s.primaryFixedDim),
      'onPrimaryFixedVariant': _hex(s.onPrimaryFixedVariant),
      'secondaryFixed': _hex(s.secondaryFixed),
      'onSecondaryFixed': _hex(s.onSecondaryFixed),
      'secondaryFixedDim': _hex(s.secondaryFixedDim),
      'onSecondaryFixedVariant': _hex(s.onSecondaryFixedVariant),
      'tertiaryFixed': _hex(s.tertiaryFixed),
      'onTertiaryFixed': _hex(s.onTertiaryFixed),
      'tertiaryFixedDim': _hex(s.tertiaryFixedDim),
      'onTertiaryFixedVariant': _hex(s.onTertiaryFixedVariant),
      'surfaceDim': _hex(s.surfaceDim),
      'surfaceBright': _hex(s.surfaceBright),
      'surfaceContainerLowest': _hex(s.surfaceContainerLowest),
      'surfaceContainerLow': _hex(s.surfaceContainerLow),
      'surfaceContainer': _hex(s.surfaceContainer),
      'surfaceContainerHigh': _hex(s.surfaceContainerHigh),
      'surfaceContainerHighest': _hex(s.surfaceContainerHighest),
    };

Map<String, String> _semanticGroupToMap(SemanticColorGroup g) => {
      'color': _hex(g.color),
      'onColor': _hex(g.onColor),
      'colorContainer': _hex(g.colorContainer),
      'onColorContainer': _hex(g.onColorContainer),
    };

Map<String, dynamic> _extendedColor({
  required String name,
  required Color seed,
  required Map<String, SemanticColorGroup> schemeVariants,
}) {
  final schemes = <String, Map<String, String>>{};
  for (final entry in schemeVariants.entries) {
    schemes[entry.key] = _semanticGroupToMap(entry.value);
  }
  return {
    'name': name,
    'color': _hex(seed),
    'harmonized': false,
    'schemes': schemes,
  };
}

Map<String, String> _tonalPaletteToMap(TonalPalette palette) {
  const tones = [
    0,
    5,
    10,
    15,
    20,
    25,
    30,
    35,
    40,
    50,
    60,
    70,
    80,
    90,
    95,
    98,
    99,
    100
  ];
  return {for (final t in tones) '$t': _hexFromArgb(palette.get(t))};
}

TonalPalette _paletteFromColor(Color color) {
  final hct = Hct.fromInt(color.toARGB32());
  return TonalPalette.of(hct.hue, hct.chroma);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  test('Export material-theme.json', () {
    // -- Schemes ---------------------------------------------------------------

    final schemes = <String, Map<String, String>>{
      'light': _schemeToMap(ColorIsExpensiveTheme.lightScheme()),
      'light-medium-contrast':
          _schemeToMap(ColorIsExpensiveTheme.lightMediumContrastScheme()),
      'light-high-contrast':
          _schemeToMap(ColorIsExpensiveTheme.lightHighContrastScheme()),
      'dark': _schemeToMap(ColorIsExpensiveTheme.darkScheme()),
      'dark-medium-contrast':
          _schemeToMap(ColorIsExpensiveTheme.darkMediumContrastScheme()),
      'dark-high-contrast':
          _schemeToMap(ColorIsExpensiveTheme.darkHighContrastScheme()),
    };

    // -- Extended colors -------------------------------------------------------

    const variantNames = [
      'light',
      'light-medium-contrast',
      'light-high-contrast',
      'dark',
      'dark-medium-contrast',
      'dark-high-contrast',
    ];

    final semanticVariants = [
      AppSemanticColors.light(),
      AppSemanticColors.lightMediumContrast(),
      AppSemanticColors.lightHighContrast(),
      AppSemanticColors.dark(),
      AppSemanticColors.darkMediumContrast(),
      AppSemanticColors.darkHighContrast(),
    ];

    Map<String, SemanticColorGroup> variantsFor(
      SemanticColorGroup Function(AppSemanticColors) selector,
    ) {
      return {
        for (var i = 0; i < variantNames.length; i++)
          variantNames[i]: selector(semanticVariants[i]),
      };
    }

    final extendedColors = [
      _extendedColor(
        name: 'Technical',
        seed: AppSemanticColors.light().technical.color,
        schemeVariants: variantsFor((s) => s.technical),
      ),
      _extendedColor(
        name: 'Flash',
        seed: AppSemanticColors.light().flash.color,
        schemeVariants: variantsFor((s) => s.flash),
      ),
      _extendedColor(
        name: 'Community',
        seed: AppSemanticColors.light().community.color,
        schemeVariants: variantsFor((s) => s.community),
      ),
      _extendedColor(
        name: 'Success',
        seed: AppSemanticColors.light().success.color,
        schemeVariants: variantsFor((s) => s.success),
      ),
    ];

    // -- Tonal palettes --------------------------------------------------------

    final light = ColorIsExpensiveTheme.lightScheme();

    final palettes = <String, Map<String, String>>{
      'primary': _tonalPaletteToMap(_paletteFromColor(light.primary)),
      'secondary': _tonalPaletteToMap(_paletteFromColor(light.secondary)),
      'tertiary': _tonalPaletteToMap(_paletteFromColor(light.tertiary)),
      'neutral': _tonalPaletteToMap(_paletteFromColor(light.surface)),
      'neutral-variant':
          _tonalPaletteToMap(_paletteFromColor(light.onSurfaceVariant)),
    };

    // -- Assemble & write ------------------------------------------------------

    final json = {
      'description':
          'Color is Expensive theme — exported from Dart source of truth',
      'seed': '#18191B',
      'coreColors': {'primary': '#18191B'},
      'extendedColors': extendedColors,
      'schemes': schemes,
      'palettes': palettes,
    };

    final encoder = const JsonEncoder.withIndent('    ');
    final output = '${encoder.convert(json)}\n';

    final file = File('lib/design_system/material-theme.json');
    file.writeAsStringSync(output);

    // Sanity checks
    expect(file.existsSync(), isTrue);
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(decoded['schemes'], isA<Map>());
    expect((decoded['schemes'] as Map).length, 6);
    expect(decoded['extendedColors'], isA<List>());
    expect((decoded['extendedColors'] as List).length, 4);
    expect(decoded['palettes'], isA<Map>());
    expect((decoded['palettes'] as Map).length, 5);

    // Spot-check: light primary should be #252627
    expect(
      (decoded['schemes'] as Map)['light']['primary'],
      '#252627',
    );
  });
}
