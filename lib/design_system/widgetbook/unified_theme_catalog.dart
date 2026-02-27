import 'package:flutter/material.dart';

import '../src/button.dart';
import '../src/challenge_card.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_spacing.dart';

// =============================================================================
// Unified Theme Catalog — "Color is Expensive" Design System Encyclopedia
//
// A single scrollable page demonstrating the complete design system across
// 9 sections. Each section is a private widget for maintainability.
// =============================================================================

/// The top-level catalog widget. Renders all 9 sections in a scrollable column.
class UnifiedThemeCatalog extends StatelessWidget {
  const UnifiedThemeCatalog({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return SingleChildScrollView(
      padding: EdgeInsets.all(spacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ColorArchitectureSection(),
          SizedBox(height: spacing.space48),
          const _SemanticColorsSection(),
          SizedBox(height: spacing.space48),
          const _SurfaceArchitectureSection(),
          SizedBox(height: spacing.space48),
          const _TypographyScaleSection(),
          SizedBox(height: spacing.space48),
          const _BorderRadiiSection(),
          SizedBox(height: spacing.space48),
          const _SpacingScaleSection(),
          SizedBox(height: spacing.space48),
          const _DesignTensionsSection(),
          SizedBox(height: spacing.space48),
          const _ComponentShowcaseSection(),
          SizedBox(height: spacing.space48),
          const _M3DynamicColorSection(),
          SizedBox(height: spacing.space48),
        ],
      ),
    );
  }
}

// =============================================================================
// Shared helpers
// =============================================================================

class _SwatchData {
  const _SwatchData(this.label, this.color, this.contrastColor);
  final String label;
  final Color color;
  final Color contrastColor;
}

Widget _sectionHeader(BuildContext context, String title, {String? subtitle}) {
  final textTheme = Theme.of(context).textTheme;
  final colors = Theme.of(context).colorScheme;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: textTheme.headlineSmall?.copyWith(color: colors.onSurface),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
      const SizedBox(height: 16),
    ],
  );
}

Widget _subsectionTitle(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 16),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
    ),
  );
}

Widget _colorSwatch(BuildContext context, _SwatchData swatch, {double? width}) {
  final hex =
      '#${swatch.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  return Container(
    width: width ?? 120,
    height: 72,
    decoration: BoxDecoration(
      color: swatch.color,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: Theme.of(context).colorScheme.outlineVariant,
        width: 0.5,
      ),
    ),
    padding: const EdgeInsets.all(8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          swatch.label,
          style: TextStyle(
            color: swatch.contrastColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(hex, style: TextStyle(color: swatch.contrastColor, fontSize: 9)),
      ],
    ),
  );
}

Widget _swatchRow(
  BuildContext context,
  List<_SwatchData> swatches, {
  double? swatchWidth,
}) {
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: swatches
        .map((s) => _colorSwatch(context, s, width: swatchWidth))
        .toList(),
  );
}

Widget _annotationBox(BuildContext context, String text) {
  final colors = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: colors.outlineVariant),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.onSurface,
            fontStyle: FontStyle.italic,
          ),
    ),
  );
}

// =============================================================================
// Section 1: Color Architecture
// =============================================================================

class _ColorArchitectureSection extends StatelessWidget {
  const _ColorArchitectureSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          '1. Color Architecture',
          subtitle: 'The full M3 ColorScheme role map — achromatic by design',
        ),

        // Primary family
        _subsectionTitle(context, 'Primary Family'),
        _swatchRow(context, [
          _SwatchData('primary', cs.primary, cs.onPrimary),
          _SwatchData('onPrimary', cs.onPrimary, cs.primary),
          _SwatchData(
            'primaryContainer',
            cs.primaryContainer,
            cs.onPrimaryContainer,
          ),
          _SwatchData(
            'onPrimaryContainer',
            cs.onPrimaryContainer,
            cs.primaryContainer,
          ),
        ]),
        const SizedBox(height: 8),
        _swatchRow(context, [
          _SwatchData('primaryFixed', cs.primaryFixed, cs.onPrimaryFixed),
          _SwatchData(
            'primaryFixedDim',
            cs.primaryFixedDim,
            cs.onPrimaryFixedVariant,
          ),
        ]),

        // Secondary family
        _subsectionTitle(context, 'Secondary Family'),
        _swatchRow(context, [
          _SwatchData('secondary', cs.secondary, cs.onSecondary),
          _SwatchData('onSecondary', cs.onSecondary, cs.secondary),
          _SwatchData(
            'secondaryContainer',
            cs.secondaryContainer,
            cs.onSecondaryContainer,
          ),
          _SwatchData(
            'onSecondaryContainer',
            cs.onSecondaryContainer,
            cs.secondaryContainer,
          ),
        ]),
        const SizedBox(height: 8),
        _swatchRow(context, [
          _SwatchData('secondaryFixed', cs.secondaryFixed, cs.onSecondaryFixed),
          _SwatchData(
            'secondaryFixedDim',
            cs.secondaryFixedDim,
            cs.onSecondaryFixedVariant,
          ),
        ]),

        // Tertiary (Ghost) family
        _subsectionTitle(context, 'Tertiary Family (Ghost)'),
        _annotationBox(
          context,
          'The "ghost" role: tertiary is deliberately near-invisible. Developers reaching for tertiary get grey — forcing them toward AppSemanticColors.',
        ),
        const SizedBox(height: 8),
        _swatchRow(context, [
          _SwatchData('tertiary', cs.tertiary, cs.onTertiary),
          _SwatchData('onTertiary', cs.onTertiary, cs.tertiary),
          _SwatchData(
            'tertiaryContainer',
            cs.tertiaryContainer,
            cs.onTertiaryContainer,
          ),
          _SwatchData(
            'onTertiaryContainer',
            cs.onTertiaryContainer,
            cs.tertiaryContainer,
          ),
        ]),
        const SizedBox(height: 8),
        _swatchRow(context, [
          _SwatchData('tertiaryFixed', cs.tertiaryFixed, cs.onTertiaryFixed),
          _SwatchData(
            'tertiaryFixedDim',
            cs.tertiaryFixedDim,
            cs.onTertiaryFixedVariant,
          ),
        ]),

        // Error family
        _subsectionTitle(context, 'Error Family'),
        _annotationBox(
          context,
          'The ONLY chromatic family in the core ColorScheme. Red earns its place through universal semantic meaning.',
        ),
        const SizedBox(height: 8),
        _swatchRow(context, [
          _SwatchData('error', cs.error, cs.onError),
          _SwatchData('onError', cs.onError, cs.error),
          _SwatchData('errorContainer', cs.errorContainer, cs.onErrorContainer),
          _SwatchData(
            'onErrorContainer',
            cs.onErrorContainer,
            cs.errorContainer,
          ),
        ]),

        // Surface system
        _subsectionTitle(context, 'Surface System'),
        _swatchRow(context, [
          _SwatchData('surface', cs.surface, cs.onSurface),
          _SwatchData('surfaceDim', cs.surfaceDim, cs.onSurface),
          _SwatchData('surfaceBright', cs.surfaceBright, cs.onSurface),
        ]),
        const SizedBox(height: 8),
        _swatchRow(context, [
          _SwatchData(
            'containerLowest',
            cs.surfaceContainerLowest,
            cs.onSurface,
          ),
          _SwatchData('containerLow', cs.surfaceContainerLow, cs.onSurface),
          _SwatchData('container', cs.surfaceContainer, cs.onSurface),
          _SwatchData('containerHigh', cs.surfaceContainerHigh, cs.onSurface),
          _SwatchData(
            'containerHighest',
            cs.surfaceContainerHighest,
            cs.onSurface,
          ),
        ]),

        // On-surface / outline
        _subsectionTitle(context, 'On-Surface & Outline'),
        _swatchRow(context, [
          _SwatchData('onSurface', cs.onSurface, cs.surface),
          _SwatchData('onSurfaceVariant', cs.onSurfaceVariant, cs.surface),
          _SwatchData('outline', cs.outline, cs.surface),
          _SwatchData('outlineVariant', cs.outlineVariant, cs.surface),
        ]),

        // Inverse
        _subsectionTitle(context, 'Inverse & Overlay'),
        _swatchRow(context, [
          _SwatchData('inverseSurface', cs.inverseSurface, cs.inversePrimary),
          _SwatchData('inversePrimary', cs.inversePrimary, cs.inverseSurface),
          _SwatchData('scrim', cs.scrim, cs.onPrimary),
          _SwatchData('shadow', cs.shadow, cs.onPrimary),
        ]),
      ],
    );
  }
}

// =============================================================================
// Section 2: Semantic Colors
// =============================================================================

class _SemanticColorsSection extends StatelessWidget {
  const _SemanticColorsSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          '2. Semantic Colors',
          subtitle: 'Where Color Earns Its Place',
        ),
        _annotationBox(
          context,
          'These are the ONLY sanctioned paths to chromatic color. Every hue below carries a specific domain meaning.',
        ),
        const SizedBox(height: 16),

        // Semantic groups side by side
        _semanticGroupRow(context, 'Technical (Blue)', semantic.technical),
        const SizedBox(height: 12),
        _semanticGroupRow(context, 'Flash (Amber)', semantic.flash),
        const SizedBox(height: 12),
        _semanticGroupRow(context, 'Community (Green)', semantic.community),
        const SizedBox(height: 12),
        _semanticGroupRow(context, 'Success (Green)', semantic.success),
        const SizedBox(height: 24),

        // Contrast: achromatic structural palette
        _subsectionTitle(
          context,
          'Contrast: The Achromatic Structural Palette',
        ),
        _annotationBox(
          context,
          'Compared to the chromatic semantic colors above, the structural palette is entirely greyscale. Hue enters ONLY through the semantic extension.',
        ),
        const SizedBox(height: 8),
        _swatchRow(context, [
          _SwatchData('primary', cs.primary, cs.onPrimary),
          _SwatchData('secondary', cs.secondary, cs.onSecondary),
          _SwatchData('tertiary', cs.tertiary, cs.onTertiary),
          _SwatchData('surface', cs.surface, cs.onSurface),
          _SwatchData('outline', cs.outline, cs.surface),
        ]),
      ],
    );
  }

  Widget _semanticGroupRow(
    BuildContext context,
    String name,
    SemanticColorGroup group,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 4),
        _swatchRow(context, [
          _SwatchData('color', group.color, group.onColor),
          _SwatchData('onColor', group.onColor, group.color),
          _SwatchData(
            'colorContainer',
            group.colorContainer,
            group.onColorContainer,
          ),
          _SwatchData(
            'onColorContainer',
            group.onColorContainer,
            group.colorContainer,
          ),
        ]),
      ],
    );
  }
}

// =============================================================================
// Section 3: Surface Architecture
// =============================================================================

class _SurfaceArchitectureSection extends StatelessWidget {
  const _SurfaceArchitectureSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          '3. Surface Architecture',
          subtitle: 'Grey Scaffold / White Content',
        ),

        // Two-tier demo
        Container(
          padding: EdgeInsets.all(spacing.space24),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SCAFFOLD LAYER',
                style: textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'surface (grey canvas)',
                style: textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              SizedBox(height: spacing.space16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(spacing.space16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONTENT LAYER',
                      style: textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'surfaceContainerLowest (white content card)',
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: spacing.space12),
                    Text(
                      'Cards, sheets, nav bars, and dialogs sit as white panels on the grey canvas.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.space24),

        // 5-level container gradient
        _subsectionTitle(context, 'Surface Container Gradient'),
        _annotationBox(
          context,
          'Five levels are defined, but only two are primary: surface (scaffold) and surfaceContainerLowest (content). The rest are available for edge cases.',
        ),
        const SizedBox(height: 8),
        ..._buildContainerGradient(context, cs),
      ],
    );
  }

  List<Widget> _buildContainerGradient(BuildContext context, ColorScheme cs) {
    final textTheme = Theme.of(context).textTheme;
    final levels = <(String, Color, bool)>[
      ('surfaceContainerLowest', cs.surfaceContainerLowest, true),
      ('surfaceContainerLow', cs.surfaceContainerLow, false),
      ('surfaceContainer', cs.surfaceContainer, false),
      ('surfaceContainerHigh', cs.surfaceContainerHigh, false),
      ('surfaceContainerHighest', cs.surfaceContainerHighest, false),
    ];

    return levels.map((level) {
      final (name, color, isActive) = level;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? cs.primary : cs.outlineVariant,
              width: isActive ? 2 : 0.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: textTheme.bodySmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ACTIVE TIER',
                    style: textTheme.labelSmall?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

// =============================================================================
// Section 4: Typography Scale
// =============================================================================

class _TypographyScaleSection extends StatelessWidget {
  const _TypographyScaleSection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    final styles = <(String, TextStyle?)>[
      ('displayLarge', textTheme.displayLarge),
      ('displayMedium', textTheme.displayMedium),
      ('displaySmall', textTheme.displaySmall),
      ('headlineLarge', textTheme.headlineLarge),
      ('headlineMedium', textTheme.headlineMedium),
      ('headlineSmall', textTheme.headlineSmall),
      ('titleLarge', textTheme.titleLarge),
      ('titleMedium', textTheme.titleMedium),
      ('titleSmall', textTheme.titleSmall),
      ('bodyLarge', textTheme.bodyLarge),
      ('bodyMedium', textTheme.bodyMedium),
      ('bodySmall', textTheme.bodySmall),
      ('labelLarge', textTheme.labelLarge),
      ('labelMedium', textTheme.labelMedium),
      ('labelSmall', textTheme.labelSmall),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          '4. Typography Scale',
          subtitle:
              'Typography does the heavy lifting — color only enters when meaning demands it',
        ),

        // 4A: The scale reference
        _subsectionTitle(context, '4A. The Full Type Scale'),
        _annotationBox(
          context,
          'In a "color is expensive" system, typography hierarchy IS the '
          'primary visual hierarchy. Size, weight, and color-role (onSurface '
          'vs onSurfaceVariant) create all the differentiation structure '
          'needs — without spending a single chromatic pixel.',
        ),
        const SizedBox(height: 12),
        ...styles.map((entry) {
          final (name, style) = entry;
          final size = style?.fontSize?.toStringAsFixed(0) ?? '?';
          final weight = style?.fontWeight?.index.toString() ?? '?';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'The quick brown fox',
                    style: style?.copyWith(color: cs.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${size}px / w$weight',
                    style: textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        SizedBox(height: spacing.space32),

        // 4B: The achromatic hierarchy — typography + the two text colors
        _subsectionTitle(
          context,
          '4B. The Two-Color Text System',
        ),
        _annotationBox(
          context,
          'The entire structural text hierarchy runs on exactly two achromatic '
          'colors: onSurface (primary text) and onSurfaceVariant (secondary '
          'text). Size and weight create the reading order. Color demotion '
          '(onSurface → onSurfaceVariant) signals "supporting" vs '
          '"primary" — no hue required.',
        ),
        const SizedBox(height: 12),
        _TypographyHierarchyDemo(),

        SizedBox(height: spacing.space32),

        // 4C: When color enters — the chromatic punctuation
        _subsectionTitle(
          context,
          '4C. Chromatic Punctuation — When Color Enters Typography',
        ),
        _annotationBox(
          context,
          'In a restrained system, the moment chromatic color appears in text '
          'it acts like punctuation — it interrupts the achromatic flow to '
          'signal meaning. Below: the same content layout with and without '
          'semantic color. Notice how the colored element instantly draws '
          'the eye because there\'s no chromatic competition.',
        ),
        const SizedBox(height: 12),
        _ChromaticPunctuationDemo(),

        SizedBox(height: spacing.space32),

        // 4D: Practical composition — how a real screen combines all layers
        _subsectionTitle(
          context,
          '4D. Composition — Typography Hierarchy Meets Semantic Color',
        ),
        _annotationBox(
          context,
          'A realistic card composition demonstrating how typography scale, '
          'achromatic text colors, and semantic color work as three '
          'complementary layers. Typography establishes reading order. '
          'Achromatic color (onSurface/onSurfaceVariant) separates primary '
          'from supporting content. Semantic color carries domain meaning — '
          'here, challenge categories.',
        ),
        const SizedBox(height: 12),
        _TypographyCompositionDemo(semantic: semantic),

        SizedBox(height: spacing.space32),

        // 4E: The anti-pattern
        _subsectionTitle(
          context,
          '4E. The Signal-to-Noise Ratio',
        ),
        _annotationBox(
          context,
          'Why restraint matters: when every text element carries its own '
          'chromatic accent, the eye has no entry point. When color is '
          'scarce, it acts as a spotlight. Below: the same information '
          'with color used as decoration vs color used as signal.',
        ),
        const SizedBox(height: 12),
        _SignalToNoiseDemo(semantic: semantic),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4B: Typography Hierarchy Demo
// ---------------------------------------------------------------------------

class _TypographyHierarchyDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radii = Theme.of(context).extension<AppRadii>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(radii.large),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simulate a screen's text hierarchy
          Text(
            'Challenge Overview',
            style: textTheme.headlineSmall?.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Your active challenges this epoch',
            style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          // A "card" within the demo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Validate 50 Transactions',
                  style: textTheme.titleMedium?.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete transaction validations to strengthen network security and earn rewards.',
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Mar 1 – Mar 15',
                      style: textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '250 pts',
                      style: textTheme.labelLarge?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Annotation showing the mapping
          Row(
            children: [
              _TextRoleChip(
                label: 'onSurface',
                color: cs.onSurface,
                background: cs.surfaceContainerHighest,
              ),
              const SizedBox(width: 8),
              Text(
                'Primary text — titles, values, actions',
                style: textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _TextRoleChip(
                label: 'onSurfaceVariant',
                color: cs.onSurfaceVariant,
                background: cs.surfaceContainerHighest,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Supporting text — descriptions, dates, metadata',
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TextRoleChip extends StatelessWidget {
  const _TextRoleChip({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4C: Chromatic Punctuation Demo
// ---------------------------------------------------------------------------

class _ChromaticPunctuationDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Without semantic color
        Text(
          'Without semantic color:',
          style: textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        _PunctuationCard(
          radii: radii,
          cs: cs,
          textTheme: textTheme,
          badgeColor: cs.surfaceContainerHighest,
          badgeTextColor: cs.onSurface,
          badgeLabel: 'Technical',
          statusColor: cs.onSurfaceVariant,
          statusLabel: '32 / 50 completed',
        ),
        const SizedBox(height: 16),

        // With semantic color — only the badge changes
        Text(
          'With semantic color — only the category badge:',
          style: textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        _PunctuationCard(
          radii: radii,
          cs: cs,
          textTheme: textTheme,
          badgeColor: semantic.technical.colorContainer,
          badgeTextColor: semantic.technical.onColorContainer,
          badgeLabel: 'Technical',
          statusColor: cs.onSurfaceVariant,
          statusLabel: '32 / 50 completed',
        ),
        const SizedBox(height: 12),
        _annotationBox(
          context,
          'Same layout, same typography, same hierarchy. The single chromatic '
          'badge instantly signals domain meaning (blue = technical) '
          'because it\'s the ONLY color on the card. The achromatic '
          'typography provides the calm structure that makes the color '
          'punctuation work.',
        ),
      ],
    );
  }
}

class _PunctuationCard extends StatelessWidget {
  const _PunctuationCard({
    required this.radii,
    required this.cs,
    required this.textTheme,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.badgeLabel,
    required this.statusColor,
    required this.statusLabel,
  });

  final AppRadii radii;
  final ColorScheme cs;
  final TextTheme textTheme;
  final Color badgeColor;
  final Color badgeTextColor;
  final String badgeLabel;
  final Color statusColor;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(radii.large),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(radii.small),
                ),
                child: Text(
                  badgeLabel,
                  style: textTheme.labelSmall?.copyWith(
                    color: badgeTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                statusLabel,
                style: textTheme.labelSmall?.copyWith(color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Validate 50 Transactions',
            style: textTheme.titleMedium?.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Complete transaction validations to strengthen network security.',
            style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Mar 1 – Mar 15',
                style: textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '250 pts',
                style: textTheme.labelLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4D: Typography Composition Demo
// ---------------------------------------------------------------------------

class _TypographyCompositionDemo extends StatelessWidget {
  const _TypographyCompositionDemo({required this.semantic});

  final AppSemanticColors semantic;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radii = Theme.of(context).extension<AppRadii>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(radii.large),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen header area
          Text(
            'Active Challenges',
            style: textTheme.headlineSmall?.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 2),
          Text(
            '3 challenges · Epoch 42',
            style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          // Three mini-cards with different categories
          _CompositionMiniCard(
            cs: cs,
            textTheme: textTheme,
            radii: radii,
            categoryLabel: 'Technical',
            categoryColor: semantic.technical.colorContainer,
            categoryTextColor: semantic.technical.onColorContainer,
            title: 'Validate 50 Transactions',
            subtitle: '32 / 50 completed',
            points: '250 pts',
          ),
          const SizedBox(height: 8),
          _CompositionMiniCard(
            cs: cs,
            textTheme: textTheme,
            radii: radii,
            categoryLabel: 'Flash',
            categoryColor: semantic.flash.colorContainer,
            categoryTextColor: semantic.flash.onColorContainer,
            title: 'Speed Run: 10 Blocks in 1hr',
            subtitle: 'Ends in 45 min',
            points: '500 pts',
          ),
          const SizedBox(height: 8),
          _CompositionMiniCard(
            cs: cs,
            textTheme: textTheme,
            radii: radii,
            categoryLabel: 'Community',
            categoryColor: semantic.community.colorContainer,
            categoryTextColor: semantic.community.onColorContainer,
            title: 'Invite 5 Validators',
            subtitle: '2 / 5 invited',
            points: '150 pts',
          ),
          const SizedBox(height: 16),
          // Layer annotations
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Three layers working together:',
                  style: textTheme.labelMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _LayerAnnotation(
                  cs: cs,
                  textTheme: textTheme,
                  number: '1',
                  label: 'Typography scale',
                  description:
                      'headline → title → body → label creates reading order',
                ),
                const SizedBox(height: 4),
                _LayerAnnotation(
                  cs: cs,
                  textTheme: textTheme,
                  number: '2',
                  label: 'Achromatic color',
                  description:
                      'onSurface vs onSurfaceVariant separates primary from supporting',
                ),
                const SizedBox(height: 4),
                _LayerAnnotation(
                  cs: cs,
                  textTheme: textTheme,
                  number: '3',
                  label: 'Semantic color',
                  description:
                      'Category badges are the ONLY chromatic elements — each one signals domain meaning',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompositionMiniCard extends StatelessWidget {
  const _CompositionMiniCard({
    required this.cs,
    required this.textTheme,
    required this.radii,
    required this.categoryLabel,
    required this.categoryColor,
    required this.categoryTextColor,
    required this.title,
    required this.subtitle,
    required this.points,
  });

  final ColorScheme cs;
  final TextTheme textTheme;
  final AppRadii radii;
  final String categoryLabel;
  final Color categoryColor;
  final Color categoryTextColor;
  final String title;
  final String subtitle;
  final String points;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(radii.medium),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: categoryColor,
              borderRadius: BorderRadius.circular(radii.small),
            ),
            child: Text(
              categoryLabel,
              style: textTheme.labelSmall?.copyWith(
                color: categoryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            points,
            style: textTheme.labelLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerAnnotation extends StatelessWidget {
  const _LayerAnnotation({
    required this.cs,
    required this.textTheme,
    required this.number,
    required this.label,
    required this.description,
  });

  final ColorScheme cs;
  final TextTheme textTheme;
  final String number;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              color: cs.onPrimary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: description,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4E: Signal-to-Noise Demo
// ---------------------------------------------------------------------------

class _SignalToNoiseDemo extends StatelessWidget {
  const _SignalToNoiseDemo({required this.semantic});

  final AppSemanticColors semantic;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radii = Theme.of(context).extension<AppRadii>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Noisy" version — color as decoration
        Text(
          'Color as decoration (high noise):',
          style: textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(radii.large),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Every text element gets its own chromatic color
              Text(
                'Active Challenges',
                style: textTheme.titleMedium?.copyWith(
                  color: semantic.technical.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Complete these to earn rewards',
                style: textTheme.bodySmall?.copyWith(
                  color: semantic.community.color,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: semantic.flash.colorContainer,
                  borderRadius: BorderRadius.circular(radii.small),
                ),
                child: Text(
                  'Technical',
                  style: textTheme.labelSmall?.copyWith(
                    color: semantic.flash.onColorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Validate 50 Transactions',
                style: textTheme.titleSmall?.copyWith(
                  color: semantic.flash.color,
                ),
              ),
              Text(
                '250 pts · 32 / 50 completed',
                style: textTheme.bodySmall?.copyWith(
                  color: semantic.success.color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // "Clean" version — color as signal
        Text(
          'Color as signal (high clarity):',
          style: textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(radii.large),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Only structural achromatic text
              Text(
                'Active Challenges',
                style: textTheme.titleMedium?.copyWith(color: cs.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                'Complete these to earn rewards',
                style: textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              // ONE semantic badge — the only chromatic element
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: semantic.technical.colorContainer,
                  borderRadius: BorderRadius.circular(radii.small),
                ),
                child: Text(
                  'Technical',
                  style: textTheme.labelSmall?.copyWith(
                    color: semantic.technical.onColorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Validate 50 Transactions',
                style: textTheme.titleSmall?.copyWith(color: cs.onSurface),
              ),
              Text(
                '250 pts · 32 / 50 completed',
                style: textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _annotationBox(
          context,
          'Top: 5 different chromatic colors compete for attention — the '
          'eye bounces between them with no clear entry point. '
          'The category badge (amber "Technical") is WRONG — it uses '
          'flash colors for a technical challenge.\n\n'
          'Bottom: Typography and achromatic demotion handle the hierarchy. '
          'The single blue badge is instantly readable because scarcity '
          'creates signal. This is "color is expensive" in practice: '
          'every chromatic pixel earns its place.',
        ),
      ],
    );
  }
}

// =============================================================================
// Section 5: Border Radii
// =============================================================================

class _BorderRadiiSection extends StatelessWidget {
  const _BorderRadiiSection();

  @override
  Widget build(BuildContext context) {
    final radii = Theme.of(context).extension<AppRadii>()!;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final entries = <(String, double, String)>[
      ('small', radii.small, 'Chips, badges'),
      ('medium', radii.medium, 'ListTiles, snackbars'),
      ('large', radii.large, 'Cards'),
      ('largeIncreased', radii.largeIncreased, 'ChallengeCard'),
      ('xLarge', radii.xLarge, 'Dialogs, sheets'),
      ('full', radii.full, 'Buttons (pill)'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          '5. Border Radii',
          subtitle: 'AppRadii token scale',
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: entries.map((entry) {
            final (name, value, usage) = entry;
            final displayRadius = value > 40 ? 40.0 : value;
            return SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(displayRadius),
                      border: Border.all(color: cs.primary, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      value.toStringAsFixed(0),
                      style: textTheme.titleMedium?.copyWith(
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: textTheme.labelMedium?.copyWith(color: cs.onSurface),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    usage,
                    style: textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// =============================================================================
// Section 6: Spacing Scale
// =============================================================================

class _SpacingScaleSection extends StatelessWidget {
  const _SpacingScaleSection();

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final entries = <(String, double)>[
      ('space4', spacing.space4),
      ('space8', spacing.space8),
      ('space12', spacing.space12),
      ('space16', spacing.space16),
      ('space24', spacing.space24),
      ('space32', spacing.space32),
      ('space48', spacing.space48),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          '6. Spacing Scale',
          subtitle: '4dp grid alignment',
        ),
        ...entries.map((entry) {
          final (name, value) = entry;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    name,
                    style: textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${value.toStringAsFixed(0)}dp',
                    style: textTheme.labelSmall?.copyWith(color: cs.onSurface),
                  ),
                ),
                Container(
                  width: value * 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// =============================================================================
// Section 7: Design Tensions & Resolutions
// =============================================================================

class _DesignTensionsSection extends StatelessWidget {
  const _DesignTensionsSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          '7. Design Tensions & Resolutions',
          subtitle: 'Key trade-offs visualized',
        ),

        // 7A: Achromatic Primary vs Brand Identity
        _TensionCard(
          title: 'Achromatic Primary vs Brand Identity',
          caption: 'Shape communicates action. Color is reserved for meaning.',
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                  ),
                  child: const Text('Achromatic CTA'),
                ),
              ),
              SizedBox(width: spacing.space12),
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                  ),
                  child: const Text('Chromatic (error)'),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.space16),

        // 7B: Ghost Tertiary Trap
        _TensionCard(
          title: 'Ghost Tertiary Trap',
          caption:
              'Developers reaching for tertiary get grey. This is intentional.',
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'tertiaryContainer',
                    style: TextStyle(
                      color: cs.onTertiaryContainer,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              SizedBox(width: spacing.space12),
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'surface',
                    style: TextStyle(color: cs.onSurface, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.space16),

        // 7C: Two-Tier vs Five-Level
        _TensionCard(
          title: 'Two-Tier vs Five-Level',
          caption:
              'Five levels defined, two actively used. Simplification through conviction.',
          child: _buildFiveLevelBar(context, cs),
        ),
        SizedBox(height: spacing.space16),

        // 7D: Chromatic Budget
        _TensionCard(
          title: 'Chromatic Budget',
          caption: 'Scarcity = value. ~95% achromatic, ~5% chromatic.',
          child: _buildChromaticBudget(context, cs, semantic),
        ),
        SizedBox(height: spacing.space16),

        // 7E: Contrast Cascade
        _TensionCard(
          title: 'Contrast Cascade',
          caption:
              'Ghost tertiary at current contrast level. Switch themes in Widgetbook to see progressive restoration.',
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.tertiary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'tertiary',
                    style: TextStyle(color: cs.onTertiary, fontSize: 11),
                  ),
                ),
              ),
              SizedBox(width: spacing.space8),
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'tertiaryContainer',
                    style: TextStyle(
                      color: cs.onTertiaryContainer,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFiveLevelBar(BuildContext context, ColorScheme cs) {
    final levels = <(String, Color, bool)>[
      ('Lowest', cs.surfaceContainerLowest, true),
      ('Low', cs.surfaceContainerLow, false),
      ('Base', cs.surfaceContainer, false),
      ('High', cs.surfaceContainerHigh, false),
      ('Highest', cs.surfaceContainerHighest, false),
    ];

    return Column(
      children: [
        // Active tiers shown large
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.primary, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  'surface (scaffold)',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 3,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.primary, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  'containerLowest (content)',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // All five as thin bars
        Row(
          children: levels.map((level) {
            final (label, color, isActive) = level;
            return Expanded(
              child: Container(
                height: isActive ? 20 : 12,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: isActive ? cs.primary : cs.outlineVariant,
                    width: isActive ? 1.5 : 0.5,
                  ),
                ),
                alignment: Alignment.center,
                child: isActive
                    ? Text(
                        label,
                        style: TextStyle(color: cs.onSurface, fontSize: 8),
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildChromaticBudget(
    BuildContext context,
    ColorScheme cs,
    AppSemanticColors semantic,
  ) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 32,
            child: Row(
              children: [
                Expanded(
                  flex: 95,
                  child: Container(
                    color: cs.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Text(
                      'ACHROMATIC ~95%',
                      style: TextStyle(color: cs.onSurface, fontSize: 9),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(color: semantic.technical.color),
                ),
                Expanded(
                  flex: 1,
                  child: Container(color: semantic.flash.color),
                ),
                Expanded(
                  flex: 1,
                  child: Container(color: semantic.community.color),
                ),
                Expanded(flex: 1, child: Container(color: cs.error)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _budgetLegend(context, 'Technical', semantic.technical.color),
            _budgetLegend(context, 'Flash', semantic.flash.color),
            _budgetLegend(context, 'Community', semantic.community.color),
            _budgetLegend(context, 'Error', cs.error),
          ],
        ),
      ],
    );
  }

  Widget _budgetLegend(BuildContext context, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable card for tension demonstrations.
class _TensionCard extends StatelessWidget {
  const _TensionCard({
    required this.title,
    required this.caption,
    required this.child,
  });

  final String title;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 12),
          child,
          const SizedBox(height: 8),
          Text(
            caption,
            style: textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Section 8: Component Showcase
// =============================================================================

class _ComponentShowcaseSection extends StatelessWidget {
  const _ComponentShowcaseSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          '8. Component Showcase',
          subtitle: 'M3 components in the achromatic theme',
        ),

        // Buttons
        _subsectionTitle(context, 'Buttons'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const Button(
              label: 'Primary',
              variant: ButtonVariant.primary,
              onTap: _noop,
            ),
            const Button(
              label: 'Tonal',
              variant: ButtonVariant.tonal,
              onTap: _noop,
            ),
            const Button(
              label: 'Outlined',
              variant: ButtonVariant.outlined,
              onTap: _noop,
            ),
            const Button(
              label: 'Surface',
              variant: ButtonVariant.surface,
              onTap: _noop,
            ),
          ],
        ),
        SizedBox(height: spacing.space24),

        // Toggle controls
        _subsectionTitle(context, 'Toggle Controls'),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Switch(value: true, onChanged: (_) {}),
            Switch(value: false, onChanged: (_) {}),
            Checkbox(value: true, onChanged: (_) {}),
            Checkbox(value: false, onChanged: (_) {}),
            RadioGroup<int>(
              groupValue: 1,
              onChanged: (_) {},
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Radio<int>(value: 1), Radio<int>(value: 2)],
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.space24),

        // Card (outlined)
        _subsectionTitle(context, 'Card (Outlined)'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Outlined Card',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  'White background, outlineVariant border, zero elevation.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: spacing.space24),

        // Chips
        _subsectionTitle(context, 'Chip Variants'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('Selected'),
              selected: true,
              onSelected: (_) {},
            ),
            FilterChip(
              label: const Text('Unselected'),
              selected: false,
              onSelected: (_) {},
            ),
            InputChip(label: const Text('Input'), onDeleted: () {}),
            const ActionChip(label: Text('Action'), onPressed: _noop),
          ],
        ),
        SizedBox(height: spacing.space24),

        // NavigationBar mockup
        _subsectionTitle(context, 'NavigationBar'),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: NavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Explore',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.space24),

        // Challenge Card — semantic bridge
        _subsectionTitle(context, 'Challenge Card (Semantic Colors)'),
        _annotationBox(
          context,
          'The bridge from achromatic structure to chromatic content — semantic color appears only in the reward bar.',
        ),
        const SizedBox(height: 8),
        ChallengeCard(
          title: 'Build a Smart Contract',
          description:
              'Deploy and test a simple smart contract on the testnet.',
          dateRange: 'Feb 24 – Mar 2',
          category: ChallengeCategory.technical,
          categoryIcon: Icon(Icons.code, color: semantic.technical.color),
          variant: ChallengeCardVariant.ongoing,
          earnedPoints: '120 pts',
          epochPoints: '500 pts',
        ),
      ],
    );
  }
}

void _noop() {}

// =============================================================================
// Section 9: M3 Dynamic Color Theming
// =============================================================================

class _M3DynamicColorSection extends StatelessWidget {
  const _M3DynamicColorSection();

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          '9. M3 Dynamic Color Theming',
          subtitle: 'How the Machine Works',
        ),

        // 9A: Role Map
        _subsectionTitle(
          context,
          '9A. The ColorScheme Role Map — Live Anatomy',
        ),
        _annotationBox(
          context,
          'M3 components are role-consumers, not color-consumers. Change the role values, and every component updates simultaneously.',
        ),
        const SizedBox(height: 12),
        _RoleMapDemo(),
        SizedBox(height: spacing.space32),

        // 9B: Theme Switching
        _subsectionTitle(
          context,
          '9B. Theme Switching — The Power of Indirection',
        ),
        _annotationBox(
          context,
          'The same components rendered under different ColorScheme configurations. Swapping one ColorScheme transforms everything.',
        ),
        const SizedBox(height: 12),
        _ThemeSwitchingDemo(),
        SizedBox(height: spacing.space32),

        // 9C: Component Theme Overrides
        _subsectionTitle(
          context,
          '9C. Component Theme Overrides — The Control Layer',
        ),
        _annotationBox(
          context,
          'ColorScheme sets the palette; component themes control how each component uses that palette.',
        ),
        const SizedBox(height: 12),
        _ComponentOverridesTable(),
        SizedBox(height: spacing.space32),

        // 9D: Semantic Bridge
        _subsectionTitle(
          context,
          '9D. The Semantic Bridge — From Structure to Meaning',
        ),
        _annotationBox(
          context,
          'M3\'s ColorScheme provides the achromatic structure. AppSemanticColors provides the chromatic meaning. Together, every colored pixel declares its purpose.',
        ),
        const SizedBox(height: 12),
        _SemanticBridgeDemo(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 9A: Role Map Demo
// ---------------------------------------------------------------------------

class _RoleMapDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FilledButton anatomy
        _ComponentAnatomyCard(
          title: 'FilledButton',
          annotations: ['primary \u2192 fill', 'onPrimary \u2192 label'],
          child: FilledButton(onPressed: () {}, child: const Text('Action')),
        ),
        const SizedBox(height: 12),
        // Card anatomy
        _ComponentAnatomyCard(
          title: 'Card (Outlined)',
          annotations: [
            'surfaceContainerLowest \u2192 fill',
            'outlineVariant \u2192 border',
            'onSurface \u2192 title',
            'onSurfaceVariant \u2192 subtitle',
          ],
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Title',
                    style: textTheme.titleSmall?.copyWith(color: cs.onSurface),
                  ),
                  Text(
                    'Subtitle',
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // FilterChip anatomy
        _ComponentAnatomyCard(
          title: 'FilterChip',
          annotations: [
            'Selected: secondaryContainer fill, onSecondaryContainer label',
            'Unselected: surfaceContainerLowest fill, outlineVariant border',
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilterChip(
                label: const Text('Selected'),
                selected: true,
                onSelected: (_) {},
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Unselected'),
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComponentAnatomyCard extends StatelessWidget {
  const _ComponentAnatomyCard({
    required this.title,
    required this.child,
    required this.annotations,
  });

  final String title;
  final Widget child;
  final List<String> annotations;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.labelLarge?.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          child,
          const SizedBox(height: 8),
          ...annotations.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '\u2192 $a',
                style: textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 9B: Theme Switching Demo
// ---------------------------------------------------------------------------

class _ThemeSwitchingDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Build a comparison theme using fromSeed
    final comparisonScheme = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: cs.brightness,
    );
    final comparisonTheme = Theme.of(context).copyWith(
      colorScheme: comparisonScheme,
      cardTheme: CardThemeData(
        color: comparisonScheme.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: comparisonScheme.outlineVariant),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "Color is Expensive" column
            Expanded(
              child: _ThemeColumn(
                label: '"Color is Expensive"',
                theme: Theme.of(context),
              ),
            ),
            const SizedBox(width: 8),
            // Standard M3 fromSeed column
            Expanded(
              child: _ThemeColumn(
                label: 'M3 fromSeed(deepPurple)',
                theme: comparisonTheme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _annotationBox(
          context,
          'Error stays red regardless of theme strategy — the semantic anchor is stable across configurations.',
        ),
      ],
    );
  }
}

class _ThemeColumn extends StatelessWidget {
  const _ThemeColumn({required this.label, required this.theme});

  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final outerColors = Theme.of(context).colorScheme;

    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;

          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: outerColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('Button'),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Outlined'),
                  ),
                ),
                const SizedBox(height: 6),
                FilterChip(
                  label: const Text('Chip'),
                  selected: true,
                  onSelected: (_) {},
                ),
                const SizedBox(height: 6),
                // Error — stable across both
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Error: stable red',
                    style: textTheme.labelSmall?.copyWith(
                      color: cs.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 9C: Component Overrides Table
// ---------------------------------------------------------------------------

class _ComponentOverridesTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final overrides = <(String, String, String)>[
      ('AppBar', 'surface bg, 0 elevation', 'scrolledUnderElevation: 0'),
      ('NavigationBar', 'White bg, transparent tint', 'surfaceContainerLowest'),
      ('Card', 'White + outlineVariant border', 'elevation: 0'),
      ('Dialog', 'White, 0 elevation', 'transparent tint'),
      ('BottomSheet', 'White, 0 elevation', 'transparent tint'),
      ('Divider', 'outlineVariant color', 'thickness: 1'),
      ('ListTile', 'Transparent, compact density', 'medium border radius'),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: cs.surfaceContainerHighest,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Component',
                    style: textTheme.labelSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'What It Controls',
                    style: textTheme.labelSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Key Override',
                    style: textTheme.labelSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...overrides.map((o) {
            final (component, controls, override) = o;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      component,
                      style: textTheme.labelSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      controls,
                      style: textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      override,
                      style: textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 9D: Semantic Bridge Demo
// ---------------------------------------------------------------------------

class _SemanticBridgeDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pure structural
        _SemanticBridgeCard(
          label: 'Pure Structural',
          badgeColor: cs.surfaceContainerHighest,
          badgeTextColor: cs.onSurface,
          badgeLabel: 'CATEGORY',
        ),
        SizedBox(height: spacing.space8),
        // Technical
        _SemanticBridgeCard(
          label: 'Technical',
          badgeColor: semantic.technical.colorContainer,
          badgeTextColor: semantic.technical.onColorContainer,
          badgeLabel: 'TECHNICAL',
        ),
        SizedBox(height: spacing.space8),
        // Flash
        _SemanticBridgeCard(
          label: 'Flash',
          badgeColor: semantic.flash.colorContainer,
          badgeTextColor: semantic.flash.onColorContainer,
          badgeLabel: 'FLASH',
        ),
        SizedBox(height: spacing.space8),
        // Community
        _SemanticBridgeCard(
          label: 'Community',
          badgeColor: semantic.community.colorContainer,
          badgeTextColor: semantic.community.onColorContainer,
          badgeLabel: 'COMMUNITY',
        ),
        SizedBox(height: spacing.space16),

        // Code path annotation
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Code path:',
                style: textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Theme.of(context)\n  .extension<AppSemanticColors>()!\n  .technical.colorContainer',
                style: textTheme.bodySmall?.copyWith(
                  color: cs.onSurface,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Chromatic color requires an explicit, semantic API call. You don\'t get color by accident.',
                style: textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SemanticBridgeCard extends StatelessWidget {
  const _SemanticBridgeCard({
    required this.label,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.badgeLabel,
  });

  final String label;
  final Color badgeColor;
  final Color badgeTextColor;
  final String badgeLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeLabel,
              style: textTheme.labelSmall?.copyWith(
                color: badgeTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Challenge Title',
                  style: textTheme.titleSmall?.copyWith(color: cs.onSurface),
                ),
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
