import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/info_row.dart';

WidgetbookComponent infoRowComponent() {
  return WidgetbookComponent(
    name: 'InfoRow',
    useCases: [
      _playground(),
      _patterns(),
    ],
  );
}

WidgetbookUseCase _playground() {
  return WidgetbookUseCase(
    name: 'Playground',
    builder: (context) {
      final label = context.knobs.string(
        label: 'Label',
        initialValue: 'Block Height',
      );
      final value = context.knobs.string(
        label: 'Value',
        initialValue: '1,234,567',
      );
      final showDivider = context.knobs.boolean(
        label: 'Show Divider',
        initialValue: true,
      );

      return Padding(
        padding: const EdgeInsets.all(16),
        child: InfoRow(
          label: label,
          value: value,
          showDivider: showDivider,
        ),
      );
    },
  );
}

WidgetbookUseCase _patterns() {
  return WidgetbookUseCase(
    name: 'Common Patterns',
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const InfoRow(label: 'Block Height', value: '1,234,567'),
            InfoRow(
              label: 'Hash',
              value: '0x3a9f...b2c1',
              valueStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              trailing: IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            const InfoRow(label: 'Epoch', value: '42'),
            const InfoRow(label: 'Slot', value: '7,891'),
            const InfoRow(
              label: 'Status',
              value: 'Confirmed',
              showDivider: false,
            ),
          ],
        ),
      );
    },
  );
}
