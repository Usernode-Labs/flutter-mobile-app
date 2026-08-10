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

final dappBySlugProvider = Provider.family<DappItem?, String>((ref, slug) {
  final dapps = ref.watch(dappsProvider).valueOrNull;
  if (dapps == null) return null;

  assert(() {
    final seen = <String>{};
    for (final dapp in dapps) {
      final dappSlug = dapp.slug;
      if (!seen.add(dappSlug)) {
        throw FlutterError('Duplicate dApp slug: $dappSlug');
      }
    }
    return true;
  }());

  for (final dapp in dapps) {
    if (dapp.slug == slug) return dapp;
  }
  return null;
});
