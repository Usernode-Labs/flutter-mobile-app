import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/list_section_header.dart';

WidgetbookComponent listSectionHeaderComponent() {
  return WidgetbookComponent(
    name: 'ListSectionHeader',
    useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) {
          final title = context.knobs.string(
            label: 'Title',
            initialValue: 'General',
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ListSectionHeader(title: title),
                const Card(
                  child: ListTile(
                    title: Text('Example item'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}
