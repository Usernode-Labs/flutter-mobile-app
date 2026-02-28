import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/dropdown_chain.dart';
import '../src/dropdown_chip.dart';

WidgetbookComponent dropdownChainComponent() {
  return WidgetbookComponent(
    name: 'DropdownChain',
    useCases: [
      _playground(),
      _allVariants(),
    ],
  );
}

WidgetbookUseCase _playground() {
  return WidgetbookUseCase(
    name: 'Playground',
    builder: (context) {
      final itemCount = context.knobs.int.slider(
        label: 'Number of items',
        initialValue: 2,
        min: 1,
        max: 4,
      );

      final variant = context.knobs.object.dropdown<ChipVariant>(
        label: 'Variant',
        options: ChipVariant.values,
        initialOption: ChipVariant.surface,
        labelBuilder: (v) => v.name,
      );

      final size = context.knobs.object.dropdown<ChipSize>(
        label: 'Size',
        options: ChipSize.values,
        initialOption: ChipSize.regular,
        labelBuilder: (s) => s.name,
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
        child: DropdownChain(
          items: items,
          variant: variant,
          size: size,
        ),
      );
    },
  );
}

WidgetbookUseCase _allVariants() {
  return WidgetbookUseCase(
    name: 'All Variants',
    builder: (context) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final variant in ChipVariant.values) ...[
              Text(
                variant.name.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              for (final size in ChipSize.values) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DropdownChain(
                    variant: variant,
                    size: size,
                    items: [
                      DropdownChainItem(
                        label: 'Season 2',
                        onTap: () {},
                      ),
                      DropdownChainItem(
                        label: 'DApps Integration',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ],
        ),
      );
    },
  );
}
