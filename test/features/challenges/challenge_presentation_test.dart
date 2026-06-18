import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
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
    enabled: true,
    completed: false,
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

AtomicChallengeRailTreatment _expectedRail(ChallengeVisualMetricType type) =>
    switch (type) {
      ChallengeVisualMetricType.binary => AtomicChallengeRailTreatment.checkbox,
      ChallengeVisualMetricType.technicalOngoing =>
        AtomicChallengeRailTreatment.technicalOngoing,
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
        ChallengeVisualUiPhase.open => null,
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
        ChallengeVisualUiPhase.open => 'Not done',
        ChallengeVisualUiPhase.inProgress => '2 / 5',
        ChallengeVisualUiPhase.pending ||
        ChallengeVisualUiPhase.completed =>
          '5 / 5',
      },
    ChallengeVisualMetricType.sum => switch (fixtureCase.phase) {
        ChallengeVisualUiPhase.open => 'Not done',
        ChallengeVisualUiPhase.inProgress => '40 / 100',
        ChallengeVisualUiPhase.pending ||
        ChallengeVisualUiPhase.completed =>
          '100 / 100',
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
  });

  group('mapToAtomicCard (visual matrix)', () {
    for (final fixtureCase in ChallengeUiVisualFixture.allCases) {
      test('${fixtureCase.metricType.name} ${fixtureCase.phase.name}', () {
        final card = mapToAtomicCard(
          _enriched(fixtureCase.challenge),
          progress: fixtureCase.progress,
        );

        expect(card.phase, _expectedPhase(fixtureCase.phase));
        expect(card.railTreatment, _expectedRail(fixtureCase.metricType));

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

  group('mapToAtomicCard (generic fallback, no progress)', () {
    test('no metric, no points → open checkbox with ceiling reward', () {
      final card = mapToAtomicCard(_enriched(_dto(reward: '500')));

      expect(card.railTreatment, AtomicChallengeRailTreatment.checkbox);
      expect(card.phase, AtomicChallengePhase.open);
      expect(card.leftText, 'Not done');
      expect(card.rightText, '500 pts');
    });
  });

  group('buildChallengeBands', () {
    final now = DateTime.utc(2026, 6, 16, 12);
    String endsIn(Duration d) => now.add(d).toIso8601String();

    test('groups into Featured / Today / This week / Season', () {
      final challenges = [
        _enriched(_dto(
            id: 1,
            goal: 'Featured one',
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
      ];

      final bands = buildChallengeBands(challenges, now: now);

      expect(bands.map((b) => b.title).toList(),
          ['Featured', 'Today', 'This week', 'Season']);
      expect(bands.first.cards.single.featured, isTrue);
      expect(bands.first.cards.single.title, 'Featured one');
      expect(bands[1].deadlineText, '5h left');
      expect(bands[2].deadlineText, '4d left');
      expect(bands[3].cards.single.title, 'Long haul');
    });

    test('empty input yields no bands', () {
      expect(buildChallengeBands(const [], now: now), isEmpty);
    });
  });
}
