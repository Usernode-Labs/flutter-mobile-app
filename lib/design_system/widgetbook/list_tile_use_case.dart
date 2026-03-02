import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/icon_badge.dart';
import '../src/rank_badge.dart';
import '../src/status_badge.dart';
import '../src/text_chevron_trailing.dart';

// ---------------------------------------------------------------------------
// Knob options (aligned with 07_list_system_guidance.md §1)
// ---------------------------------------------------------------------------

enum _LeadingOption { none, iconBadge, rankBadge, inlineIcon }

enum _TrailingOption {
  none,
  value,
  chevron,
  icon,
  action,
  statusBadge,
  valueAndChevron,
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

WidgetbookComponent listTileComponent() {
  return WidgetbookComponent(
    name: 'ListTile',
    useCases: [
      _playground(),
      _leadingSlots(),
      _trailingSlots(),
      _sectionGrouping(),
      _specializedVariants(),
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
        initialOption: _TrailingOption.valueAndChevron,
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
        case _LeadingOption.inlineIcon:
          leadingWidget = const Icon(Icons.history);
        case _LeadingOption.none:
          leadingWidget = null;
      }

      Widget? trailingWidget;
      switch (trailing) {
        case _TrailingOption.value:
          trailingWidget = Text(trailingText);
        case _TrailingOption.chevron:
          trailingWidget = const Icon(Icons.chevron_right, size: 20);
        case _TrailingOption.icon:
          trailingWidget = const Icon(Icons.open_in_new, size: 20);
        case _TrailingOption.action:
          trailingWidget = IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          );
        case _TrailingOption.statusBadge:
          trailingWidget = const StatusBadge(
            label: 'Active',
            variant: StatusBadgeVariant.success,
          );
        case _TrailingOption.valueAndChevron:
          trailingWidget = TextChevronTrailing(text: trailingText);
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
// Use case 2 — Leading Slots (guidance §1 Leading Slot table)
// ---------------------------------------------------------------------------

WidgetbookUseCase _leadingSlots() {
  return WidgetbookUseCase(
    name: 'Leading Slots',
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ICON CONTAINER — IconBadge (48 px)',
                style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const IconBadge(icon: Icons.check_circle_outline),
                    title: const Text('Checked Slots'),
                    subtitle: const Text('Evaluated 240 of 240'),
                    trailing: const TextChevronTrailing(text: '100%'),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const IconBadge(icon: Icons.hub_outlined),
                    title: const Text('Network Peers'),
                    subtitle: const Text('12 connected'),
                    trailing: const Text('Online'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('RANK CIRCLE — RankBadge (40 px)',
                style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: RankBadge(rank: '#1'),
                    title: Text('namaah'),
                    trailing: Text('10,000 pts'),
                  ),
                  const ListTile(
                    leading: RankBadge(rank: '#2'),
                    title: Text('madmax'),
                    trailing: Text('8,500 pts'),
                  ),
                  const ListTile(
                    leading: RankBadge(rank: '#3'),
                    title: Text('boscrypto'),
                    trailing: Text('7,200 pts'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('INLINE ICON — Icon (24 px)', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('B62qk...x9fR'),
                    subtitle: const Text('Last used 2 days ago'),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.qr_code),
                    title: const Text('Scan QR Code'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('EMPTY — no leading', style: textTheme.labelLarge),
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
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Use case 3 — Trailing Slots (guidance §1 Trailing Slot table)
// ---------------------------------------------------------------------------

WidgetbookUseCase _trailingSlots() {
  return WidgetbookUseCase(
    name: 'Trailing Slots',
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
      final cs = Theme.of(context).colorScheme;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VALUE', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: RankBadge(rank: '#1'),
                    title: Text('namaah'),
                    trailing: Text('10,000 pts'),
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
            Text('CHEVRON', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const IconBadge(icon: Icons.settings),
                    title: const Text('Advanced Settings'),
                    trailing: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('VALUE + CHEVRON — TextChevronTrailing',
                style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const IconBadge(icon: Icons.check_circle_outline),
                    title: const Text('Checked Slots'),
                    subtitle: const Text('Evaluated 240 of 240'),
                    trailing: const TextChevronTrailing(text: '100%'),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const IconBadge(icon: Icons.view_in_ar),
                    title: const Text('Produced Blocks'),
                    subtitle: const Text('16 of 21 won slots'),
                    trailing: const TextChevronTrailing(text: '1'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('BADGE — StatusBadge', style: textTheme.labelLarge),
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
            const SizedBox(height: 24),
            Text('ACTION — IconButton', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const IconBadge(icon: Icons.person),
                    title: const Text('Peer 192.168.1.1'),
                    subtitle: const Text('Connected 5 min ago'),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('EMPTY — no trailing', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.qr_code),
                    title: const Text('Scan QR Code'),
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
// Use case 4 — Section Grouping (guidance §2)
// ---------------------------------------------------------------------------

WidgetbookUseCase _sectionGrouping() {
  return WidgetbookUseCase(
    name: 'Section Grouping',
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1 — normal header
            Text('PERFORMANCE', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const IconBadge(icon: Icons.check_circle_outline),
                    title: const Text('Checked Slots'),
                    subtitle: const Text('Evaluated 240 of 240'),
                    trailing: const TextChevronTrailing(text: '100%'),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const IconBadge(icon: Icons.view_in_ar),
                    title: const Text('Produced Blocks'),
                    subtitle: const Text('16 of 21 won slots'),
                    trailing: const TextChevronTrailing(text: '1'),
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

            // Section 2 — normal header
            Text('RECENT SLOTS', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Slot #2132132'),
                    subtitle: const Text('22 Oct 04:30:12'),
                    trailing: const StatusBadge(
                      label: 'Produced',
                      variant: StatusBadgeVariant.success,
                    ),
                    onTap: () {},
                  ),
                  ListTile(
                    title: const Text('Slot #2132130'),
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

            // Section 3 — ranking
            Text('LEADERBOARD', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: RankBadge(rank: '#1'),
                    title: Text('namaah'),
                    trailing: Text('10,000 pts'),
                  ),
                  const ListTile(
                    leading: RankBadge(rank: '#2'),
                    title: Text('madmax'),
                    trailing: Text('8,500 pts'),
                  ),
                  const ListTile(
                    leading: RankBadge(rank: '#3'),
                    title: Text('boscrypto'),
                    trailing: Text('7,200 pts'),
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
// Use case 5 — Specialized Variants (guidance §2)
// ---------------------------------------------------------------------------

WidgetbookUseCase _specializedVariants() {
  return WidgetbookUseCase(
    name: 'Specialized Variants',
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SWITCH — SwitchListTile', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: true,
                    onChanged: (_) {},
                    title: const Text('Background Production'),
                    subtitle:
                        const Text('Keep producing while app is in background'),
                  ),
                  SwitchListTile(
                    value: false,
                    onChanged: (_) {},
                    title: const Text('Notifications'),
                    subtitle: const Text('Get notified about slot assignments'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('EXPANDABLE — ExpansionTile', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ExpansionTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Epoch 42'),
                    subtitle: const Text('3 slots'),
                    children: [
                      ListTile(
                        title: const Text('Slot #1284'),
                        trailing: const StatusBadge(
                          label: 'Produced',
                          variant: StatusBadgeVariant.success,
                        ),
                        onTap: () {},
                      ),
                      ListTile(
                        title: const Text('Slot #1290'),
                        trailing: const StatusBadge(
                          label: 'Missed',
                          variant: StatusBadgeVariant.error,
                        ),
                        onTap: () {},
                      ),
                      ListTile(
                        title: const Text('Slot #1305'),
                        trailing: const StatusBadge(
                          label: 'Upcoming',
                          variant: StatusBadgeVariant.info,
                        ),
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('DISABLED STATE', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: IconBadge(icon: Icons.lock_outline),
                    title: Text('Locked Feature'),
                    subtitle: Text('Requires active node'),
                    enabled: false,
                  ),
                  SwitchListTile(
                    value: false,
                    onChanged: null,
                    title: const Text('Unavailable Toggle'),
                    subtitle: const Text('Node must be running'),
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
