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

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Button(
              label: label,
              leadingIcon:
                  showIcon ? const Icon(Icons.leaderboard, size: 20) : null,
              onTap: () {},
            ),
          );
        },
      ),
    ],
  );
}
