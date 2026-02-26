import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_card.dart';
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
  );
}

BreakdownActivity _makeActivity({
  int id = 1,
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
  group('mapCategory', () {
    test('maps known categories', () {
      expect(mapCategory('technical'), ChallengeCategory.technical);
      expect(mapCategory('community'), ChallengeCategory.community);
      expect(mapCategory('flash'), ChallengeCategory.flash);
    });

    test('is case-insensitive', () {
      expect(mapCategory('TECHNICAL'), ChallengeCategory.technical);
      expect(mapCategory('Community'), ChallengeCategory.community);
      expect(mapCategory('Flash'), ChallengeCategory.flash);
    });

    test('falls back to technical for unknown values', () {
      expect(mapCategory('unknown'), ChallengeCategory.technical);
      expect(mapCategory(''), ChallengeCategory.technical);
    });
  });

  group('mapVariant', () {
    test('completed challenge → completed', () {
      expect(
        mapVariant(_makeDto(completed: true, enabled: true)),
        ChallengeCardVariant.completed,
      );
    });

    test('completed takes precedence over disabled', () {
      expect(
        mapVariant(_makeDto(completed: true, enabled: false)),
        ChallengeCardVariant.completed,
      );
    });

    test('disabled and not completed → missed', () {
      expect(
        mapVariant(_makeDto(enabled: false, completed: false)),
        ChallengeCardVariant.missed,
      );
    });

    test('enabled and not completed → active', () {
      expect(
        mapVariant(_makeDto(enabled: true, completed: false)),
        ChallengeCardVariant.active,
      );
    });
  });

  group('categorizeChallenges', () {
    test('splits challenges into correct buckets', () {
      final challenges = [
        _makeDto(enabled: true, completed: false),
        _makeDto(enabled: true, completed: true),
        _makeDto(enabled: false, completed: false),
        _makeDto(enabled: true, completed: false),
      ];

      final result = categorizeChallenges(challenges);
      expect(result.active, hasLength(2));
      expect(result.completed, hasLength(1));
      expect(result.missed, hasLength(1));
    });

    test('handles empty list', () {
      final result = categorizeChallenges(const []);
      expect(result.active, isEmpty);
      expect(result.completed, isEmpty);
      expect(result.missed, isEmpty);
    });
  });

  group('formatDateRange', () {
    test('formats valid ISO dates', () {
      expect(
        formatDateRange('2025-01-15T00:00:00Z', '2025-02-15T00:00:00Z'),
        'Jan 15 - Feb 15',
      );
    });

    test('handles null start', () {
      expect(
        formatDateRange(null, '2025-02-15T00:00:00Z'),
        'Feb 15',
      );
    });

    test('handles null end', () {
      expect(
        formatDateRange('2025-01-15T00:00:00Z', null),
        'Jan 15',
      );
    });

    test('returns empty for both null', () {
      expect(formatDateRange(null, null), '');
    });
  });

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
            id: 10,
            challengeId: 1,
            description: 'Produce Every Block',
            points: 6491),
        _makeActivity(
            id: 11,
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
        _makeActivity(id: 10, description: 'Produce Every Block', points: 6491),
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
            id: 10, challengeId: 1, description: 'Different Desc', points: 999),
      ];

      final enriched = enrichChallenges(challenges, activities);
      expect(enriched[0].participantCompleted, isTrue);
      expect(enriched[0].earnedPoints, 999);
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
      final activities = [_makeActivity(id: 10, description: null)];

      final enriched = enrichChallenges(challenges, activities);
      expect(enriched[0].participantCompleted, isFalse);
    });

    test('unmatched activities are ignored', () {
      final challenges = [_makeDto(id: 1, goal: 'Goal')];
      final activities = [
        _makeActivity(id: 10, description: 'Something Else'),
      ];

      final enriched = enrichChallenges(challenges, activities);
      expect(enriched[0].participantCompleted, isFalse);
    });
  });

  group('categorizeEnrichedChallenges', () {
    test('participant completed → completed tab', () {
      final enriched = [
        EnrichedChallenge(
          dto: _makeDto(id: 1, enabled: true, goal: 'Goal'),
          activity: _makeActivity(description: 'Goal'),
        ),
      ];
      final result = categorizeEnrichedChallenges(enriched);
      expect(result.completed, hasLength(1));
      expect(result.active, isEmpty);
      expect(result.missed, isEmpty);
    });

    test('not enabled + not completed → missed tab', () {
      final enriched = [
        EnrichedChallenge(dto: _makeDto(id: 1, enabled: false)),
      ];
      final result = categorizeEnrichedChallenges(enriched);
      expect(result.missed, hasLength(1));
      expect(result.active, isEmpty);
      expect(result.completed, isEmpty);
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

    test('participant completed overrides enabled=false (not missed)', () {
      final enriched = [
        EnrichedChallenge(
          dto: _makeDto(id: 1, enabled: false, goal: 'Goal'),
          activity: _makeActivity(description: 'Goal'),
        ),
      ];
      final result = categorizeEnrichedChallenges(enriched);
      expect(result.completed, hasLength(1));
      expect(result.missed, isEmpty);
    });

    test('enabled but scheduleEnd in the past → missed tab', () {
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
  });

  group('mapEnrichedVariant', () {
    test('participant completed → completed', () {
      expect(
        mapEnrichedVariant(EnrichedChallenge(
          dto: _makeDto(enabled: true, goal: 'Goal'),
          activity: _makeActivity(description: 'Goal'),
        )),
        ChallengeCardVariant.completed,
      );
    });

    test('not enabled + not completed → missed', () {
      expect(
        mapEnrichedVariant(EnrichedChallenge(
          dto: _makeDto(enabled: false),
        )),
        ChallengeCardVariant.missed,
      );
    });

    test('enabled + not completed → active', () {
      expect(
        mapEnrichedVariant(EnrichedChallenge(
          dto: _makeDto(enabled: true),
        )),
        ChallengeCardVariant.active,
      );
    });

    test('participant completed overrides not-enabled', () {
      expect(
        mapEnrichedVariant(EnrichedChallenge(
          dto: _makeDto(enabled: false, goal: 'Goal'),
          activity: _makeActivity(description: 'Goal'),
        )),
        ChallengeCardVariant.completed,
      );
    });

    test('enabled but scheduleEnd in the past → missed', () {
      final pastEnd = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      expect(
        mapEnrichedVariant(EnrichedChallenge(
          dto: _makeDto(enabled: true, scheduleEnd: pastEnd),
        )),
        ChallengeCardVariant.missed,
      );
    });

    test('enabled with future scheduleEnd → active', () {
      final futureEnd =
          DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String();
      expect(
        mapEnrichedVariant(EnrichedChallenge(
          dto: _makeDto(enabled: true, scheduleEnd: futureEnd),
        )),
        ChallengeCardVariant.active,
      );
    });
  });

  group('formatEarnedPoints', () {
    test('formats with comma grouping and pts suffix', () {
      expect(formatEarnedPoints(6491), '6,491 pts');
      expect(formatEarnedPoints(1000000), '1,000,000 pts');
      expect(formatEarnedPoints(0), '0 pts');
      expect(formatEarnedPoints(500), '500 pts');
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

  group('isProduceBlocksReward', () {
    test('returns true for "Up to" prefixed strings', () {
      expect(isProduceBlocksReward('Up to 6,500 pts'), isTrue);
      expect(isProduceBlocksReward('up to 500 pts'), isTrue);
    });

    test('returns false for plain number strings', () {
      expect(isProduceBlocksReward('1000'), isFalse);
      expect(isProduceBlocksReward('6500'), isFalse);
    });

    test('returns false for non-"Up to" text', () {
      expect(isProduceBlocksReward('Fixed 500 pts'), isFalse);
      expect(isProduceBlocksReward(''), isFalse);
    });
  });

  group('formatRankOrdinal', () {
    test('formats 1–3 as ordinals', () {
      expect(formatRankOrdinal(1), '1st');
      expect(formatRankOrdinal(2), '2nd');
      expect(formatRankOrdinal(3), '3rd');
    });

    test('returns null for null', () {
      expect(formatRankOrdinal(null), isNull);
    });

    test('returns null for ranks outside 1–3', () {
      expect(formatRankOrdinal(0), isNull);
      expect(formatRankOrdinal(4), isNull);
      expect(formatRankOrdinal(-1), isNull);
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

  group('formatDiffLabel', () {
    test('>= 24h returns "Last 24h"', () {
      expect(formatDiffLabel(const Duration(hours: 24)), 'Last 24h');
      expect(formatDiffLabel(const Duration(hours: 36)), 'Last 24h');
    });

    test('>= 1h returns "Last Xh"', () {
      expect(formatDiffLabel(const Duration(hours: 3)), 'Last 3h');
      expect(formatDiffLabel(const Duration(hours: 1)), 'Last 1h');
      expect(
        formatDiffLabel(const Duration(hours: 23, minutes: 59)),
        'Last 23h',
      );
    });

    test('>= 5m returns "Last Xm"', () {
      expect(formatDiffLabel(const Duration(minutes: 30)), 'Last 30m');
      expect(formatDiffLabel(const Duration(minutes: 5)), 'Last 5m');
    });

    test('< 5m returns "Last 24h" fallback', () {
      expect(formatDiffLabel(const Duration(minutes: 4)), 'Last 24h');
      expect(formatDiffLabel(const Duration(seconds: 30)), 'Last 24h');
      expect(formatDiffLabel(Duration.zero), 'Last 24h');
    });
  });
}
