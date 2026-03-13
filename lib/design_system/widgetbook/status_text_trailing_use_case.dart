import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/status_badge.dart';
import '../src/status_text_trailing.dart';

WidgetbookComponent statusTextTrailingComponent() {
  return WidgetbookComponent(
    name: 'StatusTextTrailing',
    useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) {
          final text = context.knobs.string(
            label: 'Text',
            initialValue: 'Connected',
          );
          final variant = context.knobs.object.dropdown<StatusBadgeVariant>(
            label: 'Variant',
            options: StatusBadgeVariant.values,
            initialOption: StatusBadgeVariant.success,
            labelBuilder: (v) => v.name,
          );

          return Center(
            child: ListTile(
              title: const Text('Example Row'),
              trailing: StatusTextTrailing(text: text, variant: variant),
            ),
          );
        },
      ),
      WidgetbookUseCase(
        name: 'All Variants',
        builder: (context) {
          const variants = [
            ('Connected', StatusBadgeVariant.success),
            ('Failed', StatusBadgeVariant.error),
            ('Pending', StatusBadgeVariant.warning),
            ('In Progress', StatusBadgeVariant.info),
            ('Not Started', StatusBadgeVariant.neutral),
          ];

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, variant) in variants)
                ListTile(
                  title: Text(variant.name),
                  trailing: StatusTextTrailing(text: label, variant: variant),
                ),
            ],
          );
        },
      ),
    ],
  );
}
