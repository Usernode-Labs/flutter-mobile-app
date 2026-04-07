import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_sizing.dart';
import 'sheet_layout.dart';

/// Shows a modal bottom sheet with selectable options.
///
/// Returns the index of the selected option, or `null` if dismissed
/// (tap barrier or drag down).
///
/// [dividerAfterIndex] inserts a [Divider] after the option at that index.
///
/// Wraps M3 [showModalBottomSheet] for native drag-to-dismiss, barrier tap,
/// and accessibility. Visual appearance is controlled by `bottomSheetTheme`
/// in [ColorIsExpensiveTheme].
Future<int?> showDropdownSheet({
  required BuildContext context,
  required List<String> labels,
  String? title,
  int? selectedIndex,
  int? dividerAfterIndex,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.65,
    ),
    builder: (context) => _DropdownSheetBody(
      labels: labels,
      title: title,
      selectedIndex: selectedIndex,
      dividerAfterIndex: dividerAfterIndex,
    ),
  );
}

class _DropdownSheetBody extends StatelessWidget {
  const _DropdownSheetBody({
    required this.labels,
    this.title,
    this.selectedIndex,
    this.dividerAfterIndex,
  });

  final List<String> labels;
  final String? title;
  final int? selectedIndex;
  final int? dividerAfterIndex;

  @override
  Widget build(BuildContext context) {
    final dividerSlot = dividerAfterIndex != null ? dividerAfterIndex! + 1 : -1;

    return SheetLayout(
      title: title,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: labels.length + (dividerAfterIndex != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == dividerSlot) {
            return const Divider(height: 1);
          }
          final labelIndex =
              index > dividerSlot && dividerSlot >= 0 ? index - 1 : index;
          final isSelected = labelIndex == selectedIndex;
          return _OptionRow(
            label: labels[labelIndex],
            selected: isSelected,
            onTap: () => Navigator.of(context).pop(labelIndex),
          );
        },
      ),
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
    final sizing = Theme.of(context).extension<AppSizing>()!;

    return ListTile(
      title: Text(
        label,
        style: textTheme.bodyLarge?.copyWith(color: colors.onSurface),
      ),
      trailing: selected
          ? Icon(Symbols.check_sharp,
              size: sizing.iconRegular, color: colors.primary)
          : SizedBox(width: sizing.iconRegular),
      onTap: onTap,
    );
  }
}
