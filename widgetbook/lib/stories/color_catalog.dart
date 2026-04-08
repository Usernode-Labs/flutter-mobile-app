import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';

// ---------------------------------------------------------------------------
// Section extraction helper
// ---------------------------------------------------------------------------

String extractSection(String markdown, String startMarker, String endMarker) {
  final startIndex = markdown.indexOf(startMarker);
  if (startIndex == -1) return '';
  final contentStart = startIndex + startMarker.length;
  final endIndex = markdown.indexOf(endMarker, contentStart);
  if (endIndex == -1) return markdown.substring(contentStart);
  return markdown.substring(contentStart, endIndex).trim();
}

// ---------------------------------------------------------------------------
// 1. Core Roles catalog
// ---------------------------------------------------------------------------

class CoreRolesCatalog extends StatelessWidget {
  const CoreRolesCatalog({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'Primary'),
          _colorRow(context, [
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
          const SizedBox(height: 24),
          _sectionTitle(context, 'Secondary'),
          _colorRow(context, [
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
          const SizedBox(height: 24),
          _sectionTitle(context, 'Tertiary'),
          _colorRow(context, [
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
          const SizedBox(height: 24),
          _sectionTitle(context, 'Error'),
          _colorRow(context, [
            _SwatchData('error', cs.error, cs.onError),
            _SwatchData('onError', cs.onError, cs.error),
            _SwatchData(
              'errorContainer',
              cs.errorContainer,
              cs.onErrorContainer,
            ),
            _SwatchData(
              'onErrorContainer',
              cs.onErrorContainer,
              cs.errorContainer,
            ),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Surface & Neutral catalog
// ---------------------------------------------------------------------------

class SurfaceNeutralCatalog extends StatelessWidget {
  const SurfaceNeutralCatalog({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'Surface Hierarchy'),
          _colorRow(context, [
            _SwatchData('surface', cs.surface, cs.onSurface),
            _SwatchData('surfaceDim', cs.surfaceDim, cs.onSurface),
            _SwatchData('surfaceBright', cs.surfaceBright, cs.onSurface),
          ]),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Surface Containers'),
          _colorRow(context, [
            _SwatchData(
              'containerLowest',
              cs.surfaceContainerLowest,
              cs.onSurface,
            ),
            _SwatchData('containerLow', cs.surfaceContainerLow, cs.onSurface),
            _SwatchData('container', cs.surfaceContainer, cs.onSurface),
          ]),
          const SizedBox(height: 12),
          _colorRow(context, [
            _SwatchData('containerHigh', cs.surfaceContainerHigh, cs.onSurface),
            _SwatchData(
              'containerHighest',
              cs.surfaceContainerHighest,
              cs.onSurface,
            ),
          ]),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Outline & Text'),
          _colorRow(context, [
            _SwatchData('outline', cs.outline, cs.surface),
            _SwatchData('outlineVariant', cs.outlineVariant, cs.surface),
            _SwatchData('onSurface', cs.onSurface, cs.surface),
            _SwatchData('onSurfaceVariant', cs.onSurfaceVariant, cs.surface),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Semantic Colors catalog
// ---------------------------------------------------------------------------

class SemanticColorsCatalog extends StatelessWidget {
  const SemanticColorsCatalog({super.key});

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    if (semantic == null) {
      return const Center(
        child: Text('AppSemanticColors not found in theme extensions.'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _semanticGroup(context, 'Technical', semantic.technical),
          const SizedBox(height: 24),
          _semanticGroup(context, 'Flash', semantic.flash),
          const SizedBox(height: 24),
          _semanticGroup(context, 'Community', semantic.community),
          const SizedBox(height: 24),
          _semanticGroup(context, 'Success', semantic.success),
        ],
      ),
    );
  }

  Widget _semanticGroup(
    BuildContext context,
    String name,
    SemanticColorGroup group,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, name),
        _colorRow(context, [
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
        const SizedBox(height: 8),
        _colorRow(context, [
          _SwatchData('colorSurface', group.colorSurface, group.onColorSurface),
          _SwatchData(
            'onColorSurface',
            group.onColorSurface,
            group.colorSurface,
          ),
        ]),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Guidelines catalog (renders DESIGN_SYSTEM.md sections)
// ---------------------------------------------------------------------------

class GuidelinesCatalog extends StatefulWidget {
  const GuidelinesCatalog({super.key});

  @override
  State<GuidelinesCatalog> createState() => _GuidelinesCatalogState();
}

class _GuidelinesCatalogState extends State<GuidelinesCatalog> {
  String _markdown = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMarkdown();
  }

  Future<void> _loadMarkdown() async {
    try {
      final raw = await rootBundle.loadString(
        'lib/design_system/DESIGN_SYSTEM.md',
      );
      final philosophy = extractSection(
        raw,
        '<!-- COLOR_PHILOSOPHY_START -->',
        '<!-- COLOR_PHILOSOPHY_END -->',
      );
      final dosDonts = extractSection(
        raw,
        '<!-- COLOR_DOS_DONTS_START -->',
        '<!-- COLOR_DOS_DONTS_END -->',
      );
      setState(() {
        _markdown = '$philosophy\n\n$dosDonts';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _markdown = 'Failed to load DESIGN_SYSTEM.md: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: MarkdownBody(
        data: _markdown,
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          h2: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          h3: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          p: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          tableHead: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
          tableBody: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          strong: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
          code: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.secondary,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers (private to this file)
// ---------------------------------------------------------------------------

class _SwatchData {
  const _SwatchData(this.label, this.color, this.contrastColor);
  final String label;
  final Color color;
  final Color contrastColor;
}

Widget _sectionTitle(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}

Widget _colorRow(BuildContext context, List<_SwatchData> swatches) {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: swatches.map((s) => _colorSwatch(context, s)).toList(),
  );
}

Widget _colorSwatch(BuildContext context, _SwatchData swatch) {
  final hex =
      '#${swatch.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  return Container(
    width: 140,
    height: 80,
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
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(hex, style: TextStyle(color: swatch.contrastColor, fontSize: 10)),
      ],
    ),
  );
}
