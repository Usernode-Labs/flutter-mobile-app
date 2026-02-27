import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';

import 'network_prefs.dart';

/// Result of a best-effort point diff computation.
///
/// Returned by [ChallengePointTracker.getDiffBestEffort]. Contains the
/// computed point difference and the duration since the baseline snapshot.
class PointDiff {
  final int points;
  final Duration since;
  const PointDiff({required this.points, required this.since});
}

/// Stores timestamped point snapshots in SharedPreferences and computes
/// 24-hour deltas for challenge points.
///
/// Key scheme: `challenge_pts:<challengeKey>` prefixed by [NetworkPrefs] for
/// network isolation.
///
/// Each key stores a JSON array of `{"p": <points>, "t": <unix_seconds>}`.
/// Entries older than 48h are pruned on each [record] call.
class ChallengePointTracker {
  ChallengePointTracker._();

  /// Record the current cumulative [points] for [key].
  ///
  /// Call this on each successful data fetch so that snapshots accumulate.
  static Future<void> record(String key, int points) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = _storageKey(key);
    final now = DateTime.now().toUtc();
    final cutoff =
        now.subtract(AppConfig.challengePointMaxAge).millisecondsSinceEpoch ~/
            1000;

    final entries = _read(prefs, storageKey);

    // Prune old entries and append new one
    entries.removeWhere((e) => e.t < cutoff);
    entries.add(_Snapshot(p: points, t: now.millisecondsSinceEpoch ~/ 1000));

    await prefs.setString(
      storageKey,
      jsonEncode(entries.map((e) => {'p': e.p, 't': e.t}).toList()),
    );
  }

  /// Returns the points earned in the last 24 hours for [key], or `null` if
  /// there is no snapshot old enough to compute a diff.
  static Future<int?> getDiff24h(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = _storageKey(key);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final threshold = now - AppConfig.challengePointDiffWindow.inSeconds;

    final entries = _read(prefs, storageKey);
    if (entries.isEmpty) return null;

    final current = entries.last.p;

    // Find the latest entry at or before the 24h threshold
    _Snapshot? baseline;
    for (final e in entries) {
      if (e.t <= threshold) {
        baseline = e;
      } else {
        break;
      }
    }

    if (baseline == null) return null;
    return current - baseline.p;
  }

  /// Returns the timestamp of the baseline snapshot used for the 24h diff,
  /// or `null` if no baseline exists.
  static Future<DateTime?> getDiffSince(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = _storageKey(key);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final threshold = now - AppConfig.challengePointDiffWindow.inSeconds;

    final entries = _read(prefs, storageKey);

    _Snapshot? baseline;
    for (final e in entries) {
      if (e.t <= threshold) {
        baseline = e;
      } else {
        break;
      }
    }

    if (baseline == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      baseline.t * 1000,
      isUtc: true,
    );
  }

  /// Returns the best available point diff for [key].
  ///
  /// - 0–1 entries: returns `null` (no meaningful diff).
  /// - 2+ entries with a snapshot >= 24h old: uses the 24h baseline.
  /// - 2+ entries, all < 24h old: uses the earliest entry as baseline.
  ///
  /// The returned [PointDiff.since] reflects the actual duration from baseline
  /// to now, enabling dynamic labels like "Last 3h" for young tracking data.
  static Future<PointDiff?> getDiffBestEffort(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = _storageKey(key);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final threshold = now - AppConfig.challengePointDiffWindow.inSeconds;

    final entries = _read(prefs, storageKey);
    if (entries.length < 2) return null;

    final current = entries.last;

    // Prefer the 24h baseline (latest entry at or before threshold)
    _Snapshot? baseline;
    for (final e in entries) {
      if (e.t <= threshold) {
        baseline = e;
      } else {
        break;
      }
    }

    // Fall back to earliest entry when no 24h baseline exists
    baseline ??= entries.first;

    return PointDiff(
      points: (current.p - baseline.p).clamp(0, current.p),
      since: Duration(seconds: now - baseline.t),
    );
  }

  // -- private ---------------------------------------------------------------

  static String _storageKey(String key) =>
      NetworkPrefs.prefixKey('challenge_pts:$key');

  static List<_Snapshot> _read(SharedPreferences prefs, String storageKey) {
    final raw = prefs.getString(storageKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => _Snapshot(
                p: (e['p'] as num).toInt(),
                t: (e['t'] as num).toInt(),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

class _Snapshot {
  final int p;
  final int t;
  const _Snapshot({required this.p, required this.t});
}
