import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/features/leaderboard/leaderboard_distribution.dart';

ParticipantPoints _pp(int id, int pts) =>
    ParticipantPoints(participantId: id, totalPoints: pts);

void main() {
  group('computeDistribution', () {
    test('returns empty list for empty input', () {
      expect(computeDistribution([]), isEmpty);
    });

    test('returns all-ones for single entry', () {
      final result = computeDistribution([_pp(1, 100)]);
      expect(result.length, kDistributionBucketCount);
      expect(result.every((v) => v == 1.0), isTrue);
    });

    test('returns all-ones when all participants have same score', () {
      final result = computeDistribution([
        _pp(1, 500),
        _pp(2, 500),
        _pp(3, 500),
      ]);
      expect(result.length, kDistributionBucketCount);
      expect(result.every((v) => v == 1.0), isTrue);
    });

    test('correctly buckets a spread of points', () {
      // Two participants at min, one at max: bucket 0 should have count 2,
      // last bucket should have count 1.
      final result = computeDistribution(
        [_pp(1, 0), _pp(2, 0), _pp(3, 1600)],
        bucketCount: 4,
      );
      expect(result.length, 4);
      // Bucket 0: 2 entries (max), Bucket 3: 1 entry
      expect(result[0], 1.0); // 2/2
      expect(result[3], 0.5); // 1/2
    });

    test('normalizes tallest bucket to 1.0', () {
      final result = computeDistribution(
        [
          _pp(1, 0),
          _pp(2, 100),
          _pp(3, 100),
          _pp(4, 100),
          _pp(5, 200),
        ],
        bucketCount: 3,
      );
      // Bucket 1 (middle) should have most entries and be 1.0
      final maxVal = result.reduce((a, b) => a > b ? a : b);
      expect(maxVal, 1.0);
    });

    test('respects custom bucket count', () {
      final result = computeDistribution(
        [_pp(1, 0), _pp(2, 100)],
        bucketCount: 8,
      );
      expect(result.length, 8);
    });
  });

  group('computeUserBarIndex', () {
    test('returns 0 for null user points', () {
      expect(computeUserBarIndex(null, [_pp(1, 100)]), 0);
    });

    test('returns 0 for empty entries', () {
      expect(computeUserBarIndex(100, []), 0);
    });

    test('returns middle bucket when all same score', () {
      final entries = [_pp(1, 500), _pp(2, 500)];
      expect(
        computeUserBarIndex(500, entries),
        kDistributionBucketCount ~/ 2,
      );
    });

    test('places user in correct bucket', () {
      // Range 0-1600, 4 buckets of width 400
      // 1200 -> bucket index 3
      final entries = [_pp(1, 0), _pp(2, 1600)];
      expect(computeUserBarIndex(1200, entries, bucketCount: 4), 3);
    });

    test('clamps to last bucket for max score', () {
      final entries = [_pp(1, 0), _pp(2, 1000)];
      expect(
        computeUserBarIndex(1000, entries, bucketCount: 4),
        3, // last bucket
      );
    });

    test('places user in first bucket for min score', () {
      final entries = [_pp(1, 0), _pp(2, 1000)];
      expect(computeUserBarIndex(0, entries, bucketCount: 4), 0);
    });
  });
}
