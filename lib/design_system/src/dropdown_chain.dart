import 'package:flutter/material.dart';

import '../tokens/app_spacing.dart';
import 'dropdown_chip.dart';

/// A single filter in the chain.
class DropdownChainItem {
  const DropdownChainItem({
    required this.label,
    this.onTap,
  });

  /// The chip label text, e.g. "Season 2" or "DApps Integration".
  final String label;

  /// Called when the chip is tapped.
  final VoidCallback? onTap;
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
  }) : assert(items.length > 0);

  /// The ordered list of filters. Must contain at least one item.
  final List<DropdownChainItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    final children = <Widget>[];

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isLast = i == items.length - 1;

      if (isLast) {
        children.add(
          Expanded(
            child: DropdownChip(
              label: item.label,
              onTap: item.onTap,
              expanded: true,
            ),
          ),
        );
      } else {
        children.add(
          DropdownChip(
            label: item.label,
            onTap: item.onTap,
          ),
        );
        children.add(SizedBox(width: spacing.space8));
        children.add(
          Icon(
            Icons.chevron_right,
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
