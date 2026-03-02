import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_spacing.dart';
import 'dropdown_chip.dart';

/// A single filter in the chain.
class DropdownChainItem {
  const DropdownChainItem({
    required this.label,
    this.onTap,
    this.variant,
    this.borderColor,
    @Deprecated('Use variant instead. '
        'selected=true maps to ChipVariant.surface, '
        'selected=false maps to ChipVariant.outlined.')
    this.selected,
  });

  /// The chip label text, e.g. "Season 2" or "DApps Integration".
  final String label;

  /// Called when the chip is tapped.
  final VoidCallback? onTap;

  /// Visual variant for this chip. When null, uses the chain's default.
  final ChipVariant? variant;

  /// Optional border color passed through to [DropdownChip].
  final Color? borderColor;

  /// Legacy parameter — use [variant] instead.
  final bool? selected;
}

/// A horizontal row of [DropdownChip]s separated by chevron icons.
///
/// The last chip expands to fill remaining width; all preceding chips
/// shrink-wrap. Chevron-forward icons indicate hierarchical narrowing
/// (e.g. Season > Category).
///
/// Composes [DropdownChip] — presentation-only, all state via constructor.
class DropdownChain extends StatelessWidget {
  const DropdownChain({
    super.key,
    required this.items,
    this.variant = ChipVariant.surface,
    this.size = ChipSize.regular,
  }) : assert(items.length > 0);

  /// The ordered list of filters. Must contain at least one item.
  final List<DropdownChainItem> items;

  /// Default variant for all chips in the chain.
  final ChipVariant variant;

  /// Size for all chips in the chain.
  final ChipSize size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    final children = <Widget>[];

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isLast = i == items.length - 1;

      // Resolve variant: item.selected (legacy) > item.variant > chain default
      ChipVariant? chipVariant = item.variant ?? variant;
      // ignore: deprecated_member_use_from_same_package
      final legacySelected = item.selected;

      if (isLast) {
        children.add(
          Expanded(
            child: DropdownChip(
              label: item.label,
              onTap: item.onTap,
              expanded: true,
              variant: chipVariant,
              size: size,
              // ignore: deprecated_member_use_from_same_package
              selected: legacySelected,
              borderColor: item.borderColor,
            ),
          ),
        );
      } else {
        children.add(
          DropdownChip(
            label: item.label,
            onTap: item.onTap,
            variant: chipVariant,
            size: size,
            // ignore: deprecated_member_use_from_same_package
            selected: legacySelected,
            borderColor: item.borderColor,
          ),
        );
        children.add(SizedBox(width: spacing.space8));
        children.add(
          Icon(
            Symbols.chevron_right_sharp,
            size: 24,
            color: colors.onSurfaceVariant,
          ),
        );
        children.add(SizedBox(width: spacing.space8));
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }
}
