import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_semantic_colors.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_radii.dart';
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
class SlotAssignmentsPage extends StatefulWidget {
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
    this.highlightIndex,
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

  /// Index of the item to highlight with a heartbeat pulse animation.
  final int? highlightIndex;

  @override
  State<SlotAssignmentsPage> createState() => _SlotAssignmentsPageState();
}

class _SlotAssignmentsPageState extends State<SlotAssignmentsPage> {
  int? _activeHighlightIndex;

  @override
  void initState() {
    super.initState();
    _activeHighlightIndex = widget.highlightIndex;
  }

  @override
  void didUpdateWidget(SlotAssignmentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightIndex != oldWidget.highlightIndex) {
      _activeHighlightIndex = widget.highlightIndex;
    }
  }

  void _onHighlightComplete() {
    setState(() => _activeHighlightIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBackTap != null
            ? IconButton(
                icon: const Icon(Symbols.arrow_back_sharp),
                onPressed: widget.onBackTap,
              )
            : null,
        title: Text(widget.title),
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
                Text(widget.epochLabel, style: theme.textTheme.titleMedium),
                SizedBox(height: spacing.space8),
                LinearProgressIndicator(value: widget.slotProgress),
                SizedBox(height: spacing.space4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.slotProgressLeftLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (widget.slotProgressRightLabel != null)
                      Text(
                        widget.slotProgressRightLabel!,
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
            filters: widget.filters,
            onFilterTap: widget.onFilterTap,
          ),
          SizedBox(height: spacing.space8),
          // Item list
          Expanded(
            child: ListView.builder(
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
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

    Widget tile = ListTile(
      leading: IconBadge(
        icon: _statusIcon(item.status),
        size: sizing.iconContainerSmall,
        backgroundColor: badgeColors?.$1,
        iconColor: badgeColors?.$2,
      ),
      title: Text('Slot ${item.slot}'),
      subtitle: item.timeLabel != null ? Text(item.timeLabel!) : null,
      trailing: trailing,
      onTap: item.isTappable ? () => widget.onItemTap?.call(index) : null,
    );

    if (index == _activeHighlightIndex) {
      tile = _HeartbeatHighlight(
        onComplete: _onHighlightComplete,
        child: tile,
      );
    }

    return tile;
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

class _HeartbeatHighlight extends StatefulWidget {
  const _HeartbeatHighlight({
    required this.onComplete,
    required this.child,
  });

  final VoidCallback onComplete;
  final Widget child;

  @override
  State<_HeartbeatHighlight> createState() => _HeartbeatHighlightState();
}

class _HeartbeatHighlightState extends State<_HeartbeatHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete();
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_completed) return;
    if (MediaQuery.of(context).disableAnimations) {
      _completed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onComplete();
      });
    } else if (!_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_completed) return widget.child;

    final highlightColor = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withAlpha((255 * 0.35).round());

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 3 smooth sin pulses over the animation duration
        final pulse = math.sin(_controller.value * math.pi * 3).clamp(0.0, 1.0);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(
              Colors.transparent,
              highlightColor,
              pulse,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

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
    final radii = Theme.of(context).extension<AppRadii>()!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: spacing.space16),
      child: Row(
        spacing: spacing.space8,
        children: [
          for (int i = 0; i < filters.length; i++)
            FilterChip(
              showCheckmark: false,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: spacing.space8,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.space8,
                      vertical: spacing.space4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant,
                      borderRadius: radii.borderRadiusFull,
                    ),
                    child: Text(
                      '${filters[i].count}',
                      style: labelSmall.copyWith(color: colorScheme.surface),
                    ),
                  ),
                  Text(filters[i].label),
                ],
              ),
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
      SlotStatus.orphaned => (colors.errorContainer, colors.onErrorContainer),
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
