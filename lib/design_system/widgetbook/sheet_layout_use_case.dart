import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/info_row.dart';
import '../src/sheet_layout.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent sheetLayoutComponent() {
  return WidgetbookComponent(
    name: 'SheetLayout',
    useCases: [
      _withTitle(),
      _withoutTitle(),
    ],
  );
}

WidgetbookUseCase _withTitle() {
  return WidgetbookUseCase(
    name: 'With Title',
    builder: (context) {
      final title = context.knobs.string(
        label: 'Title',
        initialValue: 'Build Info',
      );

      return SheetLayout(
        title: title,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoRow(label: 'Version', value: '0.8.1'),
            InfoRow(label: 'Commit', value: 'abc1234'),
            InfoRow(label: 'Branch', value: 'main'),
            InfoRow(
              label: 'Status',
              value: 'Release',
              showDivider: false,
            ),
          ],
        ),
      );
    },
  );
}

WidgetbookUseCase _withoutTitle() {
  return WidgetbookUseCase(
    name: 'Without Title',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;

      return SheetLayout(
        child: Padding(
          padding: EdgeInsets.only(top: spacing.space16),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InfoRow(label: 'Block Height', value: '1,234,567'),
              InfoRow(label: 'Epoch', value: '42'),
              InfoRow(
                label: 'Slot',
                value: '7,891',
                showDivider: false,
              ),
            ],
          ),
        ),
      );
    },
  );
}
