import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/icon_badge.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent iconBadgeComponent() {
  return WidgetbookComponent(
    name: 'IconBadge',
    useCases: [
      _playground(),
      _variants(),
    ],
  );
}

WidgetbookUseCase _playground() {
  return WidgetbookUseCase(
    name: 'Playground',
    builder: (context) {
      return const Center(
        child: IconBadge(icon: Icons.bolt),
      );
    },
  );
}

WidgetbookUseCase _variants() {
  return WidgetbookUseCase(
    name: 'Icon Variants',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;

      return Center(
        child: Wrap(
          spacing: spacing.space16,
          runSpacing: spacing.space16,
          children: const [
            IconBadge(icon: Icons.bolt),
            IconBadge(icon: Icons.account_balance_wallet),
            IconBadge(icon: Icons.bar_chart),
            IconBadge(icon: Icons.settings),
            IconBadge(icon: Icons.person),
            IconBadge(icon: Icons.star),
          ],
        ),
      );
    },
  );
}
