import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';

final _log = LoggingService.instance.withTag('usernode/GenesisAddressService');

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
    final alloc = genesisJson['alloc'] as Map<String, dynamic>? ?? {};

    // alloc keys are ut-prefixed address strings
    final addresses =
        alloc.keys.where((key) => key.startsWith('ut')).toList(growable: false);

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
