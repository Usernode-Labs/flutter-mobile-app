import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/core/widgets/app_card.dart';

WidgetbookComponent appCardComponent() {
  return WidgetbookComponent(
    name: 'AppCard',
    useCases: [
      WidgetbookUseCase(
        name: 'Regular',
        builder: (context) {
          final showHeader = context.knobs.boolean(
            label: 'Show Header',
            initialValue: true,
          );
          final tappable = context.knobs.boolean(
            label: 'Tappable',
            initialValue: false,
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: AppCard.regular(
              header: showHeader ? 'Card Title' : null,
              onTap: tappable ? () {} : null,
              child: const Text('Card content goes here. '
                  'This is a regular card with 16px padding.'),
            ),
          );
        },
      ),
      WidgetbookUseCase(
        name: 'Compact',
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: AppCard.compact(
            header: context.knobs.boolean(
              label: 'Show Header',
              initialValue: false,
            )
                ? 'Compact Card'
                : null,
            child: const Text('Compact card with 12px padding.'),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Spacious',
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: AppCard.spacious(
            header: 'Spacious Card',
            headerAction: const Icon(Icons.more_vert),
            child: const Text('Spacious card with 24px padding '
                'and a header action.'),
          ),
        ),
      ),
    ],
  );
}
