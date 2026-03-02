import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/button.dart';

WidgetbookComponent buttonComponent() {
  return WidgetbookComponent(
    name: 'Button',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final label = context.knobs.string(
            label: 'Label',
            initialValue: 'View in Leaderboard',
          );

          final showIcon = context.knobs.boolean(
            label: 'Show leading icon',
            initialValue: false,
          );

          final size = context.knobs.object.dropdown<ButtonSize>(
            label: 'Size',
            options: ButtonSize.values,
            initialOption: ButtonSize.regular,
            labelBuilder: (s) => s.name,
          );

          final variant = context.knobs.object.dropdown<ButtonVariant>(
            label: 'Variant',
            options: ButtonVariant.values,
            initialOption: ButtonVariant.tonal,
            labelBuilder: (v) => v.name,
          );

          final darkBackground = context.knobs.boolean(
            label: 'Dark background',
            initialValue: false,
          );

          final button = Button(
            label: label,
            leadingIcon: showIcon
                ? const Icon(Symbols.leaderboard_sharp, size: 20)
                : null,
            size: size,
            variant: variant,
            onTap: () {},
          );

          if (darkBackground) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade800,
                borderRadius: BorderRadius.circular(12),
              ),
              child: button,
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: button,
          );
        },
      ),
      WidgetbookUseCase(
        name: 'All Variants',
        builder: (context) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final variant in ButtonVariant.values) ...[
                  Text(
                    variant.name.toUpperCase(),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (final size in ButtonSize.values)
                        Button(
                          label: '${size.name} ${variant.name}',
                          size: size,
                          variant: variant,
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
      ),
    ],
  );
}
