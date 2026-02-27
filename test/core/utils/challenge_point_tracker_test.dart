import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/utils/challenge_point_tracker.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ChallengePointTracker', () {
    test('getDiff24h returns null when no snapshots exist', () async {
      final diff = await ChallengePointTracker.getDiff24h('test_key');
      expect(diff, isNull);
    });

    test('getDiff24h returns null when only recent snapshots exist', () async {
      // Record a single recent snapshot — no 24h-old baseline exists
      await ChallengePointTracker.record('test_key', 100);
      final diff = await ChallengePointTracker.getDiff24h('test_key');
      expect(diff, isNull);
    });

    test('getDiff24h computes diff when a 24h-old snapshot exists', () async {
      // Seed a snapshot 25 hours ago directly in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final oldT = now - const Duration(hours: 25).inSeconds;
      final key = 'testnet:challenge_pts:test_key';
      await prefs.setString(
        key,
        jsonEncode([
          {'p': 50, 't': oldT},
        ]),
      );

      // Record current snapshot
      await ChallengePointTracker.record('test_key', 150);

      final diff = await ChallengePointTracker.getDiff24h('test_key');
      expect(diff, 100); // 150 - 50
    });

    test('record prunes entries older than 48 hours', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final key = 'testnet:challenge_pts:prune_key';

      // Seed an entry 50 hours ago (should be pruned) and one 23 hours ago
      await prefs.setString(
        key,
        jsonEncode([
          {'p': 10, 't': now - const Duration(hours: 50).inSeconds},
          {'p': 20, 't': now - const Duration(hours: 23).inSeconds},
        ]),
      );

      await ChallengePointTracker.record('prune_key', 30);

      // Read raw data to verify pruning
      final raw = prefs.getString(key)!;
      final entries = jsonDecode(raw) as List;
      // The 50h-old entry should be pruned, leaving the 23h entry + new one
      expect(entries, hasLength(2));
      expect((entries.first as Map)['p'], 20);
      expect((entries.last as Map)['p'], 30);
    });

    test('getDiffSince returns null when no baseline exists', () async {
      await ChallengePointTracker.record('since_key', 100);
      final since = await ChallengePointTracker.getDiffSince('since_key');
      expect(since, isNull);
    });

    test('getDiffSince returns baseline timestamp', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final oldT = now - const Duration(hours: 25).inSeconds;
      final key = 'testnet:challenge_pts:since_key2';
      await prefs.setString(
        key,
        jsonEncode([
          {'p': 50, 't': oldT},
          {'p': 100, 't': now},
        ]),
      );

      final since = await ChallengePointTracker.getDiffSince('since_key2');
      expect(since, isNotNull);
      // Should be approximately 25 hours ago
      final diff = DateTime.now().toUtc().difference(since!);
      expect(diff.inHours, greaterThanOrEqualTo(24));
      expect(diff.inHours, lessThanOrEqualTo(26));
    });

    test('getDiff24h handles corrupt data gracefully', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'testnet:challenge_pts:corrupt_key',
        'not valid json',
      );
      final diff = await ChallengePointTracker.getDiff24h('corrupt_key');
      expect(diff, isNull);
    });

    test('different keys do not collide', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final oldT = now - const Duration(hours: 25).inSeconds;

      await prefs.setString(
        'testnet:challenge_pts:key_a',
        jsonEncode([
          {'p': 100, 't': oldT},
          {'p': 200, 't': now},
        ]),
      );
      await prefs.setString(
        'testnet:challenge_pts:key_b',
        jsonEncode([
          {'p': 50, 't': oldT},
          {'p': 75, 't': now},
        ]),
      );

      final diffA = await ChallengePointTracker.getDiff24h('key_a');
      final diffB = await ChallengePointTracker.getDiff24h('key_b');
      expect(diffA, 100); // 200 - 100
      expect(diffB, 25); // 75 - 50
    });
  });

  group('getDiffBestEffort', () {
    test('returns null when no entries exist', () async {
      final diff = await ChallengePointTracker.getDiffBestEffort('empty_key');
      expect(diff, isNull);
    });

    test('returns null when only 1 entry exists', () async {
      await ChallengePointTracker.record('single_key', 100);
      final diff = await ChallengePointTracker.getDiffBestEffort('single_key');
      expect(diff, isNull);
    });

    test('returns diff from earliest when < 24h data with 2+ entries',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final threeHoursAgo = now - const Duration(hours: 3).inSeconds;
      final key = 'testnet:challenge_pts:best_effort_short';

      await prefs.setString(
        key,
        jsonEncode([
          {'p': 100, 't': threeHoursAgo},
          {'p': 150, 't': now},
        ]),
      );

      final diff = await ChallengePointTracker.getDiffBestEffort(
        'best_effort_short',
      );
      expect(diff, isNotNull);
      expect(diff!.points, 50); // 150 - 100
      expect(diff.since.inHours, greaterThanOrEqualTo(2));
      expect(diff.since.inHours, lessThanOrEqualTo(4));
    });

    test('uses 24h baseline when >= 24h snapshot exists', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final twentyFiveHoursAgo = now - const Duration(hours: 25).inSeconds;
      final twelveHoursAgo = now - const Duration(hours: 12).inSeconds;
      final key = 'testnet:challenge_pts:best_effort_24h';

      await prefs.setString(
        key,
        jsonEncode([
          {'p': 50, 't': twentyFiveHoursAgo},
          {'p': 100, 't': twelveHoursAgo},
          {'p': 200, 't': now},
        ]),
      );

      final diff = await ChallengePointTracker.getDiffBestEffort(
        'best_effort_24h',
      );
      expect(diff, isNotNull);
      // Should use the 25h-old entry as baseline, not the earliest
      expect(diff!.points, 150); // 200 - 50
      expect(diff.since.inHours, greaterThanOrEqualTo(24));
    });

    test('clamps negative diffs to zero', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final twoHoursAgo = now - const Duration(hours: 2).inSeconds;
      final key = 'testnet:challenge_pts:best_effort_negative';

      // Points decreased (e.g. backend correction)
      await prefs.setString(
        key,
        jsonEncode([
          {'p': 200, 't': twoHoursAgo},
          {'p': 150, 't': now},
        ]),
      );

      final diff = await ChallengePointTracker.getDiffBestEffort(
        'best_effort_negative',
      );
      expect(diff, isNotNull);
      expect(diff!.points, 0); // clamped from -50
    });

    test('handles corrupt data gracefully', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'testnet:challenge_pts:best_effort_corrupt',
        'not valid json',
      );
      final diff = await ChallengePointTracker.getDiffBestEffort(
        'best_effort_corrupt',
      );
      expect(diff, isNull);
    });
  });
}
