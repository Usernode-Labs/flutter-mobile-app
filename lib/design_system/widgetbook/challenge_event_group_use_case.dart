import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/challenge_card.dart';
import '../src/challenge_event_group.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent challengeEventGroupComponent() {
  return WidgetbookComponent(
    name: 'ChallengeEventGroup',
    useCases: [
      _playground(),
      _multipleEvents(),
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

      final eventName = context.knobs.string(
        label: 'Event Name',
        initialValue: 'Block Production',
      );

      final dateRange = context.knobs.string(
        label: 'Date Range',
        initialValue: 'Mar 1 - Mar 31',
      );

      final pointsLabel = context.knobs.string(
        label: 'Points Label',
        initialValue: '6,500 pts',
      );

      return Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: ChallengeEventGroup(
          eventName: eventName,
          dateRange: dateRange,
          pointsLabel: pointsLabel,
          challenges: const [
            ChallengeEventItem(
              title: 'Produce Every Block',
              category: ChallengeCategory.technical,
              variant: ChallengeCardVariant.completed,
              earnedPoints: '4,500 pts',
            ),
            ChallengeEventItem(
              title: 'Live Feedback',
              category: ChallengeCategory.community,
              variant: ChallengeCardVariant.completed,
              earnedPoints: '500 pts',
            ),
            ChallengeEventItem(
              title: 'Weekend Sprint',
              category: ChallengeCategory.flash,
              variant: ChallengeCardVariant.missed,
            ),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Use case 2 — Multiple Events
// ---------------------------------------------------------------------------

WidgetbookUseCase _multipleEvents() {
  return WidgetbookUseCase(
    name: 'Multiple Events',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;

      return SingleChildScrollView(
        padding: EdgeInsets.all(spacing.space16),
        child: Column(
          spacing: spacing.space16,
          children: const [
            ChallengeEventGroup(
              eventName: 'Block Production',
              dateRange: 'Mar 1 - Mar 31',
              pointsLabel: '5,000 pts',
              challenges: [
                ChallengeEventItem(
                  title: 'Produce Every Block',
                  category: ChallengeCategory.technical,
                  variant: ChallengeCardVariant.completed,
                  earnedPoints: '4,500 pts',
                ),
                ChallengeEventItem(
                  title: 'Live Feedback',
                  category: ChallengeCategory.community,
                  variant: ChallengeCardVariant.completed,
                  earnedPoints: '500 pts',
                ),
              ],
            ),
            ChallengeEventGroup(
              eventName: 'Transactions & Wallets',
              dateRange: 'Jan 15 - Feb 28',
              pointsLabel: '3,200 pts',
              challenges: [
                ChallengeEventItem(
                  title: 'Send 50 Transactions',
                  category: ChallengeCategory.technical,
                  variant: ChallengeCardVariant.completed,
                  earnedPoints: '2,000 pts',
                ),
                ChallengeEventItem(
                  title: 'Use 3 dApps',
                  category: ChallengeCategory.community,
                  variant: ChallengeCardVariant.completed,
                  earnedPoints: '1,200 pts',
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
