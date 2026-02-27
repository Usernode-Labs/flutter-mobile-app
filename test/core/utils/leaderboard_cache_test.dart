import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/utils/leaderboard_cache.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ---------------------------------------------------------------------------
  // CachedData
  // ---------------------------------------------------------------------------

  group('CachedData', () {
    test('staleness is null when lastUpdated is null', () {
      const cd = CachedData(data: 42, isCached: true);
      expect(cd.staleness, isNull);
    });

    test('staleness returns a non-negative duration for a past timestamp', () {
      final past = DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 5))
          .toIso8601String();
      final cd = CachedData(data: 42, isCached: false, lastUpdated: past);
      expect(cd.staleness, isNotNull);
      expect(cd.staleness!.inMinutes, greaterThanOrEqualTo(4));
    });

    test('copyWith replaces specified fields', () {
      const cd = CachedData(data: 1, isCached: true, lastUpdated: '2025-01-01');
      final cd2 = cd.copyWith(data: 2, isCached: false);
      expect(cd2.data, 2);
      expect(cd2.isCached, false);
      expect(cd2.lastUpdated, '2025-01-01');
    });
  });

  // ---------------------------------------------------------------------------
  // LeaderboardCache.read / write
  // ---------------------------------------------------------------------------

  group('LeaderboardCache', () {
    test('read returns null when nothing is cached', () async {
      final result = await LeaderboardCache.read<RankingResult>(
        type: 'ranking',
        seasonId: 1,
        fromJson: (json) =>
            RankingResult.fromJson(json as Map<String, dynamic>),
      );
      expect(result, isNull);
    });

    test('write then read round-trips a RankingResult', () async {
      final original = RankingResult.fromJson({
        'scope': 'season',
        'rank': 3,
        'total_points': 5000,
        'offchain_points': 1000,
        'total_participants': 2000,
        'season_id': 1,
        'season_name': 'Season 1',
        'phases_participated': 4,
        'total_produced_blocks': 25,
      });

      await LeaderboardCache.write(
        type: 'ranking',
        seasonId: 1,
        toJson: () => original.toJson(),
      );

      final snapshot = await LeaderboardCache.read<RankingResult>(
        type: 'ranking',
        seasonId: 1,
        fromJson: (json) =>
            RankingResult.fromJson(json as Map<String, dynamic>),
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.data.scope, 'season');
      expect(snapshot.data.rank, 3);
      expect(snapshot.data.totalPoints, 5000);
      expect(snapshot.data.seasonId, 1);
      expect(DateTime.tryParse(snapshot.updatedAt), isNotNull);
    });

    test('write then read round-trips a List<ChallengeDto>', () async {
      final challenges = [
        ChallengeDto.fromJson({
          'id': 1,
          'category': 'social',
          'goal': 'Share',
          'task': 'Social',
          'reward': 100,
          'enabled': true,
          'completed': false,
        }),
        ChallengeDto.fromJson({
          'id': 2,
          'category': 'block_production',
          'goal': 'Produce',
          'task': 'Blocks',
          'reward': 500,
          'enabled': true,
          'completed': true,
        }),
      ];

      await LeaderboardCache.write(
        type: 'challenges',
        seasonId: 1,
        eventId: 5,
        toJson: () => challenges.map((c) => c.toJson()).toList(),
      );

      final snapshot = await LeaderboardCache.read<List<ChallengeDto>>(
        type: 'challenges',
        seasonId: 1,
        eventId: 5,
        fromJson: (json) => (json as List)
            .map((e) => ChallengeDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.data, hasLength(2));
      expect(snapshot.data.first.id, 1);
      expect(snapshot.data.last.completed, true);
    });

    test('different keys do not collide', () async {
      final r1 = RankingResult.fromJson({
        'scope': 'season',
        'rank': 1,
        'total_points': 100,
        'offchain_points': 0,
        'total_participants': 10,
        'season_id': 1,
      });
      final r2 = RankingResult.fromJson({
        'scope': 'season',
        'rank': 2,
        'total_points': 200,
        'offchain_points': 0,
        'total_participants': 10,
        'season_id': 2,
      });

      await LeaderboardCache.write(
        type: 'ranking',
        seasonId: 1,
        toJson: () => r1.toJson(),
      );
      await LeaderboardCache.write(
        type: 'ranking',
        seasonId: 2,
        toJson: () => r2.toJson(),
      );

      final s1 = await LeaderboardCache.read<RankingResult>(
        type: 'ranking',
        seasonId: 1,
        fromJson: (json) =>
            RankingResult.fromJson(json as Map<String, dynamic>),
      );
      final s2 = await LeaderboardCache.read<RankingResult>(
        type: 'ranking',
        seasonId: 2,
        fromJson: (json) =>
            RankingResult.fromJson(json as Map<String, dynamic>),
      );

      expect(s1!.data.rank, 1);
      expect(s2!.data.rank, 2);
    });

    test('page parameter differentiates cache keys', () async {
      final result = LeaderboardResult.fromJson({
        'season': {'id': 1, 'name': 'S1'},
        'events': <dynamic>[],
        'entries': <dynamic>[],
        'pagination': {
          'page': 1,
          'per_page': 50,
          'total': 0,
          'total_pages': 1,
        },
      });

      await LeaderboardCache.write(
        type: 'leaderboard',
        seasonId: 1,
        page: 1,
        toJson: () => result.toJson(),
      );

      // Different page key returns null
      final miss = await LeaderboardCache.read<LeaderboardResult>(
        type: 'leaderboard',
        seasonId: 1,
        page: 2,
        fromJson: (json) =>
            LeaderboardResult.fromJson(json as Map<String, dynamic>),
      );
      expect(miss, isNull);

      // Same page key returns data
      final hit = await LeaderboardCache.read<LeaderboardResult>(
        type: 'leaderboard',
        seasonId: 1,
        page: 1,
        fromJson: (json) =>
            LeaderboardResult.fromJson(json as Map<String, dynamic>),
      );
      expect(hit, isNotNull);
    });

    test('read returns null for corrupt data', () async {
      final prefs = await SharedPreferences.getInstance();
      // Write raw garbage under the expected key pattern
      await prefs.setString(
        'testnet:leaderboard:ranking:s1',
        'not valid json at all',
      );

      final result = await LeaderboardCache.read<RankingResult>(
        type: 'ranking',
        seasonId: 1,
        fromJson: (json) =>
            RankingResult.fromJson(json as Map<String, dynamic>),
      );
      expect(result, isNull);
    });

    test('updatedAt timestamp is close to now', () async {
      final before = DateTime.now().toUtc();

      await LeaderboardCache.write(
        type: 'ranking',
        seasonId: 1,
        toJson: () => RankingResult.fromJson({
          'scope': 'global',
          'rank': 1,
          'total_points': 0,
          'offchain_points': 0,
          'total_participants': 1,
        }).toJson(),
      );

      final after = DateTime.now().toUtc();

      final snapshot = await LeaderboardCache.read<RankingResult>(
        type: 'ranking',
        seasonId: 1,
        fromJson: (json) =>
            RankingResult.fromJson(json as Map<String, dynamic>),
      );

      final updatedAt = DateTime.parse(snapshot!.updatedAt);
      expect(updatedAt.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
      expect(updatedAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });
}
