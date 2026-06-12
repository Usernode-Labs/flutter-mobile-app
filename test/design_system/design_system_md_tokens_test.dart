import 'dart:io';

import 'package:crypto_mobile_app/design_system/theme/color_is_expensive_theme.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_animation.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_borders.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_elevation.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_opacity.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_sizing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

String _px(num value) => '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}px';

void _writeMap(
  StringBuffer buffer,
  String name,
  Map<String, Object> values, {
  int indent = 0,
}) {
  final pad = ' ' * indent;
  buffer.writeln('$pad$name:');
  for (final entry in values.entries) {
    final value = entry.value;
    if (value is Map<String, Object>) {
      _writeMap(buffer, entry.key, value, indent: indent + 2);
    } else {
      buffer.writeln('$pad  ${entry.key}: $value');
    }
  }
}

Map<String, String> _schemeMap(ColorScheme scheme) => {
      'primary': '"${_hex(scheme.primary)}"',
      'onPrimary': '"${_hex(scheme.onPrimary)}"',
      'primaryContainer': '"${_hex(scheme.primaryContainer)}"',
      'onPrimaryContainer': '"${_hex(scheme.onPrimaryContainer)}"',
      'secondary': '"${_hex(scheme.secondary)}"',
      'onSecondary': '"${_hex(scheme.onSecondary)}"',
      'tertiary': '"${_hex(scheme.tertiary)}"',
      'onTertiary': '"${_hex(scheme.onTertiary)}"',
      'error': '"${_hex(scheme.error)}"',
      'surface': '"${_hex(scheme.surface)}"',
      'onSurface': '"${_hex(scheme.onSurface)}"',
      'surfaceContainerLowest': '"${_hex(scheme.surfaceContainerLowest)}"',
      'surfaceContainerLow': '"${_hex(scheme.surfaceContainerLow)}"',
      'surfaceContainer': '"${_hex(scheme.surfaceContainer)}"',
      'surfaceContainerHigh': '"${_hex(scheme.surfaceContainerHigh)}"',
      'outline': '"${_hex(scheme.outline)}"',
      'outlineVariant': '"${_hex(scheme.outlineVariant)}"',
    };

Map<String, String> _semanticGroup(SemanticColorGroup group) => {
      'color': '"${_hex(group.color)}"',
      'onColor': '"${_hex(group.onColor)}"',
      'colorContainer': '"${_hex(group.colorContainer)}"',
      'onColorContainer': '"${_hex(group.onColorContainer)}"',
      'colorSurface': '"${_hex(group.colorSurface)}"',
      'onColorSurface': '"${_hex(group.onColorSurface)}"',
    };

String _generatedFrontmatter() {
  final spacing = AppSpacing.standard();
  final radii = AppRadii.standard();
  final sizing = AppSizing.standard();
  final elevation = AppElevation.standard();
  final opacity = AppOpacity.standard();
  final borders = AppBorders.standard();
  final animation = AppAnimation.standard();
  final semantic = AppSemanticColors.light();

  final buffer = StringBuffer()
    ..writeln('---')
    ..writeln('version: alpha')
    ..writeln('name: Usernode Mobile Design System')
    ..writeln(
      'description: "Generated from Dart token classes; do not edit this frontmatter by hand."',
    )
    ..writeln(
      'generated_by: test/design_system/design_system_md_tokens_test.dart',
    )
    ..writeln('source_of_truth: lib/design_system/tokens');

  _writeMap(buffer, 'colors', {
    'materialLight': _schemeMap(ColorIsExpensiveTheme.lightScheme()),
    'materialDark': _schemeMap(ColorIsExpensiveTheme.darkScheme()),
    'semanticLight': {
      'technical': _semanticGroup(semantic.technical),
      'flash': _semanticGroup(semantic.flash),
      'premium': _semanticGroup(semantic.premium),
      'community': _semanticGroup(semantic.community),
      'success': _semanticGroup(semantic.success),
      'warning': _semanticGroup(semantic.warning),
    },
  });

  _writeMap(buffer, 'typography', {
    'mono': {
      'fontFamily': kMonoFontFamily,
      'usage': '"tabular data and display hero text"',
    },
  });

  _writeMap(buffer, 'spacing', {
    'space4': _px(spacing.space4),
    'space8': _px(spacing.space8),
    'space12': _px(spacing.space12),
    'space16': _px(spacing.space16),
    'space24': _px(spacing.space24),
    'space32': _px(spacing.space32),
    'space48': _px(spacing.space48),
  });

  _writeMap(buffer, 'rounded', {
    'xSmall': _px(radii.xSmall),
    'small': _px(radii.small),
    'medium': _px(radii.medium),
    'large': _px(radii.large),
    'largeIncreased': _px(radii.largeIncreased),
    'xLarge': _px(radii.xLarge),
    'xxLarge': _px(radii.xxLarge),
    'full': _px(radii.full),
  });

  _writeMap(buffer, 'sizing', {
    'iconContainerSmall': _px(sizing.iconContainerSmall),
    'iconContainerRegular': _px(sizing.iconContainerRegular),
    'iconContainerLarge': _px(sizing.iconContainerLarge),
    'iconContainerXLarge': _px(sizing.iconContainerXLarge),
    'iconXSmall': _px(sizing.iconXSmall),
    'iconSmall': _px(sizing.iconSmall),
    'iconRegular': _px(sizing.iconRegular),
    'iconLarge': _px(sizing.iconLarge),
    'iconXLarge': _px(sizing.iconXLarge),
    'iconDisplay': _px(sizing.iconDisplay),
    'iconDisplayLarge': _px(sizing.iconDisplayLarge),
    'buttonHeightSmall': _px(sizing.buttonHeightSmall),
    'buttonHeightRegular': _px(sizing.buttonHeightRegular),
    'buttonHeightLarge': _px(sizing.buttonHeightLarge),
  });

  _writeMap(buffer, 'elevation', {
    'none': elevation.none,
    'low': elevation.low,
    'medium': elevation.medium,
    'high': elevation.high,
    'max': elevation.max,
  });

  _writeMap(buffer, 'opacity', {
    'subtle': opacity.subtle,
    'medium': opacity.medium,
    'strong': opacity.strong,
    'disabled': opacity.disabled,
    'secondary': opacity.secondary,
  });

  _writeMap(buffer, 'borders', {
    'width': _px(borders.width),
    'opacity': borders.opacity,
  });

  _writeMap(buffer, 'animation', {
    'fast': '${animation.fast.inMilliseconds}ms',
    'normal': '${animation.normal.inMilliseconds}ms',
    'slow': '${animation.slow.inMilliseconds}ms',
    'complex': '${animation.complex.inMilliseconds}ms',
  });

  buffer.writeln('---');
  return buffer.toString();
}

String _bodyWithoutFrontmatter(String content) {
  if (!content.startsWith('---\n')) return content;
  final end = content.indexOf('\n---\n', 4);
  if (end == -1) return content;
  return content.substring(end + 5);
}

void main() {
  test('DESIGN_SYSTEM.md token frontmatter is generated from Dart tokens', () {
    final file = File('lib/design_system/DESIGN_SYSTEM.md');
    final content = file.readAsStringSync();
    final expected =
        '${_generatedFrontmatter()}${_bodyWithoutFrontmatter(content)}';

    if (Platform.environment['UPDATE_DESIGN_SYSTEM_MD'] == 'true') {
      file.writeAsStringSync(expected);
    }

    expect(
      file.readAsStringSync(),
      expected,
      reason:
          'DESIGN_SYSTEM.md frontmatter drifted. Run UPDATE_DESIGN_SYSTEM_MD=true flutter test test/design_system/design_system_md_tokens_test.dart',
    );
  });
}
