import 'package:flutter/foundation.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';

/// Capability to begin one wallet-signing effect.
///
/// Construction is the gate: guests and unsettled identities cannot obtain a
/// value accepted by wallet effect APIs.
@immutable
class WalletIdentityLease {
  const WalletIdentityLease._({
    required this.identityLease,
    required this.accountScope,
  });

  final IdentityLease identityLease;
  final AccountStorageScope accountScope;

  String get address => accountScope.address;

  static WalletIdentityLease? capture(
    Identity identity, {
    String? network,
  }) {
    if (!identity.allowsSigning) return null;
    final identityLease = IdentityLease.capture(identity, network: network);
    final accountScope = identityLease.accountScope;
    if (accountScope == null) return null;
    return WalletIdentityLease._(
      identityLease: identityLease,
      accountScope: accountScope,
    );
  }

  bool get isCurrent => identityLease.isCurrent;
}

/// Stable owner for wallet data on one chain.
///
/// Explorer responses and their persisted caches may finish in this scope
/// after a node restart. Node-local reads additionally require a
/// [WalletRuntimeLease].
@immutable
class WalletDataScope {
  const WalletDataScope({
    required this.accountScope,
    required this.chainId,
  }) : assert(chainId != '');

  final AccountStorageScope accountScope;
  final String chainId;

  @override
  bool operator ==(Object other) =>
      other is WalletDataScope &&
      accountScope == other.accountScope &&
      chainId == other.chainId;

  @override
  int get hashCode => Object.hash(accountScope, chainId);
}

/// Exact authority for node-local wallet reads from one runtime generation.
@immutable
class WalletRuntimeLease {
  const WalletRuntimeLease({
    required this.dataScope,
    required this.runtimeGeneration,
  });

  final WalletDataScope dataScope;
  final int runtimeGeneration;

  AccountStorageScope get accountScope => dataScope.accountScope;
  String get chainId => dataScope.chainId;

  @override
  bool operator ==(Object other) =>
      other is WalletRuntimeLease &&
      dataScope == other.dataScope &&
      runtimeGeneration == other.runtimeGeneration;

  @override
  int get hashCode => Object.hash(dataScope, runtimeGeneration);
}
