import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

/// Generic wrapper exposing cache metadata alongside the payload.
///
/// UI reads [data] for display, [isCached] to decide whether to show
/// a staleness indicator, and [staleness] for "Updated 2m ago" labels.
class CachedData<T> {
  final T data;

  /// `true` when the data was loaded from disk and a live fetch is in progress.
  final bool isCached;

  /// ISO 8601 UTC timestamp of the last successful API fetch.
  final String? lastUpdated;

  const CachedData({
    required this.data,
    required this.isCached,
    this.lastUpdated,
  });

  Duration? get staleness => lastUpdated == null
      ? null
      : DateTime.now().toUtc().difference(DateTime.parse(lastUpdated!));

  CachedData<T> copyWith({T? data, bool? isCached, String? lastUpdated}) {
    return CachedData<T>(
      data: data ?? this.data,
      isCached: isCached ?? this.isCached,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Snapshot returned from [LeaderboardCache.read].
class CachedSnapshot<T> {
  final T data;
  final String updatedAt;

  const CachedSnapshot({required this.data, required this.updatedAt});
}

/// Static helpers for reading/writing leaderboard data to SharedPreferences.
///
/// Key scheme: `leaderboard:{type}:s{seasonId}[:e{eventId}][:p{page}]`
/// All keys are additionally prefixed by [NetworkPrefs.prefixKey] for network
/// isolation (testnet / internal / custom).
///
/// The on-disk format wraps the payload in a JSON envelope:
/// ```json
/// { "data": <payload>, "updatedAt": "2025-01-15T10:00:00.000Z" }
/// ```
class LeaderboardCache {
  LeaderboardCache._();

  /// Read a cached value, returning `null` if nothing is stored or the
  /// stored JSON is corrupt.
  static Future<CachedSnapshot<T>?> read<T>({
    required String type,
    int? seasonId,
    int? eventId,
    int? page,
    required T Function(dynamic json) fromJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(type, seasonId, eventId, page));
    if (raw == null) return null;
    try {
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      final data = fromJson(envelope['data']);
      return CachedSnapshot<T>(
        data: data,
        updatedAt: envelope['updatedAt'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  /// Write a value to the cache, stamped with the current UTC time.
  static Future<void> write({
    required String type,
    int? seasonId,
    int? eventId,
    int? page,
    required dynamic Function() toJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final envelope = {
      'data': toJson(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await prefs.setString(
        _key(type, seasonId, eventId, page), jsonEncode(envelope));
  }

  // -- private ---------------------------------------------------------------

  static String _key(String type, int? seasonId, int? eventId, int? page) {
    final buf = StringBuffer('leaderboard:$type');
    if (seasonId != null) buf.write(':s$seasonId');
    if (eventId != null) buf.write(':e$eventId');
    if (page != null) buf.write(':p$page');
    return NetworkPrefs.prefixKey(buf.toString());
  }
}
