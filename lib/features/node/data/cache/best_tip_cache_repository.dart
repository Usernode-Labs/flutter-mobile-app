import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BestTipSnapshot {
  final int? height;
  final String? hash;
  final List<String> batchTransactions; // BigInt as strings
  final String updatedAt; // ISO

  const BestTipSnapshot({
    required this.height,
    required this.hash,
    required this.batchTransactions,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'height': height,
        'hash': hash,
        'batchTransactions': batchTransactions,
        'updatedAt': updatedAt,
      };

  static BestTipSnapshot? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      final List<dynamic> txs =
          (json['batchTransactions'] as List<dynamic>? ?? []);
      return BestTipSnapshot(
        height: (json['height'] as num?)?.toInt(),
        hash: json['hash'] as String?,
        batchTransactions: txs.map((e) => e.toString()).toList(),
        updatedAt: json['updatedAt'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

class BestTipCacheRepository {
  static const _keyPrefix = 'node:best_tip:last_snapshot:';

  Future<BestTipSnapshot?> getCached(String envKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$envKey');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return BestTipSnapshot.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String envKey, BestTipSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$envKey', jsonEncode(snapshot.toJson()));
  }
}
