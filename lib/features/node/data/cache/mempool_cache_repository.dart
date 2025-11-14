import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MempoolSnapshot {
  final String count; // BigInt as string
  final String orphans; // BigInt as string
  final String totalSize; // BigInt as string
  final String updatedAt; // ISO8601

  const MempoolSnapshot({
    required this.count,
    required this.orphans,
    required this.totalSize,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'count': count,
        'orphans': orphans,
        'totalSize': totalSize,
        'updatedAt': updatedAt,
      };

  static MempoolSnapshot? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      return MempoolSnapshot(
        count: json['count'] as String,
        orphans: json['orphans'] as String,
        totalSize: json['totalSize'] as String,
        updatedAt: json['updatedAt'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

class MempoolCacheRepository {
  static const _keyPrefix = 'node:mempool:last_snapshot:';

  Future<MempoolSnapshot?> getCached(String envKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$envKey');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return MempoolSnapshot.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String envKey, MempoolSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$envKey', jsonEncode(snapshot.toJson()));
  }
}
