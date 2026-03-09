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
    defaultValue: 'http://localhost:8000',
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

final dappStatsProvider = FutureProvider<Map<String, DappStats>>((ref) async {
  final dapps = await ref.watch(dappsProvider.future);
  final base = _dappBaseUri();

  // Get chain ID.
  final chainRes = await http.get(base.resolve('/explorer-api/active_chain'));
  if (chainRes.statusCode != 200) {
    throw Exception('Failed to fetch active chain');
  }
  final chainData = jsonDecode(chainRes.body) as Map<String, dynamic>;
  final chainId = chainData['chain_id'] as String;

  final result = <String, DappStats>{};

  // Fetch stats for all dApps concurrently (paginated fetch per-dApp is
  // sequential since it depends on cursors).
  final eligible = dapps.where((d) => d.pubkey?.isNotEmpty == true);
  final entries = await Future.wait(eligible.map((dapp) async {
    final pubkey = dapp.pubkey!;
    var totalTxns = 0;
    final uniqueSenders = <String>{};
    String? cursor;
    const maxPages = 20;

    for (var page = 0; page < maxPages; page++) {
      final body = <String, dynamic>{
        'recipient': pubkey,
        'limit': 50,
      };
      if (cursor != null) body['cursor'] = cursor;

      final txRes = await http.post(
        base.resolve('/explorer-api/$chainId/transactions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (txRes.statusCode != 200) break;

      final txData = jsonDecode(txRes.body) as Map<String, dynamic>;
      final items = txData['items'] as List<dynamic>? ?? [];
      totalTxns += items.length;

      for (final item in items) {
        final sender = (item as Map<String, dynamic>)['source'] as String?;
        if (sender != null) uniqueSenders.add(sender);
      }

      final hasMore = txData['has_more'] as bool? ?? false;
      if (!hasMore || items.isEmpty) break;
      cursor = txData['next_cursor'] as String?;
      if (cursor == null) break;
    }

    return MapEntry(
        pubkey, DappStats(users: uniqueSenders.length, txns: totalTxns));
  }));

  result.addEntries(entries);
  return result;
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
