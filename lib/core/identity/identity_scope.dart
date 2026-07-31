import 'package:flutter/foundation.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

/// Stable storage identity for data owned by one authenticated participant.
///
/// Unlike [IdentityLease], this scope deliberately excludes the identity
/// epoch and lifecycle phase. A request that was already reading participant
/// data may safely finish into this participant's cache after a logout; what
/// it must not do is publish that value as another participant's data.
@immutable
class AuthenticatedUserScope {
  const AuthenticatedUserScope({required this.participantId});

  final int participantId;

  @override
  bool operator ==(Object other) =>
      other is AuthenticatedUserScope && participantId == other.participantId;

  @override
  int get hashCode => participantId.hashCode;
}

/// Stable address for account-owned data.
///
/// Repositories and caches should accept this value instead of consulting the
/// ambient active account, bucket, or network after an `await`.
@immutable
class AccountStorageScope {
  const AccountStorageScope({
    required this.network,
    required this.bucket,
    required this.accountId,
    required this.address,
  });

  final String network;
  final String bucket;
  final String accountId;
  final String address;

  String preferenceKey(String key) =>
      NetworkPrefs.prefixKeyWith('acct:$bucket:$key', network);

  @override
  bool operator ==(Object other) =>
      other is AccountStorageScope &&
      network == other.network &&
      bucket == other.bucket &&
      accountId == other.accountId &&
      address == other.address;

  @override
  int get hashCode => Object.hash(network, bucket, accountId, address);
}

/// Exact, ephemeral authority captured for an identity-sensitive effect.
///
/// This lease intentionally holds the immutable [Identity] instead of copying
/// all of its fields into every domain lease. Domain capabilities wrap it and
/// add only the extra authority they actually need.
@immutable
class IdentityLease {
  const IdentityLease({
    required this.identity,
    required this.network,
  });

  factory IdentityLease.capture(
    Identity identity, {
    String? network,
  }) =>
      IdentityLease(
        identity: identity,
        network: network ?? NetworkPrefs.currentNetwork,
      );

  final Identity identity;
  final String network;

  bool matches(
    Identity candidate, {
    required String currentNetwork,
  }) =>
      identity.sameScopeAs(candidate) && network == currentNetwork;

  bool get isCurrent => matches(
        IdentitySnapshots.current,
        currentNetwork: NetworkPrefs.currentNetwork,
      );

  AuthenticatedUserScope? get authenticatedUserScope {
    final participantId = identity.participantId;
    if (!identity.isAuthenticated || participantId == null) return null;
    return AuthenticatedUserScope(participantId: participantId);
  }

  AccountStorageScope? get accountScope {
    final accountId = identity.accountId;
    final address = identity.address;
    if (accountId == null ||
        accountId.isEmpty ||
        address == null ||
        address.isEmpty) {
      return null;
    }
    return AccountStorageScope(
      network: network,
      bucket: identity.bucket,
      accountId: accountId,
      address: address,
    );
  }
}

/// Capability for an authenticated participant effect.
///
/// [scope] is the stable data owner; [identityLease] is the ephemeral authority
/// that must still be current when an authenticated transport begins.
@immutable
class AuthenticatedUserLease {
  const AuthenticatedUserLease._({
    required this.identityLease,
    required this.scope,
  });

  final IdentityLease identityLease;
  final AuthenticatedUserScope scope;

  static AuthenticatedUserLease? capture(
    Identity identity, {
    String? network,
  }) {
    final identityLease = IdentityLease.capture(identity, network: network);
    final scope = identityLease.authenticatedUserScope;
    if (scope == null) return null;
    return AuthenticatedUserLease._(
      identityLease: identityLease,
      scope: scope,
    );
  }

  bool get isCurrent => identityLease.isCurrent;
}

enum NodeStartAuthorityKind { settledIdentity, reconciliation }

/// Complete authority for one node-start request.
///
/// Normal callers capture it from a settled identity. The reconciler instead
/// supplies the exact account it has just provisioned, because a reconciling
/// [Identity] deliberately does not claim that account yet. This replaces the
/// old boolean override, which could bypass the lifecycle gate without saying
/// which identity, network, or account it was allowed to start.
@immutable
class NodeStartAuthority {
  const NodeStartAuthority._({
    required this.identityLease,
    required this.accountScope,
    required this.kind,
  });

  final IdentityLease identityLease;
  final AccountStorageScope? accountScope;
  final NodeStartAuthorityKind kind;

  String get network => identityLease.network;
  bool get isReconciliation => kind == NodeStartAuthorityKind.reconciliation;
  bool get isCurrent => identityLease.isCurrent;

  static NodeStartAuthority? capture(
    Identity identity, {
    String? network,
  }) {
    if (!identity.allowsNodeStart) return null;
    final lease = IdentityLease.capture(identity, network: network);
    final accountScope = lease.accountScope;
    if (identity.phase != IdentityPhase.guest && accountScope == null) {
      return null;
    }
    return NodeStartAuthority._(
      identityLease: lease,
      accountScope: accountScope,
      kind: NodeStartAuthorityKind.settledIdentity,
    );
  }

  static NodeStartAuthority? forReconciliation({
    required IdentityLease identityLease,
    required AccountStorageScope accountScope,
  }) {
    final identity = identityLease.identity;
    if (identity.phase != IdentityPhase.reconciling ||
        accountScope.network != identityLease.network ||
        accountScope.bucket !=
            NetworkPrefs.bucketForAddress(accountScope.address) ||
        accountScope.accountId.isEmpty ||
        accountScope.address.isEmpty) {
      return null;
    }
    return NodeStartAuthority._(
      identityLease: identityLease,
      accountScope: accountScope,
      kind: NodeStartAuthorityKind.reconciliation,
    );
  }

  bool sameRequestAuthorityAs(NodeStartAuthority other) =>
      kind == other.kind &&
      accountScope == other.accountScope &&
      identityLease.network == other.identityLease.network &&
      identityLease.identity.sameScopeAs(other.identityLease.identity);
}

/// Authority proven for the process-global runtime currently tracked by this
/// Dart engine. A null [accountScope] means the runtime is keyless.
@immutable
class NodeRuntimeAuthority {
  const NodeRuntimeAuthority({
    required this.network,
    required this.accountScope,
    required this.generation,
  });

  final String network;
  final AccountStorageScope? accountScope;
  final int generation;

  bool get isKeyless => accountScope == null;

  bool matchesStart(
    NodeStartAuthority start, {
    required bool keyless,
    required int currentGeneration,
  }) =>
      generation == currentGeneration &&
      network == start.network &&
      isKeyless == keyless &&
      (keyless || accountScope == start.accountScope);
}

/// The identity or selected network changed before a protected effect began.
class StaleIdentityLeaseException implements Exception {
  const StaleIdentityLeaseException();

  @override
  String toString() => 'StaleIdentityLeaseException()';
}
