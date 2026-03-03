import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/icon_badge.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent iconBadgeComponent() {
  return WidgetbookComponent(
    name: 'IconBadge',
    useCases: [
      _playground(),
      _variants(),
      _insetComparison(),
    ],
  );
}

WidgetbookUseCase _playground() {
  return WidgetbookUseCase(
    name: 'Playground',
    builder: (context) {
      final sizing = Theme.of(context).extension<AppSizing>()!;
      final insetSurface = context.knobs.boolean(
        label: 'Inset surface (3-layer)',
        initialValue: true,
      );

      return Center(
        child: IconBadge(
          icon: Symbols.bolt_sharp,
          surfaceSize: insetSurface ? null : sizing.iconContainerRegular,
        ),
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
            IconBadge(icon: Symbols.bolt_sharp),
            IconBadge(icon: Symbols.account_balance_wallet_sharp),
            IconBadge(icon: Symbols.bar_chart_sharp),
            IconBadge(icon: Symbols.settings_sharp),
            IconBadge(icon: Symbols.person_sharp),
            IconBadge(icon: Symbols.star_sharp),
          ],
        ),
      );
    },
  );
}

WidgetbookUseCase _insetComparison() {
  return WidgetbookUseCase(
    name: 'Default (3-layer) vs Flush surface',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;
      final sizing = Theme.of(context).extension<AppSizing>()!;
      final textTheme = Theme.of(context).textTheme;

      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: spacing.space24,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              spacing: spacing.space8,
              children: [
                const IconBadge(icon: Symbols.bolt_sharp),
                Text('Default (3-layer)', style: textTheme.labelSmall),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              spacing: spacing.space8,
              children: [
                IconBadge(
                  icon: Symbols.bolt_sharp,
                  surfaceSize: sizing.iconContainerRegular,
                ),
                Text('Flush surface', style: textTheme.labelSmall),
              ],
            ),
          ],
        ),
      );
    },
  );
}
