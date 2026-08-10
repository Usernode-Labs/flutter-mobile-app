import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';

ChallengeDto _makeDto({
  int id = 1,
  bool enabled = true,
  bool completed = false,
  String category = 'technical',
  String goal = 'Goal',
  String reward = '1000',
  String? scheduleStart,
  String? scheduleEnd,
  String? subCategory,
}) {
  return ChallengeDto(
    id: id,
    category: category,
    goal: goal,
    task: 'Task',
    reward: reward,
    enabled: enabled,
    completed: completed,
    scheduleStart: scheduleStart,
    scheduleEnd: scheduleEnd,
    subCategory: subCategory,
  );
}

BreakdownActivity _makeActivity({
  String id = '1',
  int points = 100,
  String? description,
  int? challengeId,
}) {
  return BreakdownActivity(
    id: id,
    activityType: 'challenge_completed',
    points: points,
    description: description,
    challengeId: challengeId,
  );
}

void main() {
  group('formatPoints', () {
    test('formats with comma grouping', () {
      expect(formatPoints(8000), '8,000');
      expect(formatPoints(1000000), '1,000,000');
      expect(formatPoints(500), '500');
      expect(formatPoints(0), '0');
    });
  });

  // -------------------------------------------------------------------------
  // Enrichment
  // -------------------------------------------------------------------------

  group('enrichChallenges', () {
    test('matches by challengeId when available', () {
      final challenges = [
        _makeDto(id: 1, goal: 'Produce Every Block'),
        _makeDto(id: 2, goal: 'Report a Bug'),
        _makeDto(id: 3, goal: 'Feedback Survey'),
      ];
      final activities = [
        _makeActivity(
            id: '10',
            challengeId: 1,
            description: 'Produce Every Block',
            points: 6491),
        _makeActivity(
            id: '11',
            challengeId: 3,
            description: 'Feedback Survey',
            points: 500),
      ];

      final enriched = enrichChallenges(challenges, activities);
      expect(enriched, hasLength(3));
      expect(enriched[0].participantCompleted, isTrue);
      expect(enriched[0].earnedPoints, 6491);
      expect(enriched[1].participantCompleted, isFalse);
      expect(enriched[1].earnedPoints, isNull);
      expect(enriched[2].participantCompleted, isTrue);
      expect(enriched[2].earnedPoints, 500);
    });

    test('falls back to description matching when challengeId is null', () {
      final challenges = [
        _makeDto(id: 1, goal: 'Produce Every Block'),
        _makeDto(id: 2, goal: 'Report a Bug'),
      ];
      final activities = [
        _makeActivity(
            id: '10', description: 'Produce Every Block', points: 6491),
      ];

      final enriched = enrichChallenges(challenges, activities);
      expect(enriched[0].participantCompleted, isTrue);
      expect(enriched[0].earnedPoints, 6491);
      expect(enriched[1].participantCompleted, isFalse);
    });

    test('challengeId match takes precedence over description match', () {
      final challenges = [
        _makeDto(id: 1, goal: 'Goal A'),
      ];
      // Activity has challengeId=1 but description doesn't match goal
      final activities = [
        _makeActivity(
            id: '10',
            challengeId: 1,
            description: 'Different Desc',
            points: 999),
      ];

      final enriched = enrichChallenges(challenges, activities);
      expect(enriched[0].participantCompleted, isTrue);
      expect(enriched[0].earnedPoints, 999);
    });

    test(
        'prefers primary activity over extra-point when both share challengeId',
        () {
      final challenges = [
        _makeDto(
            id: 1,
            goal: 'Produce Every Block',
            subCategory: 'PRODUCE_BLOCKS_CHALLENGE'),
      ];
      final activities = [
        _makeActivity(
            id: '10', challengeId: 1, points: 4166), // regular epoch activity
        _makeActivity(
            id: 'extra-point-42', challengeId: 1, points: 125), // extra points
      ];

      final enriched = enrichChallenges(challenges, activities);
      expect(enriched[0].participantCompleted, isTrue);
      // Should pick the regular activity, not the extra-point one
      expect(enriched[0].activity!.id, '10');
      expect(enriched[0].activity!.points, 4166);
      // earnedPoints includes extra points
      expect(enriched[0].earnedPoints, 4291);
      expect(enriched[0].extraPoints, 125);
    });

    test('uses extra points when no regular activity exists', () {
      final challenges = [
        _makeDto(
            id: 1,
            goal: 'Produce Every Block',
            subCategory: 'PRODUCE_BLOCKS_CHALLENGE'),
      ];
      final activities = [
        _makeActivity(id: 'extra-point-42', challengeId: 1, points: 125),
      ];

      final enriched = enrichChallenges(challenges, activities);
      // No primary activity, but extra points still contribute
      expect(enriched[0].activity, isNull);
      expect(enriched[0].extraPoints, 125);
      expect(enriched[0].earnedPoints, 125);
    });

    test('null activities wraps all with activity: null', () {
      final challenges = [
        _makeDto(id: 1, goal: 'A'),
        _makeDto(id: 2, goal: 'B'),
      ];
      final enriched = enrichChallenges(challenges, null);
      expect(enriched, hasLength(2));
      expect(enriched.every((e) => !e.participantCompleted), isTrue);
    });

    test('activities without description or challengeId are skipped', () {
      final challenges = [_makeDto(id: 1, goal: 'Goal')];
      final activities = [_makeActivity(id: '10', description: null)];

      final enriched = enrichChallenges(challenges, activities);
      expect(enriched[0].participantCompleted, isFalse);
    });

    test('unmatched activities are ignored', () {
      final challenges = [_makeDto(id: 1, goal: 'Goal')];
      final activities = [
        _makeActivity(id: '10', description: 'Something Else'),
      ];

      final enriched = enrichChallenges(challenges, activities);
      expect(enriched[0].participantCompleted, isFalse);
    });
  });

  group('categorizeEnrichedChallenges', () {
    test('activity present but not completed/expired → active tab', () {
      final enriched = [
        EnrichedChallenge(
          dto: _makeDto(id: 1, enabled: true, goal: 'Goal'),
          activity: _makeActivity(description: 'Goal'),
        ),
      ];
      final result = categorizeEnrichedChallenges(enriched);
      expect(result.active, hasLength(1));
      expect(result.completed, isEmpty);
      expect(result.missed, isEmpty);
    });

    test('not enabled → dropped (not in any bucket)', () {
      final enriched = [
        EnrichedChallenge(dto: _makeDto(id: 1, enabled: false)),
      ];
      final result = categorizeEnrichedChallenges(enriched);
      expect(result.active, isEmpty);
      expect(result.completed, isEmpty);
      expect(result.missed, isEmpty);
    });

    test('enabled + not completed → active tab', () {
      final enriched = [
        EnrichedChallenge(dto: _makeDto(id: 1, enabled: true)),
      ];
      final result = categorizeEnrichedChallenges(enriched);
      expect(result.active, hasLength(1));
      expect(result.completed, isEmpty);
      expect(result.missed, isEmpty);
    });

    test('disabled challenge with earned points (not over) → missed tab', () {
      final enriched = [
        EnrichedChallenge(
          dto: _makeDto(id: 1, enabled: false, goal: 'Goal'),
          activity: _makeActivity(description: 'Goal'),
        ),
      ];
      final result = categorizeEnrichedChallenges(enriched);
      expect(result.missed, hasLength(1));
      expect(result.active, isEmpty);
      expect(result.completed, isEmpty);
    });

    test('expired with no points won → missed tab', () {
      final pastEnd = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      final enriched = [
        EnrichedChallenge(
          dto: _makeDto(id: 1, enabled: true, scheduleEnd: pastEnd),
        ),
      ];
      final result = categorizeEnrichedChallenges(enriched);
      expect(result.missed, hasLength(1));
      expect(result.completed, isEmpty);
      expect(result.active, isEmpty);
    });

    test('expired with points won → completed tab', () {
      final pastEnd = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      final enriched = [
        EnrichedChallenge(
          dto: _makeDto(
              id: 1, enabled: true, scheduleEnd: pastEnd, goal: 'Goal'),
          activity: _makeActivity(description: 'Goal'),
        ),
      ];
      final result = categorizeEnrichedChallenges(enriched);
      expect(result.completed, hasLength(1));
      expect(result.missed, isEmpty);
      expect(result.active, isEmpty);
    });

    test('enabled with future scheduleEnd → active tab', () {
      final futureEnd =
          DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String();
      final enriched = [
        EnrichedChallenge(
          dto: _makeDto(id: 1, enabled: true, scheduleEnd: futureEnd),
        ),
      ];
      final result = categorizeEnrichedChallenges(enriched);
      expect(result.active, hasLength(1));
      expect(result.missed, isEmpty);
    });

    test('bare datetime scheduleEnd treated as UTC (real API format)', () {
      // "2020-01-01 00:00:00" without Z — must be treated as UTC (in the past),
      // so the challenge is over. No points won → missed.
      final enriched = [
        EnrichedChallenge(
          dto: _makeDto(
              id: 1, enabled: true, scheduleEnd: '2020-01-01 00:00:00'),
        ),
      ];
      final result = categorizeEnrichedChallenges(enriched);
      expect(result.missed, hasLength(1));
      expect(result.active, isEmpty);
    });

    test('enabled with null scheduleEnd → active tab', () {
      final enriched = [
        EnrichedChallenge(
          dto: _makeDto(id: 1, enabled: true, scheduleEnd: null),
        ),
      ];
      final result = categorizeEnrichedChallenges(enriched);
      expect(result.active, hasLength(1));
      expect(result.missed, isEmpty);
    });

    test('completed overrides expired scheduleEnd', () {
      final pastEnd = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      final enriched = [
        EnrichedChallenge(
          dto: _makeDto(
              id: 1, enabled: true, scheduleEnd: pastEnd, goal: 'Goal'),
          activity: _makeActivity(description: 'Goal'),
        ),
      ];
      final result = categorizeEnrichedChallenges(enriched);
      expect(result.completed, hasLength(1));
      expect(result.missed, isEmpty);
    });

    test('produce-blocks pinned to front of each bucket', () {
      final enriched = [
        EnrichedChallenge(dto: _makeDto(id: 1, enabled: true)),
        EnrichedChallenge(
          dto: _makeDto(
              id: 2, enabled: true, subCategory: 'PRODUCE_BLOCKS_CHALLENGE'),
        ),
        EnrichedChallenge(dto: _makeDto(id: 3, enabled: true)),
      ];
      final result = categorizeEnrichedChallenges(enriched);
      expect(result.active.first.dto.id, 2);
      expect(result.active.map((c) => c.dto.id).toList(), [2, 1, 3]);
    });
  });

  group('parseRewardCeiling', () {
    test('parses "Up to 6,500 pts"', () {
      expect(parseRewardCeiling('Up to 6,500 pts'), 6500);
    });

    test('parses "Up to 10,000 pts"', () {
      expect(parseRewardCeiling('Up to 10,000 pts'), 10000);
    });

    test('parses "up to 500 pts" (lowercase)', () {
      expect(parseRewardCeiling('up to 500 pts'), 500);
    });

    test('returns null for plain number strings', () {
      expect(parseRewardCeiling('1000'), isNull);
      expect(parseRewardCeiling('6500'), isNull);
    });

    test('returns null for empty string', () {
      expect(parseRewardCeiling(''), isNull);
    });
  });

  group('isProduceBlocksChallenge', () {
    test('returns true when subCategory is PRODUCE_BLOCKS_CHALLENGE', () {
      final dto = _makeDto(subCategory: 'PRODUCE_BLOCKS_CHALLENGE');
      expect(isProduceBlocksChallenge(dto), isTrue);
    });

    test('returns false for other subCategories', () {
      expect(isProduceBlocksChallenge(_makeDto(subCategory: 'OTHER')), isFalse);
      expect(isProduceBlocksChallenge(_makeDto()), isFalse);
    });
  });

  group('ChallengeDto.fromJson', () {
    Map<String, dynamic> baseJson({
      Object id = 42,
      Object reward = 8000,
      Object? eventId,
    }) =>
        {
          'id': id,
          'category': 'technical',
          'goal': 'Run a node',
          'task': 'Keep uptime above 90%',
          'reward': reward,
          'enabled': true,
          'completed': false,
          if (eventId != null) 'event_id': eventId,
        };

    test('parses numeric values as int', () {
      final dto = ChallengeDto.fromJson(baseJson(id: 42, reward: 8000));
      expect(dto.id, 42);
      expect(dto.reward, '8000');
    });

    test('parses string-encoded numeric values', () {
      final dto = ChallengeDto.fromJson(baseJson(id: '42', reward: '8000'));
      expect(dto.id, 42);
      expect(dto.reward, '8000');
    });

    test('parses nullable string-encoded numeric values', () {
      final dto = ChallengeDto.fromJson(baseJson(reward: '500', eventId: '7'));
      expect(dto.reward, '500');
      expect(dto.eventId, 7);
    });

    test('nullable field remains null when absent', () {
      final dto = ChallengeDto.fromJson(baseJson());
      expect(dto.eventId, isNull);
    });

    test('toJson round-trip produces equivalent DTO', () {
      final original = ChallengeDto.fromJson(baseJson(id: '1', reward: '9999'));
      final roundTripped = ChallengeDto.fromJson(original.toJson());
      expect(roundTripped.id, original.id);
      expect(roundTripped.reward, original.reward);
      expect(roundTripped.category, original.category);
    });
  });

  group('kProduceBlocksSubCategory', () {
    test('is PRODUCE_BLOCKS_CHALLENGE', () {
      expect(kProduceBlocksSubCategory, 'PRODUCE_BLOCKS_CHALLENGE');
    });
  });
}
