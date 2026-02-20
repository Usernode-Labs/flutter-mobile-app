import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/core/widgets/app_progress_bar.dart';

WidgetbookComponent appProgressBarComponent() {
  return WidgetbookComponent(
    name: 'AppProgressBar',
    useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) => Padding(
          padding: const EdgeInsets.all(32),
          child: AppProgressBar(
            value: context.knobs.double.slider(
              label: 'Value',
              initialValue: 0.6,
              min: 0.0,
              max: 1.0,
            ),
            height: context.knobs.double.slider(
              label: 'Height',
              initialValue: 12.0,
              min: 4.0,
              max: 24.0,
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Custom Colors',
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppProgressBar(value: 0.3, valueColor: colorScheme.error),
                const SizedBox(height: 16),
                AppProgressBar(value: 0.6, valueColor: colorScheme.primary),
                const SizedBox(height: 16),
                AppProgressBar(value: 0.9, valueColor: colorScheme.tertiary),
              ],
            ),
          );
        },
      ),
    ],
  );
}
