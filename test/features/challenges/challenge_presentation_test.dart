import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/services/challenge_api_visual_fixture.dart';
import 'package:crypto_mobile_app/core/services/challenge_ui_visual_fixture.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_presentation.dart';

ChallengeDto _dto({
  int id = 1,
  String goal = 'Challenge',
  String reward = '500',
  ChallengeMetric? metric,
  String? subCategory,
  String? scheduleEnd,
  bool completed = false,
  int displayOrder = 0,
  bool featured = false,
  int? featuredOrder,
}) {
  return ChallengeDto(
    id: id,
    category: 'community',
    goal: goal,
    task: goal,
    reward: reward,
    metric: metric,
    subCategory: subCategory,
    scheduleEnd: scheduleEnd,
    displayOrder: displayOrder,
    featured: featured,
    featuredOrder: featuredOrder,
    enabled: true,
    completed: completed,
  );
}

EnrichedChallenge _enriched(ChallengeDto dto) => EnrichedChallenge(dto: dto);

AtomicChallengePhase _expectedPhase(ChallengeVisualUiPhase phase) =>
    switch (phase) {
      ChallengeVisualUiPhase.open => AtomicChallengePhase.open,
      ChallengeVisualUiPhase.inProgress => AtomicChallengePhase.inProgress,
      ChallengeVisualUiPhase.pending =>
        AtomicChallengePhase.pendingFinalization,
      ChallengeVisualUiPhase.completed => AtomicChallengePhase.completed,
    };

AtomicChallengeRailTreatment _expectedRail(
  ChallengeVisualMatrixCase fixtureCase,
) =>
    switch (fixtureCase.metricType) {
      ChallengeVisualMetricType.binary => AtomicChallengeRailTreatment.checkbox,
      ChallengeVisualMetricType.technicalOngoing =>
        fixtureCase.phase == ChallengeVisualUiPhase.completed
            ? AtomicChallengeRailTreatment.checkbox
            : AtomicChallengeRailTreatment.technicalOngoing,
      ChallengeVisualMetricType.count ||
      ChallengeVisualMetricType.sum ||
      ChallengeVisualMetricType.percentage ||
      ChallengeVisualMetricType.rank =>
        AtomicChallengeRailTreatment.standard,
    };

double? _expectedFill(ChallengeVisualMatrixCase fixtureCase) {
  return switch (fixtureCase.metricType) {
    ChallengeVisualMetricType.count || ChallengeVisualMetricType.sum => switch (
          fixtureCase.phase) {
        ChallengeVisualUiPhase.inProgress => 0.4,
        ChallengeVisualUiPhase.pending ||
        ChallengeVisualUiPhase.completed =>
          1.0,
        ChallengeVisualUiPhase.open => 0.0,
      },
    ChallengeVisualMetricType.percentage => switch (fixtureCase.phase) {
        ChallengeVisualUiPhase.inProgress => 0.62,
        ChallengeVisualUiPhase.pending ||
        ChallengeVisualUiPhase.completed =>
          1.0,
        ChallengeVisualUiPhase.open => null,
      },
    ChallengeVisualMetricType.binary ||
    ChallengeVisualMetricType.rank ||
    ChallengeVisualMetricType.technicalOngoing =>
      null,
  };
}

String _expectedLeftText(ChallengeVisualMatrixCase fixtureCase) {
  return switch (fixtureCase.metricType) {
    ChallengeVisualMetricType.binary => switch (fixtureCase.phase) {
        ChallengeVisualUiPhase.open => 'Not done',
        ChallengeVisualUiPhase.inProgress => 'Started',
        ChallengeVisualUiPhase.pending => 'Submitted',
        ChallengeVisualUiPhase.completed => 'Done',
      },
    ChallengeVisualMetricType.count => switch (fixtureCase.phase) {
        ChallengeVisualUiPhase.open => '0 / 5 Kudos sent',
        ChallengeVisualUiPhase.inProgress => '2 / 5 Kudos sent',
        ChallengeVisualUiPhase.pending ||
        ChallengeVisualUiPhase.completed =>
          '5 / 5 Kudos sent',
      },
    ChallengeVisualMetricType.sum => switch (fixtureCase.phase) {
        ChallengeVisualUiPhase.open => '0 / 100 Activity points',
        ChallengeVisualUiPhase.inProgress => '40 / 100 Activity points',
        ChallengeVisualUiPhase.pending ||
        ChallengeVisualUiPhase.completed =>
          '100 / 100 Activity points',
      },
    ChallengeVisualMetricType.percentage => switch (fixtureCase.phase) {
        ChallengeVisualUiPhase.open => 'Not done',
        ChallengeVisualUiPhase.inProgress => '62% success',
        ChallengeVisualUiPhase.pending ||
        ChallengeVisualUiPhase.completed =>
          '100% success',
      },
    ChallengeVisualMetricType.rank => switch (fixtureCase.phase) {
        ChallengeVisualUiPhase.open => 'Not done',
        ChallengeVisualUiPhase.inProgress => 'Rank 7',
        ChallengeVisualUiPhase.pending => 'Rank submitted',
        ChallengeVisualUiPhase.completed => 'Rank 3',
      },
    ChallengeVisualMetricType.technicalOngoing => switch (fixtureCase.phase) {
        ChallengeVisualUiPhase.open => 'Not done',
        ChallengeVisualUiPhase.inProgress => '90% success',
        ChallengeVisualUiPhase.pending => '100% success',
        ChallengeVisualUiPhase.completed => '98% success',
      },
  };
}

String _expectedRightText(ChallengeVisualMatrixCase fixtureCase) {
  return switch (fixtureCase.metricType) {
    ChallengeVisualMetricType.binary => switch (fixtureCase.phase) {
        ChallengeVisualUiPhase.open => '500 pts',
        ChallengeVisualUiPhase.inProgress => '500 pts',
        ChallengeVisualUiPhase.pending => 'pending 500 pts',
        ChallengeVisualUiPhase.completed => 'completed 500 pts',
      },
    ChallengeVisualMetricType.count => switch (fixtureCase.phase) {
        ChallengeVisualUiPhase.open => '1,500 pts',
        ChallengeVisualUiPhase.inProgress => '400 / 1,500 pts',
        ChallengeVisualUiPhase.pending => 'pending 1,500 pts',
        ChallengeVisualUiPhase.completed => 'completed 1,500 pts',
      },
    ChallengeVisualMetricType.sum => switch (fixtureCase.phase) {
        ChallengeVisualUiPhase.open => '2,000 pts',
        ChallengeVisualUiPhase.inProgress => '800 / 2,000 pts',
        ChallengeVisualUiPhase.pending => 'pending 2,000 pts',
        ChallengeVisualUiPhase.completed => 'completed 2,000 pts',
      },
    ChallengeVisualMetricType.percentage => switch (fixtureCase.phase) {
        ChallengeVisualUiPhase.open => '2,500 pts',
        ChallengeVisualUiPhase.inProgress => '1,200 / 2,500 pts',
        ChallengeVisualUiPhase.pending => 'pending 2,500 pts',
        ChallengeVisualUiPhase.completed => 'completed 2,500 pts',
      },
    ChallengeVisualMetricType.rank => switch (fixtureCase.phase) {
        ChallengeVisualUiPhase.open => '3,000 pts',
        ChallengeVisualUiPhase.inProgress => '1,000 / 3,000 pts',
        ChallengeVisualUiPhase.pending => 'pending 3,000 pts',
        ChallengeVisualUiPhase.completed => 'completed 3,000 pts',
      },
    ChallengeVisualMetricType.technicalOngoing => switch (fixtureCase.phase) {
        ChallengeVisualUiPhase.open => 'Earned 0 pts',
        ChallengeVisualUiPhase.inProgress => 'Earned 4,050 pts',
        ChallengeVisualUiPhase.pending => 'Earned 6,500 pts',
        ChallengeVisualUiPhase.completed => 'Earned 6,500 pts',
      },
  };
}

void main() {
  group('mapToAtomicCard (explicit progress)', () {
    test('binary open → checkbox rail, open phase, null fill', () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          goal: 'Fill in survey',
          reward: '500',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.binary,
            target: 1,
          ),
        )),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.none,
        ),
      );

      expect(card.railTreatment, AtomicChallengeRailTreatment.checkbox);
      expect(card.phase, AtomicChallengePhase.open);
      expect(card.fill, isNull);
      expect(card.leftText, 'Not done');
      expect(card.rightText, '500 pts');
    });

    test('binary open ignores API fallback challenge description', () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          goal: 'Read the onboarding note',
          reward: '500',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.binary,
            target: 1,
          ),
        )),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.none,
          description: 'Read the current onboarding note.',
        ),
      );

      expect(card.phase, AtomicChallengePhase.open);
      expect(card.leftText, 'Not done');
      expect(card.rightText, '500 pts');
      expect(card.fill, isNull);
    });

    test('binary none with pending points renders submitted status', () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          goal: 'Share feedback',
          reward: '500',
          metric: const ChallengeMetric(kind: ChallengeMetricKind.binary),
        )),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.none,
          pendingPoints: 500,
          description: 'You submitted the feedback form.',
        ),
      );

      expect(card.railTreatment, AtomicChallengeRailTreatment.checkbox);
      expect(card.phase, AtomicChallengePhase.pendingFinalization);
      expect(card.leftText, 'Submitted');
      expect(card.rightText, 'pending 500 pts');
      expect(card.fill, isNull);
    });

    test('no metric none with pending points renders submitted status', () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          goal: 'Share form feedback',
          reward: '500',
        )),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.none,
          current: 1,
          pendingPoints: 500,
          description: 'You submitted the feedback form.',
        ),
      );

      expect(card.railTreatment, AtomicChallengeRailTreatment.checkbox);
      expect(card.phase, AtomicChallengePhase.pendingFinalization);
      expect(card.leftText, 'Submitted');
      expect(card.rightText, 'pending 500 pts');
      expect(card.fill, isNull);
    });

    test('binary pending → pendingFinalization, "pending 500 pts"', () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.binary,
            target: 1,
          ),
        )),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.pending,
          pendingPoints: 500,
          description: 'Submitted',
        ),
      );

      expect(card.phase, AtomicChallengePhase.pendingFinalization);
      expect(card.leftText, 'Submitted');
      expect(card.rightText, 'pending 500 pts');
    });

    test('binary completed ignores long progress description in rail', () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          goal: 'Share feedback',
          reward: '500',
          metric: const ChallengeMetric(kind: ChallengeMetricKind.binary),
        )),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.earned,
          earnedPoints: 500,
          description:
              'You submitted the feedback form and it was accepted for this challenge.',
        ),
      );

      expect(card.phase, AtomicChallengePhase.completed);
      expect(card.leftText, 'Done');
      expect(card.rightText, 'completed 500 pts');
      expect(card.fill, isNull);
    });

    test('count in progress → standard rail, fraction fill + texts', () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          goal: 'Give kudos',
          reward: '1500',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.count,
            target: 5,
          ),
        )),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.inProgress,
          current: 2,
          target: 5,
          earnedPoints: 400,
        ),
      );

      expect(card.railTreatment, AtomicChallengeRailTreatment.standard);
      expect(card.phase, AtomicChallengePhase.inProgress);
      expect(card.fill, closeTo(0.4, 1e-9));
      expect(card.leftText, '2 / 5');
      expect(card.rightText, '400 / 1,500 pts');
    });

    test('count progress ignores evidence summary when current is absent', () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          goal: 'TEST: Complete 3 dApp actions',
          reward: '300 pts',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.count,
            label: 'Actions',
            target: 3,
          ),
        )),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.none,
          target: 3,
          pendingPoints: 500,
          description:
              '1 confirmed Echo dApp txs verified on-chain; awarded 100 pts',
        ),
      );

      expect(card.phase, AtomicChallengePhase.open);
      expect(card.railTreatment, AtomicChallengeRailTreatment.standard);
      expect(card.leftText, '0 / 3 Actions');
      expect(card.rightText, '300 pts');
      expect(card.fill, 0.0);
    });

    test('missed count without current does not parse reasoning as progress',
        () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          goal: 'TEST: Complete 3 dApp actions',
          reward: '300 pts',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.count,
            label: 'Actions',
            target: 3,
          ),
        )),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.missed,
          target: 3,
          pendingPoints: 500,
          description:
              '1 confirmed Echo dApp txs verified on-chain; 0 pts already committed; awarded 100 pts',
        ),
      );

      expect(card.phase, AtomicChallengePhase.open);
      expect(card.railTreatment, AtomicChallengeRailTreatment.standard);
      expect(card.leftText, 'Not done');
      expect(card.rightText, '300 pts');
      expect(card.fill, isNull);
    });

    test('missed count can show canonical current without completion styling',
        () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          goal: 'TEST: Complete 3 dApp actions',
          reward: '300 pts',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.count,
            label: 'Actions',
            target: 3,
          ),
        )),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.missed,
          current: 1,
          target: 3,
          description:
              '1 confirmed Echo dApp txs verified on-chain; 0 pts already committed; awarded 100 pts',
        ),
      );

      expect(card.phase, AtomicChallengePhase.open);
      expect(card.railTreatment, AtomicChallengeRailTreatment.standard);
      expect(card.leftText, '1 / 3 Actions');
      expect(card.rightText, '300 pts');
      expect(card.fill, closeTo(1 / 3, 0.0001));
    });

    test('count open uses zero counter instead of backend prose or points', () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          goal: 'TEST: Complete 3 dApp actions',
          reward: '300 pts',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.count,
            label: 'Actions',
            target: 3,
          ),
        )),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.none,
          target: 3,
          pendingPoints: 300,
          description: 'Perform 3 tracked test actions',
        ),
      );

      expect(card.phase, AtomicChallengePhase.open);
      expect(card.railTreatment, AtomicChallengeRailTreatment.standard);
      expect(card.leftText, '0 / 3 Actions');
      expect(card.rightText, '300 pts');
      expect(card.fill, 0.0);
    });

    test('count pending does not fabricate current when metric data is absent',
        () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          reward: '300 pts',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.count,
            label: 'Actions',
            target: 3,
          ),
        )),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.pending,
          target: 3,
          pendingPoints: 300,
          description: 'Submitted',
        ),
      );

      expect(card.phase, AtomicChallengePhase.open);
      expect(card.leftText, 'Not done');
      expect(card.rightText, '300 pts');
      expect(card.fill, isNull);
    });

    test('count pending stays in progress until target is reached', () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          reward: '1500',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.count,
            label: 'Actions',
            target: 5,
          ),
        )),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.pending,
          current: 2,
          target: 5,
          pendingPoints: 1500,
        ),
      );

      expect(card.phase, AtomicChallengePhase.inProgress);
      expect(card.leftText, '2 / 5 Actions');
      expect(card.rightText, '1,500 pts');
      expect(card.fill, closeTo(0.4, 1e-9));
    });

    test('count progress preserves fractional metric values', () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          goal: 'Earn fractional credit',
          reward: '1500',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.count,
            target: 5,
          ),
        )),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.inProgress,
          current: 2.5,
          target: 5.0,
          earnedPoints: 400,
        ),
      );

      expect(card.leftText, '2.5 / 5');
      expect(card.fill, 0.5);
    });

    test('unknown metric kind falls back to state-only checkbox treatment', () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          goal: 'Mystery metric',
          reward: '500',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.unknown,
            rawKind: 'streak',
            target: 3,
          ),
        )),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.inProgress,
          description: 'Started',
        ),
      );

      expect(card.railTreatment, AtomicChallengeRailTreatment.checkbox);
      expect(card.leftText, 'Started');
      expect(card.fill, isNull);
    });

    test('count pending → "5 / 5" + "pending 1,500 pts", full fill', () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          reward: '1500',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.count,
            target: 5,
          ),
        )),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.pending,
          current: 5,
          target: 5,
          pendingPoints: 1500,
        ),
      );

      expect(card.leftText, '5 / 5');
      expect(card.rightText, 'pending 1,500 pts');
      expect(card.fill, 1.0);
    });

    test('rank pending with no points → "waiting review", null fill', () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          goal: 'Top 3 most-voted ideas',
          reward: '0',
          metric: const ChallengeMetric(kind: ChallengeMetricKind.rank),
        )),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.pending,
          description: 'Joined',
        ),
      );

      expect(card.leftText, 'Joined');
      expect(card.rightText, 'waiting review');
      expect(card.fill, isNull);
    });

    test('produce-blocks → technicalOngoing, "% success" + "Earned … pts"', () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          goal: 'Produce Every Block',
          reward: '6500',
          subCategory: 'PRODUCE_BLOCKS_CHALLENGE',
          metric: const ChallengeMetric(kind: ChallengeMetricKind.percentage),
        )),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.inProgress,
          current: 90,
          earnedPoints: 10550,
        ),
      );

      expect(card.railTreatment, AtomicChallengeRailTreatment.technicalOngoing);
      expect(card.fill, isNull);
      expect(card.leftText, '90% success');
      expect(card.rightText, 'Earned 10,550 pts');
    });

    test('produce-blocks uses scoped success rate when current is absent', () {
      final card = mapToAtomicCard(
        const EnrichedChallenge(
          dto: ChallengeDto(
            id: 1,
            goal: 'Produce Every Block',
            task: 'Stay online.',
            category: 'technical',
            reward: '6500',
            enabled: true,
            completed: false,
            subCategory: kProduceBlocksSubCategory,
            metric: ChallengeMetric(kind: ChallengeMetricKind.percentage),
          ),
          activity: BreakdownActivity(
            id: 'produce-blocks',
            activityType: 'produce_blocks',
            points: 9050,
            description: 'Produce Every Block',
            challengeId: 1,
          ),
        ),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.inProgress,
          earnedPoints: 9050,
        ),
        technicalSuccessRate: 23.2,
      );

      expect(card.railTreatment, AtomicChallengeRailTreatment.technicalOngoing);
      expect(card.phase, AtomicChallengePhase.inProgress);
      expect(card.fill, isNull);
      expect(card.leftText, '23% success');
      expect(card.rightText, 'Earned 9,050 pts');
    });

    test(
        'completed produce-blocks keeps success text but uses completed checkbox rail',
        () {
      final card = mapToAtomicCard(
        const EnrichedChallenge(
          dto: ChallengeDto(
            id: 1,
            goal: 'Produce Every Block',
            task: 'Stay online.',
            category: 'technical',
            reward: '6500',
            enabled: true,
            completed: false,
            subCategory: kProduceBlocksSubCategory,
            metric: ChallengeMetric(kind: ChallengeMetricKind.percentage),
          ),
        ),
        progress: const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.earned,
          earnedPoints: 9050,
        ),
        technicalSuccessRate: 23.2,
      );

      expect(card.phase, AtomicChallengePhase.completed);
      expect(card.railTreatment, AtomicChallengeRailTreatment.checkbox);
      expect(card.fill, isNull);
      expect(card.leftText, '23% success');
      expect(card.rightText, 'Earned 9,050 pts');
    });
  });

  group('mapToAtomicCard (visual matrix)', () {
    for (final fixtureCase in ChallengeUiVisualFixture.allCases) {
      test('${fixtureCase.metricType.name} ${fixtureCase.phase.name}', () {
        final card = mapToAtomicCard(
          _enriched(fixtureCase.challenge),
          progress: fixtureCase.progress,
        );

        expect(card.phase, _expectedPhase(fixtureCase.phase));
        expect(card.railTreatment, _expectedRail(fixtureCase));

        final expectedFill = _expectedFill(fixtureCase);
        if (expectedFill == null) {
          expect(card.fill, isNull);
        } else {
          expect(card.fill, closeTo(expectedFill, 1e-9));
        }

        expect(card.leftText, _expectedLeftText(fixtureCase));
        expect(card.rightText, _expectedRightText(fixtureCase));
      });
    }
  });

  group('mapToAtomicCard (API contract fixture)', () {
    for (final fixtureCase in ChallengeApiVisualFixture.cases) {
      test(fixtureCase.id, () {
        final card = mapToAtomicCard(
          _enriched(fixtureCase.challenge),
          progress: fixtureCase.progress,
        );

        expect(fixtureCase.challenge.id, isPositive);
        expect(fixtureCase.breakdown.scope, isNotEmpty);
        expect(card.title, fixtureCase.challenge.goal);
        expect(card.rightText, isNotEmpty);
      });
    }

    test('recognized dApp count renders current / target metric label', () {
      final fixtureCase = ChallengeApiVisualFixture.cases.singleWhere(
        (item) => item.id == 'count-in-progress',
      );
      final card = mapToAtomicCard(
        _enriched(fixtureCase.challenge),
        progress: fixtureCase.progress,
      );

      expect(card.phase, AtomicChallengePhase.inProgress);
      expect(card.leftText, '1 / 3 Actions');
      expect(card.rightText, '300 pts');
      expect(card.fill, closeTo(1 / 3, 0.0001));
    });

    test('no metric untouched renders state-only open card', () {
      final fixtureCase = ChallengeApiVisualFixture.cases.singleWhere(
        (item) => item.id == 'metric-null-none',
      );
      final card = mapToAtomicCard(
        _enriched(fixtureCase.challenge),
        progress: fixtureCase.progress,
      );

      expect(card.railTreatment, AtomicChallengeRailTreatment.checkbox);
      expect(card.phase, AtomicChallengePhase.open);
      expect(card.leftText, 'Not done');
      expect(card.rightText, '500 pts');
      expect(card.fill, isNull);
    });

    test('no metric pending points renders submitted state', () {
      final fixtureCase = ChallengeApiVisualFixture.cases.singleWhere(
        (item) => item.id == 'metric-null-pending-points',
      );
      final card = mapToAtomicCard(
        _enriched(fixtureCase.challenge),
        progress: fixtureCase.progress,
      );

      expect(card.railTreatment, AtomicChallengeRailTreatment.checkbox);
      expect(card.phase, AtomicChallengePhase.pendingFinalization);
      expect(card.leftText, 'Submitted');
      expect(card.rightText, 'pending 500 pts');
      expect(card.fill, isNull);
    });

    test('no metric completed renders done with completed points', () {
      final fixtureCase = ChallengeApiVisualFixture.cases.singleWhere(
        (item) => item.id == 'metric-null-earned',
      );
      final card = mapToAtomicCard(
        _enriched(fixtureCase.challenge),
        progress: fixtureCase.progress,
      );

      expect(card.railTreatment, AtomicChallengeRailTreatment.checkbox);
      expect(card.phase, AtomicChallengePhase.completed);
      expect(card.leftText, 'Done');
      expect(card.rightText, 'completed 500 pts');
      expect(card.fill, isNull);
    });

    test('completed binary renders done with completed points', () {
      final fixtureCase = ChallengeApiVisualFixture.cases.singleWhere(
        (item) => item.id == 'binary-earned',
      );
      final card = mapToAtomicCard(
        _enriched(fixtureCase.challenge),
        progress: fixtureCase.progress,
      );

      expect(card.railTreatment, AtomicChallengeRailTreatment.checkbox);
      expect(card.phase, AtomicChallengePhase.completed);
      expect(card.leftText, 'Done');
      expect(card.rightText, 'completed 500 pts');
      expect(card.fill, isNull);
    });

    test('season sparse missing progress does not invent zero progress', () {
      final fixtureCase = ChallengeApiVisualFixture.cases.singleWhere(
        (item) => item.id == 'season-sparse-missing-progress',
      );
      final card = mapToAtomicCard(
        _enriched(fixtureCase.challenge),
        progress: fixtureCase.progress,
      );

      expect(fixtureCase.progress, isNull);
      expect(card.phase, AtomicChallengePhase.open);
      expect(card.leftText, 'Not done');
      expect(card.fill, isNull);
    });

    test('ambiguous missing event id returns no progress', () {
      final fixtureCase = ChallengeApiVisualFixture.cases.singleWhere(
        (item) => item.id == 'event-null-ambiguous',
      );
      final card = mapToAtomicCard(
        _enriched(fixtureCase.challenge),
        progress: fixtureCase.progress,
      );

      expect(fixtureCase.progress, isNull);
      expect(card.leftText, 'Not done');
      expect(card.fill, isNull);
    });
  });

  group('mapToAtomicCard (generic fallback, no progress)', () {
    test('no metric, no points → open checkbox with ceiling reward', () {
      final card = mapToAtomicCard(_enriched(_dto(reward: '500')));

      expect(card.railTreatment, AtomicChallengeRailTreatment.checkbox);
      expect(card.phase, AtomicChallengePhase.open);
      expect(card.leftText, 'Not done');
      expect(card.rightText, '500 pts');
    });

    test('count metric without progress does not invent zero progress', () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          reward: '300 pts',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.count,
            label: 'Actions',
            target: 3,
          ),
        )),
      );

      expect(card.railTreatment, AtomicChallengeRailTreatment.standard);
      expect(card.phase, AtomicChallengePhase.open);
      expect(card.leftText, 'Not done');
      expect(card.rightText, '300 pts');
      expect(card.fill, isNull);
    });

    test('expired challenge without progress does not render as done', () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          reward: '300 pts',
          scheduleEnd: '2020-01-01T00:00:00Z',
        )),
      );

      expect(card.phase, AtomicChallengePhase.open);
      expect(card.leftText, 'Not done');
      expect(card.rightText, '300 pts');
      expect(card.fill, isNull);
    });

    test('closed challenge without earned points does not render as done', () {
      final card = mapToAtomicCard(
        _enriched(_dto(
          reward: '300 pts',
          completed: true,
        )),
      );

      expect(card.phase, AtomicChallengePhase.open);
      expect(card.leftText, 'Not done');
      expect(card.rightText, '300 pts');
      expect(card.fill, isNull);
    });
  });

  group('buildChallengeBands', () {
    final now = DateTime.utc(2027, 6, 16, 12);
    String endsIn(Duration d) => now.add(d).toIso8601String();

    test('groups explicit Featured before Today / This week / Season', () {
      final challenges = [
        _enriched(_dto(
            id: 1,
            goal: 'Long haul first',
            scheduleEnd: endsIn(
              const Duration(days: 10),
            ))),
        _enriched(_dto(
            id: 2,
            goal: 'Due soon',
            scheduleEnd: endsIn(
              const Duration(hours: 5, minutes: 1),
            ))),
        _enriched(_dto(
            id: 3,
            goal: 'This week one',
            scheduleEnd: endsIn(
              const Duration(days: 4, hours: 1),
            ))),
        _enriched(_dto(
            id: 4,
            goal: 'Long haul',
            scheduleEnd: endsIn(
              const Duration(days: 30),
            ))),
        _enriched(_dto(
            id: 5,
            goal: 'Featured second',
            featured: true,
            featuredOrder: 2,
            displayOrder: 1,
            scheduleEnd: endsIn(
              const Duration(hours: 5),
            ))),
        _enriched(_dto(
            id: 6,
            goal: 'Featured first',
            featured: true,
            featuredOrder: 1,
            displayOrder: 2,
            scheduleEnd: endsIn(
              const Duration(days: 30),
            ))),
      ];

      final bands = buildChallengeBands(challenges, now: now);

      expect(bands.map((b) => b.title).toList(),
          ['Featured', 'Today', 'This week', 'Season']);
      expect(bands[0].deadlineText, isNull);
      expect(
        bands[0].cards.map((c) => c.title).toList(),
        ['Featured first', 'Featured second'],
      );
      expect(bands[0].cards.every((c) => c.featured), isTrue);
      expect(bands[1].deadlineText, '5h left');
      expect(bands[2].deadlineText, '4d left');
      expect(
        bands[3].cards.map((c) => c.title).toList(),
        ['Long haul first', 'Long haul'],
      );
    });

    test('puts only future deadlines in Today and This week', () {
      final challenges = [
        _enriched(_dto(
          id: 1,
          goal: 'Old completed',
          scheduleEnd: endsIn(const Duration(days: -3)),
        )),
        _enriched(_dto(
          id: 2,
          goal: 'Old unfinished',
          scheduleEnd: endsIn(const Duration(hours: -1)),
        )),
        _enriched(_dto(
          id: 3,
          goal: 'Due today',
          scheduleEnd: endsIn(const Duration(hours: 3)),
        )),
        _enriched(_dto(
          id: 4,
          goal: 'Due this week',
          scheduleEnd: endsIn(const Duration(days: 3)),
        )),
        _enriched(_dto(
          id: 5,
          goal: 'Long haul',
          scheduleEnd: endsIn(const Duration(days: 10)),
        )),
        _enriched(_dto(
          id: 6,
          goal: 'No deadline',
        )),
      ];
      const progress = {
        1: ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.earned,
        ),
        2: ChallengeProgress(
          challengeId: 2,
          state: ChallengeProgressState.none,
        ),
      };

      final bands = buildChallengeBands(
        challenges,
        now: now,
        progressForChallenge: (dto) => progress[dto.id],
      );

      expect(
          bands.map((b) => b.title).toList(), ['Today', 'This week', 'Season']);
      expect(bands[0].deadlineText, '3h left');
      expect(bands[0].cards.map((c) => c.title), ['Due today']);
      expect(bands[1].deadlineText, '3d left');
      expect(bands[1].cards.map((c) => c.title), ['Due this week']);
      expect(bands[2].deadlineText, '10d left');
      expect(
        bands[2].cards.map((c) => c.title).toList(),
        ['Old unfinished', 'Long haul', 'No deadline', 'Old completed'],
      );
    });

    test('keeps unfinished cards before completed cards inside a band', () {
      final challenges = [
        _enriched(_dto(
          id: 1,
          goal: 'Completed first',
          scheduleEnd: endsIn(const Duration(hours: 6)),
        )),
        _enriched(_dto(
          id: 2,
          goal: 'Open second',
          scheduleEnd: endsIn(const Duration(hours: 7)),
        )),
        _enriched(_dto(
          id: 3,
          goal: 'Completed third',
          scheduleEnd: endsIn(const Duration(hours: 8)),
        )),
      ];
      const progress = {
        1: ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.earned,
        ),
        2: ChallengeProgress(
          challengeId: 2,
          state: ChallengeProgressState.none,
        ),
        3: ChallengeProgress(
          challengeId: 3,
          state: ChallengeProgressState.earned,
        ),
      };

      final bands = buildChallengeBands(
        challenges,
        now: now,
        progressForChallenge: (dto) => progress[dto.id],
      );

      expect(bands.single.title, 'Today');
      expect(
        bands.single.cards.map((c) => c.title).toList(),
        ['Open second', 'Completed first', 'Completed third'],
      );
    });

    test('forwards technical success rate into compact produce-blocks card',
        () {
      final challenges = [
        const EnrichedChallenge(
          dto: ChallengeDto(
            id: 1,
            goal: 'Produce Every Block',
            task: 'Stay online.',
            category: 'technical',
            reward: '6500',
            enabled: true,
            completed: false,
            subCategory: kProduceBlocksSubCategory,
            scheduleEnd: '2026-06-16T18:00:00Z',
            metric: ChallengeMetric(kind: ChallengeMetricKind.percentage),
          ),
        ),
      ];

      final bands = buildChallengeBands(
        challenges,
        now: now,
        progressForChallenge: (_) => const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.inProgress,
          earnedPoints: 9050,
        ),
        technicalSuccessRateForChallenge: (_) => 23.2,
      );

      expect(bands.single.cards.single.leftText, '23% success');
      expect(
        bands.single.cards.single.railTreatment,
        AtomicChallengeRailTreatment.technicalOngoing,
      );
    });

    test('completed compact produce-blocks card uses completed rail treatment',
        () {
      final challenges = [
        const EnrichedChallenge(
          dto: ChallengeDto(
            id: 1,
            goal: 'Produce Every Block',
            task: 'Stay online.',
            category: 'technical',
            reward: '6500',
            enabled: true,
            completed: false,
            subCategory: kProduceBlocksSubCategory,
            scheduleEnd: '2026-06-16T18:00:00Z',
            metric: ChallengeMetric(kind: ChallengeMetricKind.percentage),
          ),
        ),
      ];

      final bands = buildChallengeBands(
        challenges,
        now: now,
        progressForChallenge: (_) => const ChallengeProgress(
          challengeId: 1,
          state: ChallengeProgressState.earned,
          earnedPoints: 9050,
        ),
        technicalSuccessRateForChallenge: (_) => 23.2,
      );

      expect(bands.single.cards.single.phase, AtomicChallengePhase.completed);
      expect(bands.single.cards.single.leftText, '23% success');
      expect(bands.single.cards.single.rightText, 'Earned 9,050 pts');
      expect(
        bands.single.cards.single.railTreatment,
        AtomicChallengeRailTreatment.checkbox,
      );
    });

    test('empty input yields no bands', () {
      expect(buildChallengeBands(const [], now: now), isEmpty);
    });
  });
}
