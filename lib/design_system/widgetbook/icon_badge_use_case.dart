import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
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
        child: IconBadge(icon: Symbols.bolt_sharp),
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
