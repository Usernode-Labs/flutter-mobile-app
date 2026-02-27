import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/dropdown_chain.dart';

WidgetbookComponent dropdownChainComponent() {
  return WidgetbookComponent(
    name: 'DropdownChain',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final itemCount = context.knobs.int.slider(
            label: 'Number of items',
            initialValue: 2,
            min: 1,
            max: 4,
          );

          final label1 = context.knobs.string(
            label: 'Label 1',
            initialValue: 'Season 2',
          );

          final label2 = context.knobs.string(
            label: 'Label 2',
            initialValue: 'DApps Integration',
          );

          final label3 = context.knobs.string(
            label: 'Label 3',
            initialValue: 'Advanced',
          );

          final label4 = context.knobs.string(
            label: 'Label 4',
            initialValue: 'Week 3',
          );

          final allLabels = [label1, label2, label3, label4];
          final items = List.generate(
            itemCount,
            (i) => DropdownChainItem(
              label: allLabels[i],
              onTap: () {},
            ),
          );

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownChain(items: items),
          );
        },
      ),
    ],
  );
}
