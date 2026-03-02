import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/status_badge.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent statusBadgeComponent() {
  return WidgetbookComponent(
    name: 'StatusBadge',
    useCases: [
      _playground(),
      _allVariants(),
    ],
  );
}

WidgetbookUseCase _playground() {
  return WidgetbookUseCase(
    name: 'Playground',
    builder: (context) {
      final label = context.knobs.string(
        label: 'Label',
        initialValue: 'Active',
      );
      final showIcon = context.knobs.boolean(
        label: 'Show Icon',
        initialValue: true,
      );

      return Center(
        child: StatusBadge(
          label: label,
          variant: StatusBadgeVariant.success,
          icon: showIcon ? Symbols.check_circle_sharp : null,
        ),
      );
    },
  );
}

WidgetbookUseCase _allVariants() {
  return WidgetbookUseCase(
    name: 'All Variants',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;

      return Center(
        child: Wrap(
          spacing: spacing.space8,
          runSpacing: spacing.space8,
          children: const [
            StatusBadge(
              label: 'Success',
              variant: StatusBadgeVariant.success,
              icon: Symbols.check_circle_sharp,
            ),
            StatusBadge(
              label: 'Error',
              variant: StatusBadgeVariant.error,
              icon: Symbols.error_sharp,
            ),
            StatusBadge(
              label: 'Warning',
              variant: StatusBadgeVariant.warning,
              icon: Symbols.warning_sharp,
            ),
            StatusBadge(
              label: 'Info',
              variant: StatusBadgeVariant.info,
              icon: Symbols.info_sharp,
            ),
            StatusBadge(
              label: 'Neutral',
              variant: StatusBadgeVariant.neutral,
            ),
          ],
        ),
      );
    },
  );
}
