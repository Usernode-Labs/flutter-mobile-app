import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto_mobile_app/features/wallet/data/models/account.dart';
import 'package:crypto_mobile_app/src/rust/account.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

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
    LoggingService.instance.debug('hasAny() called', tag: 'ACCOUNTS_REPO');
    final items = await list();
    final result = items.isNotEmpty;
    LoggingService.instance.debug(
        'hasAny() = $result (found ${items.length} accounts)',
        tag: 'ACCOUNTS_REPO');
    return result;
  }

  Future<List<AccountMeta>> list() async {
    final raw = _prefs.getString(_kIndexKey);
    LoggingService.instance.debug(
        'list() - raw from SharedPreferences: ${raw?.substring(0, raw.length > 100 ? 100 : raw.length)}${(raw?.length ?? 0) > 100 ? "..." : ""}',
        tag: 'ACCOUNTS_REPO');
    if (raw == null || raw.isEmpty) {
      LoggingService.instance.debug(
          'list() - no accounts found (raw is null or empty)',
          tag: 'ACCOUNTS_REPO');
      return [];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final accounts = decoded
          .map((e) => AccountMeta.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      LoggingService.instance.debug(
          'list() - parsed ${accounts.length} accounts: ${accounts.map((a) => a.id).toList()}',
          tag: 'ACCOUNTS_REPO');
      return accounts;
    } catch (e) {
      LoggingService.instance.error('list() - failed to parse accounts',
          tag: 'ACCOUNTS_REPO', error: e, stackTrace: StackTrace.current);
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

  Future<void> markBackupConfirmed(String id) async {
    final items = await list();
    final idx = items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final updated = [...items];
    updated[idx] = updated[idx].copyWith(backupConfirmed: true);
    await _saveIndex(updated);
  }

  /// Update identity verification status for an account
  Future<void> updateIdentityVerification(String accountId,
      {required bool verified}) async {
    LoggingService.instance.debug(
        'updateIdentityVerification - accountId: $accountId, verified: $verified',
        tag: 'ACCOUNTS_REPO');

    final items = await list();
    final idx = items.indexWhere((e) => e.id == accountId);
    if (idx < 0) {
      LoggingService.instance
          .error('Account not found: $accountId', tag: 'ACCOUNTS_REPO');
      return;
    }

    final updated = [...items];
    updated[idx] = updated[idx].copyWith(
      identityVerified: verified,
      identityVerifiedAt: verified ? DateTime.now() : null,
    );
    await _saveIndex(updated);

    // Store in secure storage
    await _secure.write(
      key: 'account:$accountId:identityVerified',
      value: verified.toString(),
    );
    if (verified) {
      await _secure.write(
        key: 'account:$accountId:identityVerifiedAt',
        value: DateTime.now().toIso8601String(),
      );
    } else {
      await _secure.delete(key: 'account:$accountId:identityVerifiedAt');
    }

    LoggingService.instance.debug('Identity verification updated successfully',
        tag: 'ACCOUNTS_REPO');
  }

  Future<void> rename(String id, String name) async {
    final items = await list();
    final idx = items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final updated = [...items];
    updated[idx] = updated[idx].copyWith(name: name);
    await _saveIndex(updated);
  }

  /// Delete a specific account by ID
  Future<void> deleteAccount(String id) async {
    final items = await list();
    final idx = items.indexWhere((e) => e.id == id);
    if (idx < 0) return;

    // Remove from secure storage
    await _secure.delete(key: 'account:$id:privateKey');
    await _secure.delete(key: 'account:$id:publicKey');
    await _secure.delete(key: 'account:$id:address');
    await _secure.delete(key: 'account:$id:hdIndex');

    // Remove from index
    final updated = [...items]..removeAt(idx);
    await _saveIndex(updated);

    // Clear active ID if it was the deleted account
    if (getActiveId() == id) {
      await _prefs.remove(_kActiveIdKey);
    }
  }

  /// Danger: Delete all stored accounts (dev-only usage).
  Future<void> deleteAll() async {
    final items = await list();
    for (final acc in items) {
      final id = acc.id;
      await _secure.delete(key: 'account:$id:privateKey');
      await _secure.delete(key: 'account:$id:publicKey');
      await _secure.delete(key: 'account:$id:address');
      await _secure.delete(key: 'account:$id:hdIndex');
    }
    await _prefs.remove(_kIndexKey);
    await _prefs.remove(_kActiveIdKey);
  }

  /// Import an account from a BIP39 mnemonic. Does not store mnemonic.
  Future<AccountMeta?> importFromMnemonic({
    required String name,
    required String mnemonic,
  }) async {
    final wordCount = mnemonic.trim().split(RegExp(r'\s+')).length;
    LoggingService.instance.debug(
        'importFromMnemonic - start (name: $name, mnemonic word count: $wordCount)',
        tag: 'ACCOUNTS_REPO');

    try {
      // Use Rust backend to derive keys from mnemonic
      LoggingService.instance.debug('Calling Rust backend accountFromSeed...',
          tag: 'ACCOUNTS_REPO');
      final accountExport = accountFromSeed(
        phrase: mnemonic.trim(),
        passphrase: null,
        index: 0, // Use index 0 for imported accounts
      );
      LoggingService.instance.debug('Account derived successfully from backend',
          tag: 'ACCOUNTS_REPO');

      // Extract keys from AccountExport
      final privateKey = accountExport.secretKeyHex;
      final publicKey = accountExport.publicKeyHex;
      final address =
          accountExport.publicKeyHashHex; // Use hex format for consistency

      LoggingService.instance.debug('Private key length: ${privateKey.length}',
          tag: 'ACCOUNTS_REPO');
      LoggingService.instance.debug('Public key length: ${publicKey.length}',
          tag: 'ACCOUNTS_REPO');
      LoggingService.instance.debug('Address: $address', tag: 'ACCOUNTS_REPO');

      LoggingService.instance
          .debug('Calling _persistNew...', tag: 'ACCOUNTS_REPO');
      final result = await _persistNew(
        name: name,
        address: address,
        publicKey: publicKey,
        privateKey: privateKey,
      );
      LoggingService.instance.debug(
          'importFromMnemonic - success (account id: ${result.id})',
          tag: 'ACCOUNTS_REPO');
      return result;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
          'importFromMnemonic - FAILED with exception',
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
  }) async {
    LoggingService.instance.debug(
        '_persistNew - start (name: $name, address: $address)',
        tag: 'ACCOUNTS_REPO');

    LoggingService.instance
        .debug('Retrieving current account list...', tag: 'ACCOUNTS_REPO');
    final current = await list();
    LoggingService.instance.debug('Current account count: ${current.length}',
        tag: 'ACCOUNTS_REPO');

    final index = current.length;
    final id = _makeId(address, index);
    LoggingService.instance.debug('Generated account ID: $id (index: $index)',
        tag: 'ACCOUNTS_REPO');

    final meta = AccountMeta(
      id: id,
      name: name,
      createdAt: DateTime.now(),
      derivationPath: '$_kPathPrefix$index',
      hdIndex: index,
      address: address,
      publicKey: publicKey,
      backupConfirmed: true, // Imported accounts assumed backed up by user
    );
    LoggingService.instance.debug('AccountMeta created', tag: 'ACCOUNTS_REPO');

    LoggingService.instance
        .debug('Writing to secure storage (4 keys)...', tag: 'ACCOUNTS_REPO');
    await _secure.write(key: 'account:$id:privateKey', value: privateKey);
    await _secure.write(key: 'account:$id:publicKey', value: publicKey);
    await _secure.write(key: 'account:$id:address', value: address);
    await _secure.write(key: 'account:$id:hdIndex', value: index.toString());
    LoggingService.instance
        .debug('Secure storage writes complete', tag: 'ACCOUNTS_REPO');

    final next = [...current, meta];
    LoggingService.instance.debug(
        'Saving account index (total accounts: ${next.length})...',
        tag: 'ACCOUNTS_REPO');
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
