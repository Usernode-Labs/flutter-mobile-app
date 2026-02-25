import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/rank_badge.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent rankBadgeComponent() {
  return WidgetbookComponent(
    name: 'RankBadge',
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
      final rank = context.knobs.string(
        label: 'Rank',
        initialValue: '#1',
      );

      return Center(
        child: RankBadge(rank: rank),
      );
    },
  );
}

WidgetbookUseCase _patterns() {
  return WidgetbookUseCase(
    name: 'Rank Variants',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;

      return Center(
        child: Wrap(
          spacing: spacing.space16,
          runSpacing: spacing.space16,
          children: const [
            RankBadge(rank: '#1'),
            RankBadge(rank: '#2'),
            RankBadge(rank: '#3'),
            RankBadge(rank: '10'),
            RankBadge(rank: '100'),
            RankBadge(rank: '999'),
          ],
        ),
      );
    },
  );
}
