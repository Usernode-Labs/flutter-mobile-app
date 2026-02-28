import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/icon_badge.dart';
import '../src/rank_badge.dart';
import '../src/status_badge.dart';

// ---------------------------------------------------------------------------
// Leading slot options
// ---------------------------------------------------------------------------

enum _LeadingOption { none, iconBadge, rankBadge }

enum _TrailingOption { none, textOnly, textAndChevron, statusBadge }

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
        initialOption: _LeadingOption.iconBadge,
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
        case _LeadingOption.iconBadge:
          leadingWidget = const IconBadge(icon: Icons.check_circle_outline);
        case _LeadingOption.rankBadge:
          leadingWidget = const RankBadge(rank: '#1');
        case _LeadingOption.none:
          leadingWidget = null;
      }

      Widget? trailingWidget;
      switch (trailing) {
        case _TrailingOption.textOnly:
          trailingWidget = Text(trailingText);
        case _TrailingOption.textAndChevron:
          trailingWidget = _TextChevron(text: trailingText);
        case _TrailingOption.statusBadge:
          trailingWidget = const StatusBadge(
            label: 'Active',
            variant: StatusBadgeVariant.success,
          );
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
      final textTheme = Theme.of(context).textTheme;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Pattern A: Stats / Metrics ----
            Text('STATS / METRICS', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const IconBadge(icon: Icons.check_circle_outline),
                    title: const Text('Checked Slots'),
                    subtitle: const Text('Evaluated 240 of 240'),
                    trailing: const _TextChevron(text: '100%'),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const IconBadge(icon: Icons.view_in_ar),
                    title: const Text('Produced Blocks'),
                    subtitle: const Text('16 of 21 won slots'),
                    trailing: const _TextChevron(text: '1'),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const IconBadge(icon: Icons.bolt),
                    title: const Text('Uptime'),
                    subtitle: const Text('Current epoch'),
                    trailing: const Text('99.7%'),
                    onTap: () {},
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
                  ListTile(
                    leading: const RankBadge(rank: '#1'),
                    title: const Text('namaah'),
                    trailing: const Text('10,000 pts'),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const RankBadge(rank: '#2'),
                    title: const Text('madmax'),
                    trailing: const Text('8,500 pts'),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const RankBadge(rank: '#3'),
                    title: const Text('boscrypto'),
                    trailing: const Text('7,200 pts'),
                    onTap: () {},
                  ),
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
                  ListTile(
                    title: const Text('2132132'),
                    subtitle: const Text('22 Oct 04:30:12'),
                    trailing: const StatusBadge(
                      label: 'Produced',
                      variant: StatusBadgeVariant.success,
                    ),
                    onTap: () {},
                  ),
                  ListTile(
                    title: const Text('2132131'),
                    subtitle: const Text('22 Oct 04:29:58'),
                    trailing: const StatusBadge(
                      label: 'Produced',
                      variant: StatusBadgeVariant.success,
                    ),
                    onTap: () {},
                  ),
                  ListTile(
                    title: const Text('2132130'),
                    subtitle: const Text('22 Oct 04:29:44'),
                    trailing: const StatusBadge(
                      label: 'Missed',
                      variant: StatusBadgeVariant.error,
                    ),
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ---- Pattern D: With Status Badges ----
            Text('WITH STATUS BADGES', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const IconBadge(icon: Icons.cloud_done_outlined),
                    title: const Text('Node Status'),
                    subtitle: const Text('Running since 3 days ago'),
                    trailing: const StatusBadge(
                      label: 'Online',
                      variant: StatusBadgeVariant.success,
                      icon: Icons.check_circle,
                    ),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const IconBadge(icon: Icons.sync),
                    title: const Text('Sync Status'),
                    subtitle: const Text('Block 1,234,567'),
                    trailing: const StatusBadge(
                      label: 'Syncing',
                      variant: StatusBadgeVariant.warning,
                      icon: Icons.sync,
                    ),
                    onTap: () {},
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
// Shared helper
// ---------------------------------------------------------------------------

class _TextChevron extends StatelessWidget {
  const _TextChevron({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
      ],
    );
  }
}
