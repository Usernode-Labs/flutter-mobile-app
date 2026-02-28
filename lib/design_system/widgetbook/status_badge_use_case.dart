import 'package:flutter/material.dart';
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
          icon: showIcon ? Icons.check_circle : null,
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
              icon: Icons.check_circle,
            ),
            StatusBadge(
              label: 'Error',
              variant: StatusBadgeVariant.error,
              icon: Icons.error,
            ),
            StatusBadge(
              label: 'Warning',
              variant: StatusBadgeVariant.warning,
              icon: Icons.warning,
            ),
            StatusBadge(
              label: 'Info',
              variant: StatusBadgeVariant.info,
              icon: Icons.info,
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
