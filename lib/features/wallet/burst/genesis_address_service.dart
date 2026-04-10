import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';

final _log = LoggingService.instance.withTag('usernode/GenesisAddressService');

List<String> parseGenesisAddresses(Map<String, dynamic> genesisJson) {
  final addresses = <String>{};

  final alloc = genesisJson['alloc'];
  if (alloc is Map) {
    for (final key in alloc.keys) {
      if (key is String && key.startsWith('ut')) {
        addresses.add(key);
      }
    }
  }

  final outputs = genesisJson['outputs'];
  if (outputs is List) {
    for (final output in outputs) {
      if (output is! Map) continue;

      final recipient = output['recipient'];
      if (recipient is! Map) continue;

      final key = recipient['key'];
      if (key is! Map) continue;

      final pkHash = key['pk_hash'];
      if (pkHash is String && pkHash.startsWith('ut')) {
        addresses.add(pkHash);
      }
    }
  }

  return List<String>.unmodifiable(addresses);
}

class GenesisAddressService {
  GenesisAddressService._();

  static final instance = GenesisAddressService._();

  List<String>? _cached;

  /// Fetch genesis addresses from the network-appropriate genesis JSON.
  /// Results are cached after first successful fetch.
  Future<List<String>> getAddresses() async {
    if (_cached != null) return _cached!;

    final networkType = await RustBackendService.instance.getSelectedNetwork();
    final String genesisUrl;

    switch (networkType) {
      case NetworkType.testnet:
        genesisUrl = AppConfig.testnetGenesisUrl;
      case NetworkType.internal:
        genesisUrl = AppConfig.internalGenesisUrl;
      case NetworkType.custom:
        genesisUrl = AppConfig.customGenesisUrl;
    }

    _log.debug('Fetching genesis addresses from: $genesisUrl');

    final response = await http.get(Uri.parse(genesisUrl));
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to fetch genesis file: HTTP ${response.statusCode}');
    }

    final genesisJson = jsonDecode(response.body) as Map<String, dynamic>;
    final addresses = parseGenesisAddresses(genesisJson);

    _log.info('Cached ${addresses.length} genesis addresses');
    _cached = addresses;
    return addresses;
  }

  /// Pick [count] random addresses, excluding [exclude] (typically the user's
  /// own address).
  List<String> pickRandom(
    List<String> addresses,
    int count, {
    String? exclude,
  }) {
    final pool = exclude != null
        ? addresses.where((a) => a != exclude).toList()
        : List<String>.from(addresses);
    pool.shuffle(Random());
    return pool.sublist(0, min(count, pool.length));
  }
}
