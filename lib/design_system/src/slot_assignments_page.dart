import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_semantic_colors.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';
import 'icon_badge.dart';

/// Status of a single slot assignment.
enum SlotStatus { produced, orphaned, missed, upcoming, notCalculated, notWon }

/// Data for a single slot assignment list item.
class SlotAssignmentItemData {
  final int slot;
  final SlotStatus status;

  /// Pre-formatted time label, e.g. "Today, 08:21" or "Mar 14, 08:21".
  final String? timeLabel;

  /// Whether the item can be tapped (typically produced/orphaned).
  final bool isTappable;

  const SlotAssignmentItemData({
    required this.slot,
    required this.status,
    this.timeLabel,
    this.isTappable = false,
  });
}

/// Data for a single filter chip in the filter row.
class SlotFilterData {
  final String label;
  final int count;
  final bool selected;

  const SlotFilterData({
    required this.label,
    required this.count,
    this.selected = false,
  });
}

/// A full-page slot assignments view with epoch progress header, filter chips,
/// and a scrollable list of slot items.
///
/// Presentation-only: all data comes through constructor parameters.
/// The feature screen in `lib/features/` wires state to this widget.
class SlotAssignmentsPage extends StatelessWidget {
  const SlotAssignmentsPage({
    super.key,
    required this.title,
    required this.epochLabel,
    required this.slotProgressLeftLabel,
    required this.slotProgress,
    required this.filters,
    required this.onFilterTap,
    required this.items,
    this.slotProgressRightLabel,
    this.onItemTap,
    this.onBackTap,
  });

  /// AppBar title, e.g. "Slot Assignments".
  final String title;

  /// Epoch label shown above the progress bar, e.g. "Epoch 176".
  final String epochLabel;

  /// Left label under the progress bar, e.g. "5000 / 7140 slots".
  final String slotProgressLeftLabel;

  /// Optional right label under the progress bar, e.g. "7h 14min left".
  final String? slotProgressRightLabel;

  /// Progress fraction (0.0–1.0) for the slot progress bar.
  final double slotProgress;

  /// Filter chips shown in the horizontal scroll row.
  final List<SlotFilterData> filters;

  /// Called with the index of the tapped filter chip.
  final ValueChanged<int> onFilterTap;

  /// Slot assignment items, pre-filtered by the caller.
  final List<SlotAssignmentItemData> items;

  /// Called with the index of the tapped item.
  final ValueChanged<int>? onItemTap;

  /// Called when the back button is tapped.
  final VoidCallback? onBackTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return Scaffold(
      appBar: AppBar(
        leading: onBackTap != null
            ? IconButton(
                icon: const Icon(Symbols.arrow_back_sharp),
                onPressed: onBackTap,
              )
            : null,
        title: Text(title),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: spacing.space16),
          // Inline progress — epoch label + bar + left/right labels
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(epochLabel, style: theme.textTheme.titleMedium),
                SizedBox(height: spacing.space8),
                LinearProgressIndicator(value: slotProgress),
                SizedBox(height: spacing.space4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        slotProgressLeftLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (slotProgressRightLabel != null)
                      Text(
                        slotProgressRightLabel!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: spacing.space12),
          // Filter row
          _FilterRow(
            filters: filters,
            onFilterTap: onFilterTap,
          ),
          SizedBox(height: spacing.space8),
          // Item list
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildItemTile(context, item, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(
    BuildContext context,
    SlotAssignmentItemData item,
    int index,
  ) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    final badgeColors = _statusBadgeColors(item.status, colors, semantic);

    final trailingText = Text(
      _statusLabel(item.status),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
    );

    final trailing = item.isTappable
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              trailingText,
              SizedBox(width: spacing.space4),
              Icon(
                Symbols.chevron_right_sharp,
                size: sizing.iconSmall,
                color: colors.onSurfaceVariant,
              ),
            ],
          )
        : trailingText;

    return ListTile(
      leading: IconBadge(
        icon: _statusIcon(item.status),
        size: sizing.iconContainerSmall,
        backgroundColor: badgeColors?.$1,
        iconColor: badgeColors?.$2,
      ),
      title: Text('Slot ${item.slot}'),
      subtitle: item.timeLabel != null ? Text(item.timeLabel!) : null,
      trailing: trailing,
      onTap: item.isTappable ? () => onItemTap?.call(index) : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filters,
    required this.onFilterTap,
  });

  final List<SlotFilterData> filters;
  final ValueChanged<int> onFilterTap;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final labelSmall = Theme.of(context).textTheme.labelSmall!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: spacing.space16),
      child: Row(
        spacing: spacing.space8,
        children: [
          for (int i = 0; i < filters.length; i++)
            FilterChip(
              avatar: CircleAvatar(
                backgroundColor: colorScheme.onSurfaceVariant,
                child: Text(
                  '${filters[i].count}',
                  style: labelSmall.copyWith(color: colorScheme.surface),
                ),
              ),
              showCheckmark: false,
              label: Text(filters[i].label),
              selected: filters[i].selected,
              onSelected: (_) => onFilterTap(i),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status mapping helpers
// ---------------------------------------------------------------------------

IconData _statusIcon(SlotStatus status) => switch (status) {
      SlotStatus.produced => Symbols.check_circle_sharp,
      SlotStatus.orphaned => Symbols.error_sharp,
      SlotStatus.missed => Symbols.cancel_sharp,
      SlotStatus.upcoming => Symbols.schedule_sharp,
      SlotStatus.notCalculated => Symbols.help_sharp,
      SlotStatus.notWon => Symbols.remove_circle_sharp,
    };

/// Returns `(backgroundColor, iconColor)` for the leading [IconBadge].
/// `null` → use IconBadge defaults (achromatic secondaryContainer).
(Color, Color)? _statusBadgeColors(
  SlotStatus status,
  ColorScheme colors,
  AppSemanticColors semantic,
) =>
    switch (status) {
      SlotStatus.missed => (colors.errorContainer, colors.onErrorContainer),
      SlotStatus.upcoming => (
          semantic.technical.colorContainer,
          semantic.technical.onColorContainer,
        ),
      _ => null,
    };

String _statusLabel(SlotStatus status) => switch (status) {
      SlotStatus.produced => 'Produced',
      SlotStatus.orphaned => 'Orphaned',
      SlotStatus.missed => 'Missed',
      SlotStatus.upcoming => 'Upcoming',
      SlotStatus.notCalculated => 'Not Calculated',
      SlotStatus.notWon => 'Not Won',
    };
