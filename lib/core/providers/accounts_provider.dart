import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto_mobile_app/features/wallet/models/account.dart';
import 'package:crypto_mobile_app/src/rust/account.dart' as rust_account;
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_namespace_store.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';

final _log = LoggingService.instance.withTag('usernode/AccountsProvider');

enum AccountImportFailure { keyDerivation, secureStorage }

typedef AccountSigner = String Function({
  required String secretKey,
  required String message,
});
typedef AccountDeriver = rust_account.AccountExport Function({
  required String secretKey,
});

class AccountReconciliationResult {
  const AccountReconciliationResult({
    required this.account,
    required this.changed,
  });

  final AccountMeta account;
  final bool changed;
}

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

  final FlutterSecureStorage _secure;
  final SharedPreferences _prefs;
  final String _network;
  final SessionAuthorityGateway _sessionAuthority;
  final AccountSigner _signer;
  final AccountDeriver _accountDeriver;

  /// The signed-in user's storage namespace, or null before any session
  /// exists. The registry cannot be bucket-scoped — the bucket is derived from
  /// an account's address and the registry is what resolves which account that
  /// is — so this server-issued, address-independent namespace is what keeps
  /// two users on one device from reading each other's accounts.
  final String? _identityNamespace;

  // Network-prefixed keys, additionally namespaced to the signed-in user once
  // one is known.
  String get _kIndexKey => _userKey(_kIndexKeyBase);
  String get _kActiveIdKey => _userKey(_kActiveIdKeyBase);

  String _userKey(String base) => NetworkPrefs.prefixKeyWith(
        _identityNamespace == null ? base : 'user:$_identityNamespace:$base',
        _network,
      );

  AccountsRepository._(
    this._secure,
    this._prefs,
    this._network,
    this._identityNamespace,
    this._sessionAuthority,
    this._signer,
    this._accountDeriver,
  );

  static Future<AccountsRepository> create({
    SessionAuthorityGateway? sessionAuthority,
    AccountSigner? signer,
    AccountDeriver? accountDeriver,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage();
    final network = await NetworkPrefs.getNetwork();
    return AccountsRepository._(
      secure,
      prefs,
      network,
      readIdentityNamespaceIn(prefs, network),
      sessionAuthority ?? SessionAuthorityGateway(),
      signer ?? rust_account.signMessage,
      accountDeriver ?? rust_account.accountFromPrivateKey,
    );
  }

  /// Creates the repository from journal-owned routing, without activating UI
  /// network or identity globals in the headless isolate.
  static Future<AccountsRepository> createForBackground(
    BackgroundRuntimeAuthority authority, {
    SessionAuthorityGateway? sessionAuthority,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return AccountsRepository._(
      const FlutterSecureStorage(),
      prefs,
      authority.network,
      authority.userNamespace,
      sessionAuthority ?? SessionAuthorityGateway(),
      rust_account.signMessage,
      rust_account.accountFromPrivateKey,
    );
  }

  AccountCapability capabilityFor(Identity identity) {
    final namespace = _identityNamespace;
    if (namespace == null) {
      throw const StaleAuthCredentialException();
    }
    return _sessionAuthority.captureAccountCapability(
      identity: identity,
      userNamespace: namespace,
      network: _network,
    );
  }

  AccountCapability capabilityForBackground(
    BackgroundRuntimeAuthority authority,
  ) {
    final capability =
        _sessionAuthority.captureBackgroundAccountCapability(authority);
    _assertCapabilityPinned(capability);
    return capability;
  }

  Future<bool> hasAny(AccountCapability capability) async {
    final accounts = await list(capability);
    return accounts.isNotEmpty;
  }

  Future<List<AccountMeta>> list(AccountCapability capability) async {
    _assertCapabilityPinned(capability);
    return _readIndex(_kIndexKey);
  }

  Future<List<AccountMeta>> _readIndex(String key) async {
    final raw = _prefs.getString(key);
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

  String? getActiveId(AccountCapability capability) {
    _assertCapabilityPinned(capability);
    return _getActiveIdUnchecked();
  }

  String? _getActiveIdUnchecked() => _prefs.getString(_kActiveIdKey);

  Future<void> _setActiveId(String id) async {
    await _prefs.setString(_kActiveIdKey, id);
    // Set Sentry user context for error correlation
    SentryUtil.setUser(id: id);
    _log.debug('Set Sentry user context for account: $id');
  }

  Future<AccountMeta?> getActive(AccountCapability capability) async {
    _assertCapabilityPinned(capability);
    final id = _getActiveIdUnchecked();
    if (id == null) return null;
    final accounts = await _readIndex(_kIndexKey);
    try {
      return accounts.firstWhere((account) => account.id == id);
    } catch (_) {
      return accounts.firstOrNull;
    }
  }

  Future<AccountMeta?> getAuthorizedAccount(
    AccountCapability capability,
  ) {
    _assertCapabilityPinned(capability);
    return _authorizedAccountUnchecked(capability);
  }

  Future<String?> getSecretKey(AccountCapability capability) async {
    _assertCapabilityPinned(capability);
    await _authorizedAccountUnchecked(capability);
    await _verifyStoredAddress(capability);
    return _secure.read(key: capability.secretKeyRef);
  }

  Future<String> signMessage(
    AccountCapability capability,
    String message,
  ) async {
    _assertCapabilityPinned(capability);
    await _authorizedAccountUnchecked(capability);
    await _verifyStoredAddress(capability);
    final secretKey = await _secure.read(key: capability.secretKeyRef);
    if (secretKey == null || secretKey.isEmpty) {
      throw StateError('Authorized account key is missing');
    }
    return _signer(secretKey: secretKey, message: message);
  }

  void _assertCapabilityPinned(AccountCapability capability) {
    if (capability.userNamespace != _identityNamespace ||
        capability.network != _network ||
        capability.bucket !=
            NetworkPrefs.bucketForAddress(capability.address) ||
        capability.secretKeyRef !=
            '$_network:account:${capability.accountId}:secretKey') {
      throw const StaleAuthCredentialException();
    }
  }

  Future<AccountMeta> _authorizedAccountUnchecked(
    AccountCapability capability,
  ) async {
    if (_getActiveIdUnchecked() != capability.accountId) {
      throw const StaleAuthCredentialException();
    }
    final accounts = await _readIndex(_kIndexKey);
    return accounts.firstWhere(
      (account) =>
          account.id == capability.accountId &&
          account.address == capability.address,
      orElse: () => throw const StaleAuthCredentialException(),
    );
  }

  Future<void> _verifyStoredAddress(AccountCapability capability) async {
    final storedAddress = await _secure.read(
      key: '$_network:account:${capability.accountId}:address',
    );
    if (storedAddress != capability.address) {
      throw const StaleAuthCredentialException();
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

    final current = await _readIndex(_kIndexKey);

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
    await _setActiveId(id);
    _log.debug('_persistNew - complete (id: $id)');

    return meta;
  }

  String _makeId(String address, int index) {
    // Simple deterministic id for now: addr suffix + index
    final suffix =
        address.length >= 8 ? address.substring(address.length - 8) : address;
    return 'acc_${index}_$suffix';
  }

  /// Reconciles a backend-provisioned account only during the activation
  /// journal phases that own this address.
  Future<AccountReconciliationResult> reconcileProvisionedAccount({
    required Identity identity,
    required String address,
    required String secretKey,
    required String name,
  }) async {
    final namespace = _identityNamespace;
    if (namespace == null) {
      throw const StaleAuthCredentialException();
    }
    final lease = _sessionAuthority.captureAccountReconciliationLease(
      identity: identity,
      userNamespace: namespace,
      network: _network,
      address: address,
    );
    final provisioned = _deriveProvisionedSecret(secretKey);
    if (provisioned.address != lease.address) {
      throw StateError(
        'Provisioned secret key does not derive the provisioned address',
      );
    }

    final accounts = await _readIndex(_kIndexKey);
    final retained = accounts.where((item) => item.address == lease.address);
    if (retained.isNotEmpty) {
      final account = retained.first;
      if (!await _accountKeyProvesAddress(account, lease.address)) {
        throw const StaleAuthCredentialException();
      }
      final changed = _getActiveIdUnchecked() != account.id;
      if (changed) {
        await _setActiveId(account.id);
      }
      return AccountReconciliationResult(
        account: account,
        changed: changed,
      );
    }

    if (accounts.isEmpty) {
      final legacyKey = NetworkPrefs.prefixKeyWith(_kIndexKeyBase, _network);
      final legacyAccounts = await _readIndex(legacyKey);
      final legacyMatches =
          legacyAccounts.where((item) => item.address == lease.address);
      if (legacyMatches.isNotEmpty) {
        final account = legacyMatches.first;
        if (await _accountKeyProvesAddress(account, lease.address)) {
          await _saveIndex([account]);
          await _setActiveId(account.id);
          return AccountReconciliationResult(account: account, changed: true);
        }
      }
    }

    final account = await _persistNew(
      name: name,
      address: provisioned.address,
      publicKey: provisioned.publicKey,
      secretKey: provisioned.secretKey,
      derivationPath: 'imported',
    );
    return AccountReconciliationResult(account: account, changed: true);
  }

  Future<bool> _accountKeyProvesAddress(
    AccountMeta account,
    String address,
  ) async {
    final storedAddress = await _secure.read(
      key: '$_network:account:${account.id}:address',
    );
    final storedSecret = await _secure.read(
      key: '$_network:account:${account.id}:secretKey',
    );
    if (storedAddress != address || storedSecret == null) return false;
    try {
      return _deriveProvisionedSecret(storedSecret).address == address;
    } on AccountImportException {
      return false;
    }
  }

  rust_account.AccountExport _deriveProvisionedSecret(String secretKey) {
    try {
      return _accountDeriver(secretKey: secretKey.trim());
    } catch (error) {
      throw AccountImportException(AccountImportFailure.keyDerivation, error);
    }
  }
}
