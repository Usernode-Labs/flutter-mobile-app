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
  static const _kAdoptionMarkerKeyBase = 'accounts:adopting';
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

  /// Explicit one-time adoption path for the pre-namespace development data.
  static Future<AccountsRepository> createForMigration({
    SessionAuthorityGateway? sessionAuthority,
    AccountSigner? signer,
    AccountDeriver? accountDeriver,
  }) async {
    final repository = await create(
      sessionAuthority: sessionAuthority,
      signer: signer,
      accountDeriver: accountDeriver,
    );
    await repository._adoptLegacyRegistry();
    return repository;
  }

  /// Claims the pre-namespace registry for the signed-in user, once.
  ///
  /// Installs that predate the namespace hold their accounts under the bare
  /// network-prefixed keys. The first authenticated read moves them into that
  /// user's namespace and removes the legacy copy — leaving it behind would
  /// hand the same accounts to whoever signs in next, which is exactly the
  /// segregation the namespace exists to provide.
  ///
  /// The destination is written before the source is removed, so an
  /// interrupted migration leaves the accounts readable under one key or the
  /// other, never neither.
  /// Marks an adoption that has written its destination but not yet removed
  /// its source, so an interrupted one can be told apart from bare rows that
  /// were never this user's. Holds the adopting namespace.
  String get _adoptionMarkerKey =>
      NetworkPrefs.prefixKeyWith(_kAdoptionMarkerKeyBase, _network);

  Future<void> _adoptLegacyRegistry() async {
    final namespace = _identityNamespace;
    if (namespace == null) return;
    final legacyIndexKey = NetworkPrefs.prefixKeyWith(_kIndexKeyBase, _network);
    final legacyActiveIdKey =
        NetworkPrefs.prefixKeyWith(_kActiveIdKeyBase, _network);
    final legacyIndex = _prefs.getString(legacyIndexKey);
    final interrupted = _prefs.getString(_adoptionMarkerKey) == namespace;

    if (legacyIndex == null) {
      if (interrupted) await _prefs.remove(_adoptionMarkerKey);
      // A stale bare active id with no index is residue either way.
      if (_prefs.getString(legacyActiveIdKey) != null) {
        await _prefs.remove(legacyActiveIdKey);
      }
      return;
    }

    if (_prefs.getString(_kIndexKey) != null) {
      if (!interrupted) {
        // A destination that exists without a marker means these bare rows
        // were never part of this user's adoption. They still cannot be
        // attributed to anyone, but that is retired at the session boundary
        // (see [retireUnnamespacedRegistry]) rather than silently here.
        return;
      }
      // The marker proves a previous adoption wrote the destination and died
      // before removing its source. Finishing it is what makes adoption
      // idempotent: a duplicate bare copy is exactly the un-attributable
      // registry the namespace exists to prevent.
      _log.warn('Finishing a pre-namespace registry adoption that was '
          'interrupted before its source was removed');
      await _prefs.remove(legacyIndexKey);
      await _prefs.remove(legacyActiveIdKey);
      await _prefs.remove(_adoptionMarkerKey);
      return;
    }

    final legacyActiveId = _prefs.getString(legacyActiveIdKey);
    _log.info('Adopting the pre-namespace account registry for this user');

    // Marker BEFORE the destination write: a crash anywhere after this leaves
    // the accounts readable under one key or the other, and leaves proof of
    // which user the leftover source belongs to.
    await _prefs.setString(_adoptionMarkerKey, namespace);
    await _prefs.setString(_kIndexKey, legacyIndex);
    if (legacyActiveId != null) {
      await _prefs.setString(_kActiveIdKey, legacyActiveId);
    }
    await _prefs.remove(legacyIndexKey);
    await _prefs.remove(legacyActiveIdKey);
    await _prefs.remove(_adoptionMarkerKey);
  }

  /// Removes the shared, unnamespaced registry keys.
  ///
  /// Run at every sign-out, unconditionally. A non-null namespace does NOT
  /// prove the bare keys are absent: `identityHash` is nullable by design (so
  /// a whole session can run on the bare keys), a same-participant renewal can
  /// acquire a namespace for a registry that is still bare, and an
  /// interrupted [_adoptLegacyRegistry] leaves both copies. Whatever survives
  /// here is a registry no identity can be shown to own — retaining it across
  /// the boundary would republish the signed-out user's wallet as a
  /// locally-signable account and hand it to whoever signs in next.
  ///
  /// Callers must let the pending adoption run first (construct an
  /// [AccountsRepository] while the namespace is still valid), so a wallet
  /// that CAN be attributed is moved rather than dropped.
  ///
  /// The key material in secure storage is deliberately left alone: without an
  /// index nothing resolves it, and destroying a user's keys is not this
  /// boundary's call to make.
  ///
  /// Returns whether the bare keys are now absent.
  static Future<bool> retireUnnamespacedRegistry() async {
    final prefs = await SharedPreferences.getInstance();
    final network = await NetworkPrefs.getNetwork();
    final indexKey = NetworkPrefs.prefixKeyWith(_kIndexKeyBase, network);
    final activeIdKey = NetworkPrefs.prefixKeyWith(_kActiveIdKeyBase, network);
    final markerKey =
        NetworkPrefs.prefixKeyWith(_kAdoptionMarkerKeyBase, network);
    await prefs.remove(markerKey);
    final hadAny = prefs.getString(indexKey) != null ||
        prefs.getString(activeIdKey) != null;
    if (hadAny) {
      _log.warn('Retiring an unnamespaced account registry at a session '
          'boundary: it cannot be proven to belong to one user');
      await prefs.remove(indexKey);
      await prefs.remove(activeIdKey);
    }
    // Verified rather than assumed — the removal is a security boundary.
    return prefs.getString(indexKey) == null &&
        prefs.getString(activeIdKey) == null;
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

  Future<bool> hasAny() async {
    final accounts = await list();
    return accounts.isNotEmpty;
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
    final accounts = await list();
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
    return _sessionAuthority.runAccountEffect(
      capability: capability,
      operationId: 'account:metadata',
      effect: () => _authorizedAccountUnchecked(capability),
    );
  }

  Future<String?> getSecretKey(AccountCapability capability) {
    _assertCapabilityPinned(capability);
    return _sessionAuthority.runAccountEffect(
      capability: capability,
      operationId: 'account:key-read',
      effect: () async {
        await _authorizedAccountUnchecked(capability);
        await _verifyStoredAddress(capability);
        return _secure.read(key: capability.secretKeyRef);
      },
    );
  }

  Future<String> signMessage(
    AccountCapability capability,
    String message,
  ) {
    _assertCapabilityPinned(capability);
    return _sessionAuthority.runAccountEffect(
      capability: capability,
      operationId: 'account:sign-message',
      effect: () async {
        await _authorizedAccountUnchecked(capability);
        await _verifyStoredAddress(capability);
        final secretKey = await _secure.read(key: capability.secretKeyRef);
        if (secretKey == null || secretKey.isEmpty) {
          throw StateError('Authorized account key is missing');
        }
        return _signer(secretKey: secretKey, message: message);
      },
    );
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
    if (getActiveId() != capability.accountId) {
      throw const StaleAuthCredentialException();
    }
    final accounts = await list();
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
    return _sessionAuthority.runAccountReconciliationEffect(
      lease: lease,
      operationId: 'account:reconcile',
      effect: () async {
        final accounts = await list();
        final retained = accounts.where((item) => item.address == address);
        if (retained.isNotEmpty) {
          final account = retained.first;
          final storedAddress = await _secure.read(
            key: '$_network:account:${account.id}:address',
          );
          if (storedAddress != address) {
            throw const StaleAuthCredentialException();
          }
          final changed = getActiveId() != account.id;
          if (changed) {
            await setActiveId(account.id);
          }
          return AccountReconciliationResult(
            account: account,
            changed: changed,
          );
        }

        final derived = _deriveProvisionedSecret(secretKey);
        if (derived.address != address) {
          throw StateError(
            'Provisioned secret key does not derive the provisioned address',
          );
        }
        final account = await _persistNew(
          name: name,
          address: derived.address,
          publicKey: derived.publicKey,
          secretKey: derived.secretKey,
          derivationPath: 'imported',
        );
        return AccountReconciliationResult(account: account, changed: true);
      },
    );
  }

  rust_account.AccountExport _deriveProvisionedSecret(String secretKey) {
    try {
      return _accountDeriver(secretKey: secretKey.trim());
    } catch (error) {
      throw AccountImportException(AccountImportFailure.keyDerivation, error);
    }
  }
}
