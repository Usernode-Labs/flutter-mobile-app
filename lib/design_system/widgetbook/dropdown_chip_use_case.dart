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

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                expanded
                    ? Expanded(
                        child: DropdownChip(
                          label: label,
                          expanded: expanded,
                          onTap: () {},
                        ),
                      )
                    : DropdownChip(
                        label: label,
                        expanded: expanded,
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
