import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/dropdown_chip.dart';

WidgetbookComponent dropdownChipComponent() {
  return WidgetbookComponent(
    name: 'DropdownChip',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final label = context.knobs.string(
            label: 'Label',
            initialValue: 'Season 2',
          );

          final expanded = context.knobs.boolean(
            label: 'Expanded',
            initialValue: false,
          );

          final selected = context.knobs.boolean(
            label: 'Selected',
            initialValue: false,
          );

          final enabled = context.knobs.boolean(
            label: 'Enabled',
            initialValue: true,
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                expanded
                    ? Expanded(
                        child: DropdownChip(
                          label: label,
                          expanded: expanded,
                          selected: selected,
                          enabled: enabled,
                          onTap: () {},
                        ),
                      )
                    : DropdownChip(
                        label: label,
                        expanded: expanded,
                        selected: selected,
                        enabled: enabled,
                        onTap: () {},
                      ),
              ],
            ),
          );
        },
      ),
    ],
  );
}
