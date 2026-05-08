import 'dart:async';
import 'dart:convert';

import 'package:crypto_mobile_app/features/dapps/models/dapp_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Parses a raw URL string into a [Uri], prepending `http://` if no scheme
/// is present, and remapping localhost to `10.0.2.2` on Android emulator.
Uri parseDappUrl(String raw) {
  final withScheme = raw.contains('://') ? raw : 'http://$raw';
  final uri = Uri.tryParse(withScheme) ?? Uri.parse('http://localhost:8000');

  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
    return uri.replace(host: '10.0.2.2');
  }

  return uri;
}

Uri _dappBaseUri() {
  const raw = String.fromEnvironment(
    'DAPP_HOMEPAGE',
    defaultValue:
        'https://usernode-dapp-homepage-87a553.social-vibecoding.usernodelabs.org',
  );
  return parseDappUrl(raw);
}

final dappsProvider = FutureProvider<List<DappItem>>((ref) async {
  final base = _dappBaseUri();
  final url = base.resolve('/dapps.json');
  final response = await http.get(url);
  if (response.statusCode != 200) {
    throw Exception('Failed to load dApps (${response.statusCode})');
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final apps = data['apps'] as List<dynamic>;
  return apps.map((e) => DappItem.fromJson(e as Map<String, dynamic>)).toList();
});

const _statsRefreshInterval = Duration(seconds: 30);

final dappStatsProvider = FutureProvider<Map<String, DappStats>>((ref) async {
  final timer = Timer(_statsRefreshInterval, () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);

  final base = _dappBaseUri();
  final response = await http.get(base.resolve('/api/stats'));
  if (response.statusCode != 200) {
    throw Exception('Failed to load dApp stats (${response.statusCode})');
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  return data.map((pubkey, value) {
    final m = value as Map<String, dynamic>;
    return MapEntry(
      pubkey,
      DappStats(
        users: (m['users'] as num?)?.toInt() ?? 0,
        txns: (m['txns'] as num?)?.toInt() ?? 0,
      ),
    );
  });
});

enum SortMode { popular, users, txns, alpha }

final sortedDappsProvider =
    Provider.family<List<DappItem>, SortMode>((ref, mode) {
  final dapps = ref.watch(dappsProvider).valueOrNull ?? [];
  final stats = ref.watch(dappStatsProvider).valueOrNull ?? {};

  final sorted = List<DappItem>.from(dapps);
  sorted.sort((a, b) {
    switch (mode) {
      case SortMode.alpha:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case SortMode.users:
        final au = stats[a.pubkey]?.users ?? 0;
        final bu = stats[b.pubkey]?.users ?? 0;
        return bu.compareTo(au);
      case SortMode.txns:
        final at = stats[a.pubkey]?.txns ?? 0;
        final bt = stats[b.pubkey]?.txns ?? 0;
        return bt.compareTo(at);
      case SortMode.popular:
        final aStats = stats[a.pubkey] ?? DappStats.zero;
        final bStats = stats[b.pubkey] ?? DappStats.zero;
        const userWeight = 20;
        final aScore = aStats.users * userWeight + aStats.txns;
        final bScore = bStats.users * userWeight + bStats.txns;
        return bScore.compareTo(aScore);
    }
  });
  return sorted;
});
