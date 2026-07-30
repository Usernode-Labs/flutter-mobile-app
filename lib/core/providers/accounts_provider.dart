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

final activeAccountProvider = FutureProvider<AccountMeta?>((ref) async {
  final repo = await ref.watch(accountsProvider.future);
  return repo.getActive();
});

const _kReconcilePendingKeyBase = 'account:reconcile_pending';

/// Marks that a sign-in happened whose account reconciliation has not yet
/// completed. Set by `completeLogin`, cleared by `NodeAccountReconciler`
/// after a successful run. On boot restore (stored token, no sign-in
/// transition) the post-sign-in sync only re-runs the reconcile when this
/// marker is set — so an interrupted reconcile can't strand the device
/// under the previous identity across restarts, while normal launches stay
/// network-free.
Future<void> markAccountReconcilePending() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(NetworkPrefs.prefixKey(_kReconcilePendingKeyBase), true);
}

Future<bool> isAccountReconcilePending() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(NetworkPrefs.prefixKey(_kReconcilePendingKeyBase)) ??
      false;
}

Future<void> clearAccountReconcilePending() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(NetworkPrefs.prefixKey(_kReconcilePendingKeyBase));
}

/// Recomputes the active per-identity storage bucket ([NetworkPrefs]). A guest
/// session always resolves to the guest bucket (no on-chain identity loaded);
/// otherwise the bucket follows the active on-chain account's address. Call on
/// every identity transition (boot, login, logout, guest, account activation).
Future<void> refreshActiveAccountBucket({required bool guest}) async {
  if (guest) {
    NetworkPrefs.setActiveBucket(null, guest: true);
    return;
  }
  final repo = await AccountsRepository.create();
  final active = await repo.getActive();
  NetworkPrefs.setActiveBucket(active?.address, guest: false);
}

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
