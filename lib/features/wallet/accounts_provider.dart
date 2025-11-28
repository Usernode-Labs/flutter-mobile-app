import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto_mobile_app/features/wallet/models/account.dart';
import 'package:crypto_mobile_app/src/rust/account.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

/// Provider for AccountsRepository - handles account persistence
final accountsProvider = FutureProvider<AccountsRepository>((ref) async {
  return AccountsRepository.create();
});

class AccountsRepository {
  static const _kIndexKey = 'accounts:index';
  static const _kActiveIdKey = 'accounts:activeId';
  static const _kPathPrefix = "m/44'/60'/0'/0/";

  final FlutterSecureStorage _secure;
  final SharedPreferences _prefs;

  AccountsRepository._(this._secure, this._prefs);

  static Future<AccountsRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage();
    return AccountsRepository._(secure, prefs);
  }

  Future<bool> hasAny() async {
    final items = await list();
    final result = items.isNotEmpty;
    LoggingService.instance.trace(
        'hasAny() = $result (found ${items.length} accounts)',
        tag: 'ACCOUNTS_REPO');
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
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveIndex(List<AccountMeta> items) async {
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await _prefs.setString(_kIndexKey, raw);
  }

  String? getActiveId() => _prefs.getString(_kActiveIdKey);
  Future<void> setActiveId(String id) => _prefs.setString(_kActiveIdKey, id);

  Future<AccountMeta?> getActive() async {
    final id = getActiveId();
    if (id == null) return null;
    final items = await list();
    try {
      return items.firstWhere((a) => a.id == id);
    } catch (_) {
      return items.isNotEmpty ? items.first : null;
    }
  }

  /// Get the private key for a specific account from secure storage
  Future<String?> getPrivateKey(String accountId) async {
    try {
      final privateKey =
          await _secure.read(key: 'account:$accountId:privateKey');
      return privateKey;
    } catch (e, st) {
      LoggingService.instance.error(
          'Failed to read private key for account $accountId',
          tag: 'ACCOUNTS_REPO',
          error: e,
          stackTrace: st);
      return null;
    }
  }

  /// Import an account from a hex-encoded private key.
  Future<AccountMeta?> importFromPrivateKey({
    required String name,
    required String privateKeyHex,
    bool isDemo = false,
  }) async {
    LoggingService.instance.trace(
        'importFromPrivateKey - start (name: $name, isDemo: $isDemo)',
        tag: 'ACCOUNTS_REPO');

    try {
      // Use Rust backend to derive public key and address from private key
      final accountExport = accountFromPrivateKey(
        privateKeyHex: privateKeyHex.trim(),
      );

      // Extract keys from AccountExport
      final privateKey = accountExport.secretKeyHex;
      final publicKey = accountExport.publicKeyHex;
      final address = accountExport.publicKeyHashBech32M;

      LoggingService.instance.trace('Private key length: ${privateKey.length}',
          tag: 'ACCOUNTS_REPO');
      LoggingService.instance.trace('Public key length: ${publicKey.length}',
          tag: 'ACCOUNTS_REPO');
      LoggingService.instance.trace('Address: $address', tag: 'ACCOUNTS_REPO');

      final result = await _persistNew(
        name: name,
        address: address,
        publicKey: publicKey,
        privateKey: privateKey,
        derivationPath: 'imported', // Mark as imported rather than HD path
        isDemo: isDemo,
      );
      LoggingService.instance.trace(
          'importFromPrivateKey - success (account id: ${result.id})',
          tag: 'ACCOUNTS_REPO');
      return result;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
          'importFromPrivateKey - FAILED with exception',
          tag: 'ACCOUNTS_REPO',
          error: e,
          stackTrace: stackTrace);
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
    LoggingService.instance.trace(
        '_persistNew - start (name: $name, address: $address)',
        tag: 'ACCOUNTS_REPO');

    final current = await list();

    final index = current.length;
    final id = _makeId(address, index);
    LoggingService.instance.trace('Generated account ID: $id (index: $index)',
        tag: 'ACCOUNTS_REPO');

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

    LoggingService.instance
        .debug('Writing to secure storage (4 keys)...', tag: 'ACCOUNTS_REPO');
    await _secure.write(key: 'account:$id:privateKey', value: privateKey);
    await _secure.write(key: 'account:$id:publicKey', value: publicKey);
    await _secure.write(key: 'account:$id:address', value: address);
    await _secure.write(key: 'account:$id:hdIndex', value: index.toString());
    LoggingService.instance
        .debug('Secure storage writes complete', tag: 'ACCOUNTS_REPO');

    final next = [...current, meta];
    await _saveIndex(next);
    LoggingService.instance
        .debug('Index saved successfully', tag: 'ACCOUNTS_REPO');

    LoggingService.instance
        .debug('Setting active account ID to: $id', tag: 'ACCOUNTS_REPO');
    await setActiveId(id);
    LoggingService.instance
        .debug('_persistNew - complete (id: $id)', tag: 'ACCOUNTS_REPO');

    return meta;
  }

  String _makeId(String address, int index) {
    // Simple deterministic id for now: addr suffix + index
    final suffix =
        address.length >= 8 ? address.substring(address.length - 8) : address;
    return 'acc_${index}_$suffix';
  }
}
