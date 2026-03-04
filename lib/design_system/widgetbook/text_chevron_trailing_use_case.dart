import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/text_chevron_trailing.dart';

WidgetbookComponent textChevronTrailingComponent() {
  return WidgetbookComponent(
    name: 'TextChevronTrailing',
    useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) {
          final text = context.knobs.string(
            label: 'Text',
            initialValue: '10,000 pts',
          );

          return Center(
            child: ListTile(
              title: const Text('Example Row'),
              trailing: TextChevronTrailing(text: text),
            ),
          );
        },
      ),
    ],
  );
}
