import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/dropdown_chip.dart';

WidgetbookComponent dropdownChipComponent() {
  return WidgetbookComponent(
    name: 'DropdownChip',
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
      final label = context.knobs.string(
        label: 'Label',
        initialValue: 'Season 2',
      );

      final variant = context.knobs.object.dropdown<ChipVariant>(
        label: 'Variant',
        options: ChipVariant.values,
        initialOption: ChipVariant.outlined,
        labelBuilder: (v) => v.name,
      );

      final size = context.knobs.object.dropdown<ChipSize>(
        label: 'Size',
        options: ChipSize.values,
        initialOption: ChipSize.regular,
        labelBuilder: (s) => s.name,
      );

      final expanded = context.knobs.boolean(
        label: 'Expanded',
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
                      variant: variant,
                      size: size,
                      expanded: expanded,
                      enabled: enabled,
                      onTap: () {},
                    ),
                  )
                : DropdownChip(
                    label: label,
                    variant: variant,
                    size: size,
                    expanded: expanded,
                    enabled: enabled,
                    onTap: () {},
                  ),
          ],
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
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final size in ChipSize.values)
                    DropdownChip(
                      label: '${size.name} ${variant.name}',
                      variant: variant,
                      size: size,
                      onTap: () {},
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Disabled row
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final size in ChipSize.values)
                    DropdownChip(
                      label: '${size.name} disabled',
                      variant: variant,
                      size: size,
                      enabled: false,
                      onTap: () {},
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      );
    },
  );
}
