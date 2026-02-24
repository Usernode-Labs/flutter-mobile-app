import 'package:flutter/material.dart';
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
            leadingIcon:
                showIcon ? const Icon(Icons.leaderboard, size: 20) : null,
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
    ],
  );
}
