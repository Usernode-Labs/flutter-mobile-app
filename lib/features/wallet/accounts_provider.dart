import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto_mobile_app/features/wallet/models/account.dart';
import 'package:crypto_mobile_app/src/rust/account.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';

final _log = LoggingService.instance.withTag('usernode/AccountsProvider');

/// Provider for AccountsRepository - handles account persistence
final accountsProvider = FutureProvider<AccountsRepository>((ref) async {
  return AccountsRepository.create();
});

class AccountsRepository {
  static const _kIndexKeyBase = 'accounts:index';
  static const _kActiveIdKeyBase = 'accounts:activeId';
  static const _kPathPrefix = "m/44'/60'/0'/0/";

  final FlutterSecureStorage _secure;
  final SharedPreferences _prefs;
  final String _network;

  // Network-prefixed keys
  String get _kIndexKey => NetworkPrefs.prefixKeyWith(_kIndexKeyBase, _network);
  String get _kActiveIdKey =>
      NetworkPrefs.prefixKeyWith(_kActiveIdKeyBase, _network);

  AccountsRepository._(this._secure, this._prefs, this._network);

  static Future<AccountsRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage();
    final network = await NetworkPrefs.getNetwork();
    return AccountsRepository._(secure, prefs, network);
  }

  Future<bool> hasAny() async {
    final items = await list();
    final result = items.isNotEmpty;
    _log.trace('hasAny() = $result (found ${items.length} accounts)');
    return result;
  }

  Future<List<AccountMeta>> list() async {
    final raw = _prefs.getString(_kIndexKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final accounts = decoded
          .map((e) => AccountMeta.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      return accounts;
    } catch (e, st) {
      _log.error('Failed to decode accounts list', error: e, stackTrace: st);
      return [];
    }
  }

  Future<void> _saveIndex(List<AccountMeta> items) async {
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await _prefs.setString(_kIndexKey, raw);
  }

  String? getActiveId() => _prefs.getString(_kActiveIdKey);

  Future<void> setActiveId(String id) async {
    await _prefs.setString(_kActiveIdKey, id);
    // Set Sentry user context for error correlation
    SentryUtil.setUser(id: id);
    _log.debug('Set Sentry user context for account: $id');
  }

  Future<AccountMeta?> getActive() async {
    final id = getActiveId();
    if (id == null) return null;
    final items = await list();
    try {
      return items.firstWhere((a) => a.id == id);
    } catch (e) {
      _log.debug('Active account $id not found, falling back to first: $e');
      return items.isNotEmpty ? items.first : null;
    }
  }

  /// Get the private key for a specific account from secure storage
  Future<String?> getPrivateKey(String accountId) async {
    try {
      final key = '$_network:account:$accountId:privateKey';
      final privateKey = await _secure.read(key: key);
      return privateKey;
    } catch (e, st) {
      _log.error('Failed to read private key for account $accountId',
          error: e, stackTrace: st);
      return null;
    }
  }

  /// Import an account from a hex-encoded private key.
  Future<AccountMeta?> importFromPrivateKey({
    required String name,
    required String privateKeyHex,
    bool isDemo = false,
  }) async {
    _log.trace('importFromPrivateKey - start (name: $name, isDemo: $isDemo)');

    try {
      // Use Rust backend to derive public key and address from private key
      final accountExport = accountFromPrivateKey(
        privateKeyHex: privateKeyHex.trim(),
      );

      // Extract keys from AccountExport
      final privateKey = accountExport.secretKeyHex;
      final publicKey = accountExport.publicKeyHex;
      final address = accountExport.publicKeyHashBech32M;

      _log.trace('Private key length: ${privateKey.length}');
      _log.trace('Public key length: ${publicKey.length}');
      _log.trace('Address: $address');

      final result = await _persistNew(
        name: name,
        address: address,
        publicKey: publicKey,
        privateKey: privateKey,
        derivationPath: 'imported', // Mark as imported rather than HD path
        isDemo: isDemo,
      );
      _log.trace('importFromPrivateKey - success (account id: ${result.id})');
      return result;
    } catch (e, stackTrace) {
      _log.error('importFromPrivateKey - FAILED with exception',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<AccountMeta> _persistNew({
    required String name,
    required String address,
    required String publicKey,
    required String privateKey,
    String? derivationPath,
    bool isDemo = false,
  }) async {
    _log.trace('_persistNew - start (name: $name, address: $address)');

    final current = await list();

    final index = current.length;
    final id = _makeId(address, index);
    _log.trace('Generated account ID: $id (index: $index)');

    final meta = AccountMeta(
      id: id,
      name: name,
      createdAt: DateTime.now(),
      derivationPath: derivationPath ?? '$_kPathPrefix$index',
      hdIndex: index,
      address: address,
      publicKey: publicKey,
      backupConfirmed: true, // Imported accounts assumed backed up by user
      isDemo: isDemo,
    );

    _log.debug('Writing to secure storage (4 keys) for network: $_network...');
    await _secure.write(
        key: '$_network:account:$id:privateKey', value: privateKey);
    await _secure.write(
        key: '$_network:account:$id:publicKey', value: publicKey);
    await _secure.write(key: '$_network:account:$id:address', value: address);
    await _secure.write(
        key: '$_network:account:$id:hdIndex', value: index.toString());
    _log.debug('Secure storage writes complete');

    final next = [...current, meta];
    await _saveIndex(next);
    _log.debug('Index saved successfully');

    _log.debug('Setting active account ID to: $id');
    await setActiveId(id);
    _log.debug('_persistNew - complete (id: $id)');

    return meta;
  }

  String _makeId(String address, int index) {
    // Simple deterministic id for now: addr suffix + index
    final suffix =
        address.length >= 8 ? address.substring(address.length - 8) : address;
    return 'acc_${index}_$suffix';
  }
}
