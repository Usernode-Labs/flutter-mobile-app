import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

// ---------------------------------------------------------------------------
// Leading slot options
// ---------------------------------------------------------------------------

enum _LeadingOption { none, iconContainer, rankBadge }

enum _TrailingOption { none, textOnly, textAndChevron }

// ---------------------------------------------------------------------------
// File-private helpers — inlined slot constructions until real slot widgets
// (IconTileLeading, RankBadge, TextChevronTrailing) are built just-in-time.
// ---------------------------------------------------------------------------

Widget _buildIconContainer(ColorScheme cs, IconData icon) {
  return Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: cs.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, size: 24, color: cs.onSecondaryContainer),
  );
}

Widget _buildRankBadge(ColorScheme cs, int rank) {
  return Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: cs.outlineVariant),
    ),
    child: Center(
      child: Text(
        '#$rank',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
    ),
  );
}

Widget _buildTextAndChevron(ColorScheme cs, String text) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(text),
      const SizedBox(width: 4),
      Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
    ],
  );
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

WidgetbookComponent listTileComponent() {
  return WidgetbookComponent(
    name: 'ListTile',
    useCases: [
      _playground(),
      _patterns(),
    ],
  );
}

// ---------------------------------------------------------------------------
// Use case 1 — Playground
// ---------------------------------------------------------------------------

WidgetbookUseCase _playground() {
  return WidgetbookUseCase(
    name: 'Playground',
    builder: (context) {
      final cs = Theme.of(context).colorScheme;

      final title = context.knobs.string(
        label: 'Title',
        initialValue: 'Checked Slots',
      );

      final subtitle = context.knobs.stringOrNull(
        label: 'Subtitle',
        initialValue: 'Evaluated 240 of 240',
      );

      final leading = context.knobs.object.dropdown<_LeadingOption>(
        label: 'Leading',
        options: _LeadingOption.values,
        initialOption: _LeadingOption.iconContainer,
        labelBuilder: (o) => o.name,
      );

      final trailing = context.knobs.object.dropdown<_TrailingOption>(
        label: 'Trailing',
        options: _TrailingOption.values,
        initialOption: _TrailingOption.textAndChevron,
        labelBuilder: (o) => o.name,
      );

      final trailingText = context.knobs.string(
        label: 'Trailing text',
        initialValue: '100%',
      );

      final tappable = context.knobs.boolean(
        label: 'Tappable',
        initialValue: true,
      );

      Widget? leadingWidget;
      switch (leading) {
        case _LeadingOption.iconContainer:
          leadingWidget = _buildIconContainer(cs, Icons.check_circle_outline);
        case _LeadingOption.rankBadge:
          leadingWidget = _buildRankBadge(cs, 1);
        case _LeadingOption.none:
          leadingWidget = null;
      }

      Widget? trailingWidget;
      switch (trailing) {
        case _TrailingOption.textOnly:
          trailingWidget = Text(trailingText);
        case _TrailingOption.textAndChevron:
          trailingWidget = _buildTextAndChevron(cs, trailingText);
        case _TrailingOption.none:
          trailingWidget = null;
      }

      return Padding(
        padding: const EdgeInsets.all(16),
        child: ListTile(
          leading: leadingWidget,
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle) : null,
          trailing: trailingWidget,
          onTap: tappable ? () {} : null,
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Use case 2 — Patterns
// ---------------------------------------------------------------------------

WidgetbookUseCase _patterns() {
  return WidgetbookUseCase(
    name: 'Patterns',
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Pattern A: Stats Summary ----
            Text('STATS SUMMARY', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _statsTile(
                    cs: cs,
                    icon: Icons.check_circle_outline,
                    title: 'Checked Slots',
                    subtitle: 'Evaluated 240 of 240',
                    trailing: '100%',
                  ),
                  _statsTile(
                    cs: cs,
                    icon: Icons.view_in_ar,
                    title: 'Produced Blocks',
                    subtitle: '16 of 21 won slots',
                    trailing: '1',
                  ),
                  _statsTile(
                    cs: cs,
                    icon: Icons.block,
                    title: 'Missed Blocks',
                    subtitle: '0 of 21 won slots missed',
                    trailing: '5',
                  ),
                  _statsTile(
                    cs: cs,
                    icon: Icons.schedule,
                    title: 'Upcoming Blocks',
                    subtitle: '3 upcoming this epoch',
                    trailing: '5',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ---- Pattern B: Ranking ----
            Text('RANKING', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _rankTile(cs: cs, rank: 1, name: 'namaah', points: '10,000'),
                  _rankTile(cs: cs, rank: 2, name: 'madmax', points: '8,500'),
                  _rankTile(
                      cs: cs, rank: 3, name: 'boscrypto', points: '7,200'),
                  _rankTile(
                      cs: cs, rank: 4, name: 'discordhandle', points: '6,100'),
                  _rankTile(
                      cs: cs, rank: 5, name: 'validator99', points: '5,000'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ---- Pattern C: Simple 2-Line ----
            Text('SIMPLE 2-LINE', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _simpleTile(
                    cs: cs,
                    title: '2132132',
                    subtitle: '22 Oct 04:30:12',
                    trailing: 'Produced',
                  ),
                  _simpleTile(
                    cs: cs,
                    title: '2132131',
                    subtitle: '22 Oct 04:29:58',
                    trailing: 'Produced',
                  ),
                  _simpleTile(
                    cs: cs,
                    title: '2132130',
                    subtitle: '22 Oct 04:29:44',
                    trailing: 'Missed',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Pattern tile builders
// ---------------------------------------------------------------------------

Widget _statsTile({
  required ColorScheme cs,
  required IconData icon,
  required String title,
  required String subtitle,
  required String trailing,
}) {
  return ListTile(
    leading: _buildIconContainer(cs, icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: _buildTextAndChevron(cs, trailing),
    onTap: () {},
  );
}

Widget _rankTile({
  required ColorScheme cs,
  required int rank,
  required String name,
  required String points,
}) {
  return ListTile(
    leading: _buildRankBadge(cs, rank),
    title: Text(name),
    trailing: Text('$points pts'),
    onTap: () {},
  );
}

Widget _simpleTile({
  required ColorScheme cs,
  required String title,
  required String subtitle,
  required String trailing,
}) {
  return ListTile(
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: _buildTextAndChevron(cs, trailing),
    onTap: () {},
  );
}
