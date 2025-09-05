import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/account.dart';
import '../models/account_creation_result.dart';
import 'key_management_service.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32_bip44/dart_bip32_bip44.dart';
import 'package:web3dart/credentials.dart';
import 'package:web3dart/web3dart.dart';

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
    final items = await list();
    return items.isNotEmpty;
  }

  Future<List<AccountMeta>> list() async {
    final raw = _prefs.getString(_kIndexKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => AccountMeta.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
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
    try {
      // Derive same as KeyManagementService
      // Reuse KMS logic by calling createWallet? No, we must use provided mnemonic.
      // Duplicate minimal logic here to avoid storing mnemonic anywhere.
      // ignore: depend_on_referenced_packages
      final String seed = bip39.mnemonicToSeedHex(mnemonic);
      // ignore: depend_on_referenced_packages
      final Chain chain = Chain.seed(seed);
      // Use fixed 0 index for imported seed by default
      final ExtendedKey extendedKey = chain.forPath(KeyManagementService.pathForPrivateKey);
      final privateKey = extendedKey.privateKeyHex();
      final EthPrivateKey cryptoPrivateKey = EthPrivateKey.fromHex(privateKey);
      final EthereumAddress cryptoAddress = await cryptoPrivateKey.extractAddress();
      final ExtendedKey extendedKeyPublic = chain.forPath(KeyManagementService.pathForPublicKey);
      final publicKey = extendedKeyPublic.publicKey().toString();

      return await _persistNew(name: name, address: cryptoAddress.hex, publicKey: publicKey, privateKey: privateKey);
    } catch (_) {
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
      final EthereumAddress cryptoAddress = await cryptoPrivateKey.extractAddress();
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
    final current = await list();
    final index = current.length;
    final id = _makeId(address, index);
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

    await _secure.write(key: 'account:$id:privateKey', value: privateKey);
    await _secure.write(key: 'account:$id:publicKey', value: publicKey);
    await _secure.write(key: 'account:$id:address', value: address);
    await _secure.write(key: 'account:$id:hdIndex', value: index.toString());

    final next = [...current, meta];
    await _saveIndex(next);
    await setActiveId(id);
    return meta;
  }

  String _makeId(String address, int index) {
    // Simple deterministic id for now: addr suffix + index
    final suffix = address.length >= 8 ? address.substring(address.length - 8) : address;
    return 'acc_${index}_$suffix';
  }
}
