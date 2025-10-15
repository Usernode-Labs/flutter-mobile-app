import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto_mobile_app/features/wallet/data/models/account.dart';
import 'package:crypto_mobile_app/features/wallet/data/models/account_creation_result.dart';
import 'package:crypto_mobile_app/features/wallet/data/datasources/key_management_service.dart';
import 'package:crypto_mobile_app/src/rust/account.dart';
import 'package:web3dart/credentials.dart';
import 'package:web3dart/web3dart.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

class AccountsRepository {
  static const _kIndexKey = 'accounts:index';
  static const _kActiveIdKey = 'accounts:activeId';
  static const _kPathPrefix = "m/44'/60'/0'/0/";

  final FlutterSecureStorage _secure;
  final SharedPreferences _prefs;
  final KeyManagementService _kms;

  AccountsRepository._(this._secure, this._prefs, this._kms);

  static Future<AccountsRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage();
    final kms = KeyManagementService();
    return AccountsRepository._(secure, prefs, kms);
  }

  Future<bool> hasAny() async {
    Log.d('ACCOUNTS_REPO', 'hasAny() called');
    final items = await list();
    final result = items.isNotEmpty;
    Log.d('ACCOUNTS_REPO', 'hasAny() = $result (found ${items.length} accounts)');
    return result;
  }

  Future<List<AccountMeta>> list() async {
    final raw = _prefs.getString(_kIndexKey);
    Log.d('ACCOUNTS_REPO', 'list() - raw from SharedPreferences: ${raw?.substring(0, raw.length > 100 ? 100 : raw.length)}${(raw?.length ?? 0) > 100 ? "..." : ""}');
    if (raw == null || raw.isEmpty) {
      Log.d('ACCOUNTS_REPO', 'list() - no accounts found (raw is null or empty)');
      return [];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final accounts = decoded
          .map((e) => AccountMeta.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      Log.d('ACCOUNTS_REPO', 'list() - parsed ${accounts.length} accounts: ${accounts.map((a) => a.id).toList()}');
      return accounts;
    } catch (e) {
      Log.e('ACCOUNTS_REPO', 'list() - failed to parse accounts', e, StackTrace.current);
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

  /// Creates a new account using KMS. Returns the full result including mnemonic
  /// for display. Mnemonic is NOT persisted; only non-sensitive parts are saved.
  Future<AccountCreationResult> createNew({
    required String name,
  }) async {
    final index = (await list()).length; // next hd index
    final gen = await _kms.createWallet();

    final success = gen.isNotEmpty && gen.first == true;
    if (!success) {
      final err = gen.length > 1 ? gen[1].toString() : 'unknown error';
      return AccountCreationResult(
        mnemonic: '',
        privateKey: '',
        publicKey: '',
        address: '',
        hdIndex: index,
        success: false,
        error: err,
      );
    }

    final mnemonic = gen[1] as String;
    final privateKey = gen[2] as String;
    final publicKey = gen[3] as String;
    final address = gen[4] as String;

    final id = _makeId(address, index);
    final meta = AccountMeta(
      id: id,
      name: name,
      createdAt: DateTime.now(),
      derivationPath: '$_kPathPrefix$index',
      hdIndex: index,
      address: address,
      publicKey: publicKey,
      backupConfirmed: false,
    );

    // Persist sensitive (no mnemonic)
    await _secure.write(key: 'account:$id:privateKey', value: privateKey);
    await _secure.write(key: 'account:$id:publicKey', value: publicKey);
    await _secure.write(key: 'account:$id:address', value: address);
    await _secure.write(key: 'account:$id:hdIndex', value: index.toString());

    // Persist index
    final items = await list();
    final next = [...items, meta];
    await _saveIndex(next);
    await setActiveId(id);

    // Return full result for immediate display only
    return AccountCreationResult(
      mnemonic: mnemonic,
      privateKey: privateKey,
      publicKey: publicKey,
      address: address,
      hdIndex: index,
      success: true,
      error: null,
    );
  }

  Future<void> markBackupConfirmed(String id) async {
    final items = await list();
    final idx = items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final updated = [...items];
    updated[idx] = updated[idx].copyWith(backupConfirmed: true);
    await _saveIndex(updated);
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
    Log.d('ACCOUNTS_REPO', 'importFromMnemonic - start (name: $name, mnemonic word count: $wordCount)');

    try {
      // Use Rust backend to derive keys from mnemonic
      Log.d('ACCOUNTS_REPO', 'Calling Rust backend accountFromSeed...');
      final accountExport = accountFromSeed(
        phrase: mnemonic.trim(),
        passphrase: null,
        index: 0, // Use index 0 for imported accounts
      );
      Log.d('ACCOUNTS_REPO', 'Account derived successfully from backend');

      // Extract keys from AccountExport
      final privateKey = accountExport.secretKeyHex;
      final publicKey = accountExport.publicKeyHex;
      final address = accountExport.publicKeyHashHex; // Use hex format for consistency

      Log.d('ACCOUNTS_REPO', 'Private key length: ${privateKey.length}');
      Log.d('ACCOUNTS_REPO', 'Public key length: ${publicKey.length}');
      Log.d('ACCOUNTS_REPO', 'Address: $address');

      Log.d('ACCOUNTS_REPO', 'Calling _persistNew...');
      final result = await _persistNew(
        name: name,
        address: address,
        publicKey: publicKey,
        privateKey: privateKey,
      );
      Log.d('ACCOUNTS_REPO', 'importFromMnemonic - success (account id: ${result.id})');
      return result;
    } catch (e, stackTrace) {
      Log.e('ACCOUNTS_REPO', 'importFromMnemonic - FAILED with exception', e, stackTrace);
      return null;
    }
  }

  /// Import an account from a raw private key (hex). Mnemonic is not applicable.
  Future<AccountMeta?> importFromPrivateKey({
    required String name,
    required String privateKey,
  }) async {
    try {
      final EthPrivateKey cryptoPrivateKey = EthPrivateKey.fromHex(privateKey);
      final EthereumAddress cryptoAddress = cryptoPrivateKey.address;
      // Public key derivation from private key may not be available directly; set to placeholder if needed
      final publicKey = '';
      return await _persistNew(
        name: name,
        address: cryptoAddress.hex,
        publicKey: publicKey,
        privateKey: privateKey,
      );
    } catch (_) {
      return null;
    }
  }

  Future<AccountMeta> _persistNew({
    required String name,
    required String address,
    required String publicKey,
    required String privateKey,
  }) async {
    Log.d('ACCOUNTS_REPO', '_persistNew - start (name: $name, address: $address)');

    Log.d('ACCOUNTS_REPO', 'Retrieving current account list...');
    final current = await list();
    Log.d('ACCOUNTS_REPO', 'Current account count: ${current.length}');

    final index = current.length;
    final id = _makeId(address, index);
    Log.d('ACCOUNTS_REPO', 'Generated account ID: $id (index: $index)');

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
    Log.d('ACCOUNTS_REPO', 'AccountMeta created');

    Log.d('ACCOUNTS_REPO', 'Writing to secure storage (4 keys)...');
    await _secure.write(key: 'account:$id:privateKey', value: privateKey);
    await _secure.write(key: 'account:$id:publicKey', value: publicKey);
    await _secure.write(key: 'account:$id:address', value: address);
    await _secure.write(key: 'account:$id:hdIndex', value: index.toString());
    Log.d('ACCOUNTS_REPO', 'Secure storage writes complete');

    final next = [...current, meta];
    Log.d('ACCOUNTS_REPO', 'Saving account index (total accounts: ${next.length})...');
    await _saveIndex(next);
    Log.d('ACCOUNTS_REPO', 'Index saved successfully');

    Log.d('ACCOUNTS_REPO', 'Setting active account ID to: $id');
    await setActiveId(id);
    Log.d('ACCOUNTS_REPO', '_persistNew - complete (id: $id)');

    return meta;
  }

  String _makeId(String address, int index) {
    // Simple deterministic id for now: addr suffix + index
    final suffix = address.length >= 8 ? address.substring(address.length - 8) : address;
    return 'acc_${index}_$suffix';
  }
}
