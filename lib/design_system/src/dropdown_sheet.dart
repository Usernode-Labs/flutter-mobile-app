import 'package:flutter/material.dart';

import '../tokens/app_spacing.dart';

/// Shows a modal bottom sheet with selectable options.
///
/// Returns the index of the selected option, or `null` if dismissed
/// (tap barrier or drag down).
///
/// Wraps M3 [showModalBottomSheet] for native drag-to-dismiss, barrier tap,
/// and accessibility. Visual appearance is controlled by `bottomSheetTheme`
/// in [ColorIsExpensiveTheme].
Future<int?> showDropdownSheet({
  required BuildContext context,
  required List<String> labels,
  String? title,
  int? selectedIndex,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.6,
    ),
    builder: (context) => _DropdownSheetBody(
      labels: labels,
      title: title,
      selectedIndex: selectedIndex,
    ),
  );
}

class _DropdownSheetBody extends StatelessWidget {
  const _DropdownSheetBody({
    required this.labels,
    this.title,
    this.selectedIndex,
  });

  final List<String> labels;
  final String? title;
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title row
        if (title != null)
          Padding(
            padding: EdgeInsets.only(
              left: spacing.space16,
              right: spacing.space8,
              bottom: spacing.space8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    size: 24,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

        // Option list
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.only(bottom: bottomPadding),
            itemCount: labels.length,
            itemBuilder: (context, index) {
              final isSelected = index == selectedIndex;
              return _OptionRow(
                label: labels[index],
                selected: isSelected,
                onTap: () => Navigator.of(context).pop(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: spacing.space16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyLarge?.copyWith(
                  color: colors.onSurface,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check, size: 24, color: colors.primary)
            else
              const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }
}
