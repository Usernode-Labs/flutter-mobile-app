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

enum AccountImportFailure { keyDerivation, secureStorage }

class AccountImportException implements Exception {
  AccountImportException(this.failure, this.cause);
  final AccountImportFailure failure;
  final Object cause;

  @override
  String toString() => 'AccountImportException($failure, $cause)';
}

/// Provider for AccountsRepository - handles account persistence
final accountsProvider = FutureProvider<AccountsRepository>((ref) async {
  return AccountsRepository.create();
});

class AccountsRepository {
  static const _kIndexKeyBase = 'accounts:index';
  static const _kActiveIdKeyBase = 'accounts:activeId';
  static const _kPathPrefix = "m/44'/60'/0'/0/";
  static const _kMetaField = 'meta';
  static final _idIndexPattern = RegExp(r'^acc_(\d+)_');

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
      return _recoverIndexFromSecureStorage(
        reason: raw == null ? 'missing' : 'empty',
      );
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final accounts = decoded
          .map((e) => AccountMeta.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      return accounts;
    } catch (e, st) {
      _log.error('Failed to decode accounts list', error: e, stackTrace: st);
      return _recoverIndexFromSecureStorage(reason: 'corrupt');
    }
  }

  Future<List<AccountMeta>> _recoverIndexFromSecureStorage({
    required String reason,
  }) async {
    try {
      final recovered = await _readRecoveredAccountsFromSecureStorage();
      if (recovered.isEmpty) {
        _log.warn(
          'Account index is $reason and no secure storage accounts were recovered',
        );
        return [];
      }

      await _saveIndex(recovered);

      final activeId = getActiveId();
      final hasValidActiveId = activeId != null &&
          recovered.any((account) => account.id == activeId);
      if (!hasValidActiveId) {
        await setActiveId(recovered.first.id);
      }

      _log.warn(
        'Recovered ${recovered.length} account(s) from secure storage after $reason account index',
      );
      return recovered;
    } catch (e, st) {
      _log.error(
        'Failed to recover account index from secure storage',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Future<List<AccountMeta>> _readRecoveredAccountsFromSecureStorage() async {
    final allEntries = await _secure.readAll();
    final prefix = '$_network:account:';
    final grouped = <String, Map<String, String>>{};

    for (final entry in allEntries.entries) {
      if (!entry.key.startsWith(prefix)) {
        continue;
      }

      final remainder = entry.key.substring(prefix.length);
      final separator = remainder.lastIndexOf(':');
      if (separator <= 0 || separator == remainder.length - 1) {
        continue;
      }

      final accountId = remainder.substring(0, separator);
      final field = remainder.substring(separator + 1);
      grouped.putIfAbsent(accountId, () => <String, String>{})[field] =
          entry.value;
    }

    final recovered = <AccountMeta>[];
    for (final entry in grouped.entries) {
      final meta = _recoverMeta(entry.key, entry.value);
      if (meta != null) {
        recovered.add(meta);
      }
    }

    recovered.sort((a, b) {
      final byIndex = a.hdIndex.compareTo(b.hdIndex);
      if (byIndex != 0) {
        return byIndex;
      }
      return a.createdAt.compareTo(b.createdAt);
    });

    return recovered;
  }

  AccountMeta? _recoverMeta(String accountId, Map<String, String> fields) {
    final storedMeta = fields[_kMetaField];
    if (storedMeta != null && storedMeta.isNotEmpty) {
      try {
        return AccountMeta.fromJson(
          jsonDecode(storedMeta) as Map<String, dynamic>,
        );
      } catch (e, st) {
        _log.warn(
          'Failed to decode stored account metadata for $accountId: $e',
        );
        _log.trace('Stored account metadata decode stack: $st');
      }
    }

    final address = fields['address'];
    final publicKey = fields['publicKey'];
    if (address == null ||
        address.isEmpty ||
        publicKey == null ||
        publicKey.isEmpty) {
      return null;
    }

    final hdIndex = int.tryParse(fields['hdIndex'] ?? '') ??
        _inferIndexFromId(accountId) ??
        0;

    return AccountMeta(
      id: accountId,
      name: 'Recovered Account ${hdIndex + 1}',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      derivationPath: 'recovered',
      hdIndex: hdIndex,
      address: address,
      publicKey: publicKey,
      backupConfirmed: true,
    );
  }

  int? _inferIndexFromId(String accountId) {
    final match = _idIndexPattern.firstMatch(accountId);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
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

  /// Get the secret key for a specific account from secure storage.
  Future<String?> getSecretKey(String accountId) async {
    try {
      final key = '$_network:account:$accountId:secretKey';
      final secretKey = await _secure.read(key: key);
      return secretKey;
    } catch (e, st) {
      _log.error('Failed to read secret key for account $accountId',
          error: e, stackTrace: st);
      return null;
    }
  }

  /// Import an account from a bech32m-encoded secret key (HRP `utsk`).
  ///
  /// Throws [AccountImportException] with a specific [AccountImportFailure]
  /// on key derivation or secure storage errors.
  Future<AccountMeta> importFromSecretKey({
    required String name,
    required String secretKey,
    bool isDemo = false,
  }) async {
    _log.debug('importFromSecretKey - start (name: $name, isDemo: $isDemo)');

    // Derive keys from private key via Rust FFI
    final AccountExport accountExport;
    try {
      accountExport = accountFromPrivateKey(
        secretKey: secretKey.trim(),
      );
    } catch (e, stackTrace) {
      _log.error('importFromSecretKey - key derivation FAILED',
          error: e, stackTrace: stackTrace);
      throw AccountImportException(AccountImportFailure.keyDerivation, e);
    }

    // Extract keys from AccountExport
    final derivedSecretKey = accountExport.secretKey;
    final publicKey = accountExport.publicKey;
    final address = accountExport.address;

    _log.debug('Secret key length: ${derivedSecretKey.length}');
    _log.debug('Public key length: ${publicKey.length}');
    _log.debug('Address: $address');

    // Persist to secure storage
    try {
      final result = await _persistNew(
        name: name,
        address: address,
        publicKey: publicKey,
        secretKey: derivedSecretKey,
        derivationPath: 'imported', // Mark as imported rather than HD path
        isDemo: isDemo,
      );
      _log.trace('importFromSecretKey - success (account id: ${result.id})');
      return result;
    } catch (e, stackTrace) {
      _log.error('importFromSecretKey - secure storage FAILED',
          error: e, stackTrace: stackTrace);
      throw AccountImportException(AccountImportFailure.secureStorage, e);
    }
  }

  Future<AccountMeta> _persistNew({
    required String name,
    required String address,
    required String publicKey,
    required String secretKey,
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
        key: '$_network:account:$id:secretKey', value: secretKey);
    await _secure.write(
        key: '$_network:account:$id:publicKey', value: publicKey);
    await _secure.write(key: '$_network:account:$id:address', value: address);
    await _secure.write(
        key: '$_network:account:$id:hdIndex', value: index.toString());
    await _secure.write(
      key: '$_network:account:$id:$_kMetaField',
      value: jsonEncode(meta.toJson()),
    );
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
