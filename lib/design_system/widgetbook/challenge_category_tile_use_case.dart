import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/challenge_card.dart';
import '../src/challenge_category_icon.dart';
import '../src/challenge_category_tile.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent challengeCategoryTileComponent() {
  return WidgetbookComponent(
    name: 'ChallengeCategoryTile',
    useCases: [
      _playground(),
      _threeCategories(),
    ],
  );
}

// ---------------------------------------------------------------------------
// Use case 1 — Playground
// ---------------------------------------------------------------------------

WidgetbookUseCase _playground() {
  return WidgetbookUseCase(
    name: 'Playground',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;

      final categoryName = context.knobs.string(
        label: 'Category Name',
        initialValue: 'Technical',
      );

      final remainingCount = context.knobs.double
          .slider(label: 'Remaining', initialValue: 3, min: 0, max: 10)
          .round();

      final completedCount = context.knobs.double
          .slider(label: 'Completed', initialValue: 2, min: 0, max: 10)
          .round();

      final pointsLabel = context.knobs.string(
        label: 'Points Label',
        initialValue: '4,525 pts',
      );

      final initiallyExpanded = context.knobs.boolean(
        label: 'Initially Expanded',
        initialValue: true,
      );

      return Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: ChallengeCategoryTile(
          categoryIcon: const ChallengeCategoryIcon(
            category: ChallengeCategory.technical,
            size: 40,
          ),
          categoryName: categoryName,
          remainingCount: remainingCount,
          completedCount: completedCount,
          pointsLabel: pointsLabel,
          initiallyExpanded: initiallyExpanded,
          challenges: const [
            ChallengeCategoryItem(
              title: 'Run a validator node',
              isCompleted: true,
            ),
            ChallengeCategoryItem(
              title: 'Submit 10 transactions',
              isCompleted: true,
            ),
            ChallengeCategoryItem(
              title: 'Deploy a smart contract',
              isCompleted: false,
            ),
            ChallengeCategoryItem(
              title: 'Stake 1,000 tokens',
              isCompleted: false,
            ),
            ChallengeCategoryItem(
              title: 'Complete SDK tutorial',
              isCompleted: false,
            ),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Use case 2 — Three Categories
// ---------------------------------------------------------------------------

WidgetbookUseCase _threeCategories() {
  return WidgetbookUseCase(
    name: 'Three Categories',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;

      return SingleChildScrollView(
        padding: EdgeInsets.all(spacing.space16),
        child: Column(
          children: [
            ChallengeCategoryTile(
              categoryIcon: const ChallengeCategoryIcon(
                category: ChallengeCategory.technical,
                size: 40,
              ),
              categoryName: 'Technical',
              remainingCount: 3,
              completedCount: 2,
              pointsLabel: '4,525 pts',
              initiallyExpanded: true,
              challenges: const [
                ChallengeCategoryItem(
                  title: 'Run a validator node',
                  isCompleted: true,
                ),
                ChallengeCategoryItem(
                  title: 'Submit 10 transactions',
                  isCompleted: true,
                ),
                ChallengeCategoryItem(
                  title: 'Deploy a smart contract',
                  isCompleted: false,
                ),
                ChallengeCategoryItem(
                  title: 'Stake 1,000 tokens',
                  isCompleted: false,
                ),
                ChallengeCategoryItem(
                  title: 'Complete SDK tutorial',
                  isCompleted: false,
                ),
              ],
            ),
            ChallengeCategoryTile(
              categoryIcon: const ChallengeCategoryIcon(
                category: ChallengeCategory.community,
                size: 40,
              ),
              categoryName: 'Community',
              remainingCount: 1,
              completedCount: 4,
              pointsLabel: '6,200 pts',
              challenges: const [
                ChallengeCategoryItem(
                  title: 'Invite 5 friends',
                  isCompleted: true,
                ),
                ChallengeCategoryItem(
                  title: 'Post in Discord',
                  isCompleted: true,
                ),
                ChallengeCategoryItem(
                  title: 'Attend community call',
                  isCompleted: true,
                ),
                ChallengeCategoryItem(
                  title: 'Write a blog post',
                  isCompleted: true,
                ),
                ChallengeCategoryItem(
                  title: 'Host a workshop',
                  isCompleted: false,
                ),
              ],
            ),
            ChallengeCategoryTile(
              categoryIcon: const ChallengeCategoryIcon(
                category: ChallengeCategory.flash,
                size: 40,
              ),
              categoryName: 'Flash',
              remainingCount: 2,
              completedCount: 1,
              pointsLabel: '1,800 pts',
              challenges: const [
                ChallengeCategoryItem(
                  title: 'Daily check-in streak',
                  isCompleted: true,
                ),
                ChallengeCategoryItem(
                  title: 'Weekend sprint',
                  isCompleted: false,
                ),
                ChallengeCategoryItem(
                  title: 'Speed challenge',
                  isCompleted: false,
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
