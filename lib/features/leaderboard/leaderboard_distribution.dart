import 'dart:math' as math;

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';

const kDistributionBucketCount = 16;

const kMinBucketCount = 6;
const kMaxBucketCount = 20;

/// Computes an adaptive bucket count using Rice's rule: ceil(2 * n^(1/3)),
/// clamped to [kMinBucketCount, kMaxBucketCount].
int computeAdaptiveBucketCount(int participantCount) {
  if (participantCount <= 0) return kMinBucketCount;
  final raw = (2 * math.pow(participantCount, 1 / 3)).ceil();
  return raw.clamp(kMinBucketCount, kMaxBucketCount);
}

/// Computes normalized bar heights (0..1) from all participants' point totals.
///
/// Groups points into [bucketCount] equal-width buckets by point range,
/// then normalizes so the tallest bucket is 1.0.
/// Returns an empty list if [allPoints] is empty.
List<double> computeDistribution(
  List<ParticipantPoints> allPoints, {
  int bucketCount = kDistributionBucketCount,
}) {
  if (allPoints.isEmpty) return [];

  final points = allPoints.map((e) => e.totalPoints).toList();
  final minPts = points.reduce(math.min);
  final maxPts = points.reduce(math.max);

  // All same score — flat distribution
  if (maxPts == minPts) {
    return List.filled(bucketCount, 1.0);
  }

  final range = maxPts - minPts;
  final bucketWidth = range / bucketCount;
  final counts = List<int>.filled(bucketCount, 0);

  for (final pts in points) {
    int bucket = ((pts - minPts) / bucketWidth).floor();
    if (bucket >= bucketCount) bucket = bucketCount - 1;
    counts[bucket]++;
  }

  final maxCount = counts.reduce(math.max);
  if (maxCount == 0) return List.filled(bucketCount, 0.0);

  return counts.map((c) => c / maxCount).toList();
}

/// Determines which bucket the user falls into based on their total points.
///
/// Returns the bucket index (0-based, where 0 = lowest point range).
/// Returns 0 if user points are null or [allPoints] is empty.
int computeUserBarIndex(
  int? userTotalPoints,
  List<ParticipantPoints> allPoints, {
  int bucketCount = kDistributionBucketCount,
}) {
  if (userTotalPoints == null || allPoints.isEmpty) return 0;

  final points = allPoints.map((e) => e.totalPoints).toList();
  final minPts = points.reduce(math.min);
  final maxPts = points.reduce(math.max);

  if (maxPts == minPts) return bucketCount ~/ 2;

  final range = maxPts - minPts;
  final bucketWidth = range / bucketCount;
  final bucket = ((userTotalPoints - minPts) / bucketWidth).floor();
  return bucket.clamp(0, bucketCount - 1);
}

/// Computes raw participant counts per bucket (not normalized).
///
/// Same bucketing logic as [computeDistribution] but returns raw counts
/// for use with the dot-matrix chart.
List<int> computeDistributionCounts(
  List<ParticipantPoints> allPoints, {
  int bucketCount = kDistributionBucketCount,
}) {
  if (allPoints.isEmpty) return [];

  final points = allPoints.map((e) => e.totalPoints).toList();
  final minPts = points.reduce(math.min);
  final maxPts = points.reduce(math.max);

  if (maxPts == minPts) {
    return List.filled(bucketCount, allPoints.length ~/ bucketCount)
      ..[bucketCount ~/ 2] = allPoints.length;
  }

  final range = maxPts - minPts;
  final bucketWidth = range / bucketCount;
  final counts = List<int>.filled(bucketCount, 0);

  for (final pts in points) {
    int bucket = ((pts - minPts) / bucketWidth).floor();
    if (bucket >= bucketCount) bucket = bucketCount - 1;
    counts[bucket]++;
  }

  return counts;
}

/// Returns the (min, max) point range across all participants.
///
/// Returns (0, 0) if [allPoints] is empty.
(int, int) computeDistributionRange(List<ParticipantPoints> allPoints) {
  if (allPoints.isEmpty) return (0, 0);

  final points = allPoints.map((e) => e.totalPoints).toList();
  return (points.reduce(math.min), points.reduce(math.max));
}
