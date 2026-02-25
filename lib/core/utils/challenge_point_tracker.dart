import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'network_prefs.dart';

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

  static const _maxAge = Duration(hours: 48);
  static const _diffWindow = Duration(hours: 24);

  /// Record the current cumulative [points] for [key].
  ///
  /// Call this on each successful data fetch so that snapshots accumulate.
  static Future<void> record(String key, int points) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = _storageKey(key);
    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(_maxAge).millisecondsSinceEpoch ~/ 1000;

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
    final threshold = now - _diffWindow.inSeconds;

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
    final threshold = now - _diffWindow.inSeconds;

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
