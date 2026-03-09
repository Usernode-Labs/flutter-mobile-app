import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/challenge_card.dart';
import '../src/challenge_category_icon.dart';

WidgetbookComponent challengeCategoryIconComponent() {
  return WidgetbookComponent(
    name: 'ChallengeCategoryIcon',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final category = context.knobs.object.dropdown<ChallengeCategory>(
            label: 'Category',
            options: ChallengeCategory.values,
            initialOption: ChallengeCategory.technical,
            labelBuilder: (c) => c.name,
          );

          final muted = context.knobs.boolean(
            label: 'Muted',
            initialValue: false,
          );

          return Center(
            child: ChallengeCategoryIcon(
              category: category,
              size: 80,
              muted: muted,
            ),
          );
        },
      ),
    ],
  );
}
