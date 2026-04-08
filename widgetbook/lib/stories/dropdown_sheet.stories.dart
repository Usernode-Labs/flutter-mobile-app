import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/dropdown_sheet.dart';

part 'dropdown_sheet.stories.g.dart';

/// Wrapper widget for showcasing showDropdownSheet() in Widgetbook.
/// Since showDropdownSheet is a function, not a widget, we wrap it.
class DropdownSheetDemo extends StatelessWidget {
  const DropdownSheetDemo({
    super.key,
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
    return Center(
      child: ElevatedButton(
        onPressed: () => showDropdownSheet(
          context: context,
          labels: labels,
          title: title,
          selectedIndex: selectedIndex,
          dividerAfterIndex: dividerAfterIndex,
        ),
        child: const Text('Open Dropdown Sheet'),
      ),
    );
  }
}

const meta = Meta<DropdownSheetDemo>(path: 'widgets/chips');

final $Default = _Story(
  args: _Args(
    labels: Arg.fixed(['Season 1', 'Season 2', 'Season 3']),
    title: Arg.fixed('Select Season'),
    selectedIndex: Arg.fixed(1),
  ),
);

final $WithDivider = _Story(
  name: 'With Divider',
  args: _Args(
    labels: Arg.fixed([
      'DApps Integration',
      'Flash Challenges',
      'Community',
      'All Categories',
    ]),
    title: Arg.fixed('Category'),
    selectedIndex: Arg.fixed(0),
    dividerAfterIndex: Arg.fixed(2),
  ),
);
