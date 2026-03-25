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
    test('splits challenges into correct buckets (disabled are dropped)', () {
      final challenges = [
        _makeDto(enabled: true, completed: false),
        _makeDto(enabled: true, completed: true),
        _makeDto(enabled: false, completed: false),
        _makeDto(enabled: true, completed: false),
      ];

      final result = categorizeChallenges(challenges);
      expect(result.active, hasLength(2));
      expect(result.completed, hasLength(1));
      expect(result.missed, hasLength(0));
    });

    test('handles empty list', () {
      final result = categorizeChallenges(const []);
      expect(result.active, isEmpty);
      expect(result.completed, isEmpty);
      expect(result.missed, isEmpty);
    });
  });

  group('formatDateRange', () {
    test('formats valid ISO dates with Z suffix', () {
      // Z-suffixed strings are already UTC — toLocal() converts for display.
      // Use a date where UTC→local won't shift the day for most timezones.
      final result =
          formatDateRange('2025-01-15T12:00:00Z', '2025-02-15T12:00:00Z');
      expect(result, contains('Jan'));
      expect(result, contains('Feb'));
      expect(result, contains(' - '));
    });

    test('treats bare datetimes as UTC (real API format)', () {
      final result =
          formatDateRange('2025-01-15 12:00:00', '2025-02-15 12:00:00');
      expect(result, contains('Jan'));
      expect(result, contains('Feb'));
      expect(result, contains(' - '));
    });

    test('handles null start', () {
      final result = formatDateRange(null, '2025-02-15T12:00:00Z');
      expect(result, contains('Feb'));
    });

    test('handles null end', () {
      final result = formatDateRange('2025-01-15T12:00:00Z', null);
      expect(result, contains('Jan'));
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

    test('disabled challenge is dropped even if participant completed', () {
      final enriched = [
        EnrichedChallenge(
          dto: _makeDto(id: 1, enabled: false, goal: 'Goal'),
          activity: _makeActivity(description: 'Goal'),
        ),
      ];
      final result = categorizeEnrichedChallenges(enriched);
      expect(result.active, isEmpty);
      expect(result.completed, isEmpty);
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

    test('bare datetime scheduleEnd treated as UTC (real API format)', () {
      // "2020-01-01 00:00:00" without Z — must be treated as UTC (in the past).
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

    test('active produce-blocks without earned points → active', () {
      expect(
        mapEnrichedVariant(EnrichedChallenge(
          dto: _makeDto(enabled: true, subCategory: 'PRODUCE_BLOCKS_CHALLENGE'),
        )),
        ChallengeCardVariant.active,
      );
    });

    test('active produce-blocks with earned points → ongoing', () {
      expect(
        mapEnrichedVariant(EnrichedChallenge(
          dto: _makeDto(
            enabled: true,
            subCategory: 'PRODUCE_BLOCKS_CHALLENGE',
            goal: 'Produce Every Block',
          ),
          activity: _makeActivity(
              challengeId: 1, description: 'Produce Every Block', points: 500),
        )),
        ChallengeCardVariant.ongoing,
      );
    });

    test('completed produce-blocks → completed (not ongoing)', () {
      expect(
        mapEnrichedVariant(EnrichedChallenge(
          dto: _makeDto(
            enabled: true,
            completed: true,
            subCategory: 'PRODUCE_BLOCKS_CHALLENGE',
            goal: 'Produce Every Block',
          ),
          activity: _makeActivity(description: 'Produce Every Block'),
        )),
        ChallengeCardVariant.completed,
      );
    });

    test(
        'active produce-blocks without activity but with eventSuccessRate > 0 → ongoing',
        () {
      expect(
        mapEnrichedVariant(
          EnrichedChallenge(
            dto: _makeDto(
              enabled: true,
              subCategory: 'PRODUCE_BLOCKS_CHALLENGE',
            ),
          ),
          eventSuccessRate: 85.0,
        ),
        ChallengeCardVariant.ongoing,
      );
    });

    test(
        'active produce-blocks without activity and eventSuccessRate == 0 → active',
        () {
      expect(
        mapEnrichedVariant(
          EnrichedChallenge(
            dto: _makeDto(
              enabled: true,
              subCategory: 'PRODUCE_BLOCKS_CHALLENGE',
            ),
          ),
          eventSuccessRate: 0,
        ),
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

  group('kProduceBlocksSubCategory', () {
    test('is PRODUCE_BLOCKS_CHALLENGE', () {
      expect(kProduceBlocksSubCategory, 'PRODUCE_BLOCKS_CHALLENGE');
    });
  });

  group('isProduceBlocksSyncing', () {
    test('true when earnedPoints is null and successRate > 0', () {
      expect(
        isProduceBlocksSyncing(
          isProduceBlocks: true,
          earnedPoints: null,
          successRate: 83.33,
        ),
        isTrue,
      );
    });

    test('true when earnedPoints is 0 and successRate > 0 (aggregator gap)',
        () {
      expect(
        isProduceBlocksSyncing(
          isProduceBlocks: true,
          earnedPoints: 0,
          successRate: 50.0,
        ),
        isTrue,
      );
    });

    test('false when earnedPoints > 0', () {
      expect(
        isProduceBlocksSyncing(
          isProduceBlocks: true,
          earnedPoints: 4166,
          successRate: 83.33,
        ),
        isFalse,
      );
    });

    test('false when successRate is 0 (no blocks produced yet)', () {
      expect(
        isProduceBlocksSyncing(
          isProduceBlocks: true,
          earnedPoints: null,
          successRate: 0,
        ),
        isFalse,
      );
    });

    test('false when not a produce-blocks challenge', () {
      expect(
        isProduceBlocksSyncing(
          isProduceBlocks: false,
          earnedPoints: null,
          successRate: 83.33,
        ),
        isFalse,
      );
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
