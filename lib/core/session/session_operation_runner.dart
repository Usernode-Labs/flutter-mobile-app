import 'dart:async';

import 'package:crypto_mobile_app/src/rust/frb_types.dart' as perf_types;

/// Feature-facing admission into one exact published session.
///
/// A runner is one-shot: once its session begins closing, every later [run]
/// rejects permanently. Features cannot close a runner or publish a successor.
abstract interface class SessionOperationRunner {
  Future<T> run<T>(
    FutureOr<T> Function(SessionOperation operation) body,
  );
}

/// Authority scoped to one admitted callback.
///
/// Child work that may outlive the immediate callback must be registered here
/// so session drain waits for it. Feature-specific effect façades consume this
/// value internally; it exposes no raw sink or native client.
abstract interface class SessionOperation {
  Future<T> runChild<T>(
    FutureOr<T> Function(SessionOperation child) body,
  );

  Future<SessionNodeStatus> readNodeStatus();

  Future<SessionWalletSnapshot> readWallet();

  Future<SessionTransactionSubmission> submitTransaction({
    required String destinationAddress,
    required BigInt amount,
    required String memo,
  });

  Future<SessionMessageSignature> signMessage(String message);

  Future<perf_types.PerfCatalog> readDeviceBenchmarkCatalog();

  Future<perf_types.PerfRunHandle> startDeviceBenchmark(
    perf_types.PerfRunProfile profile,
  );

  Future<perf_types.PerfRunStatus?> readDeviceBenchmarkStatus(int runId);

  Future<perf_types.PerfRunReport?> readDeviceBenchmarkResult(int runId);

  Future<bool> cancelDeviceBenchmark(int runId);

  Future<SessionObservabilityRecordResult> recordObservability({
    required SessionObservabilityKind kind,
    required String event,
    String? payloadJson,
  });

  Future<SessionZkPassportVerifyOuterResult> verifyZkPassportOuter({
    required List<int> outerProof,
    required bool facematchStrict,
  });

  Future<SessionZkPassportWrapOuterResult> wrapZkPassportOuter({
    required List<int> outerProof,
    required bool facematchStrict,
  });

  Future<SessionZkPassportVerifyWrappedResult> verifyZkPassportWrapped({
    required List<int> wrappedProof,
    required bool facematchStrict,
  });

  /// Delivers the retained legacy proof completion using the exact vault
  /// credential. Challenge selection remains inside the private platform
  /// adapter until Social supplies a typed proof request.
  Future<int> resolveLegacyZkPassportChallengeId();

  Future<SessionZkPassportCompletion> completeLegacyZkPassport({
    required int challengeId,
    required String sessionId,
    required String nullifierHex,
    String? completedAt,
  });

  Future<SessionDelegationSnapshot> readDelegation();

  Future<SessionDelegationSnapshot> setDelegated(bool delegated);

  Future<SessionSleepSnapshot> readSleep();

  Future<SessionSleepSnapshot> setSleepEnabled(bool enabled);

  /// Applies the exact session-scoped runtime sleep intent.
  Future<SessionSleepSnapshot> setSleeping(bool sleeping);

  Future<SessionSocialPushStatus> readSocialPushStatus({
    required String installationId,
  });

  Future<SessionSocialPushStatus> registerSocialPush(
    SessionSocialPushRegistration request,
  );

  Future<SessionSocialPushStatus> unregisterSocialPush(
    SessionSocialPushUnregistration request,
  );
}

enum SessionObservabilityKind { event, metrics, healthcheck, error }

final class SessionObservabilityRecordResult {
  const SessionObservabilityRecordResult({
    required this.queued,
    required this.discarded,
    this.reason,
  });

  final bool queued;
  final bool discarded;
  final String? reason;
}

/// Closed node status required by the Social chrome.
final class SessionNodeStatus {
  const SessionNodeStatus({
    required this.status,
    this.chain,
    this.localBestHeight,
    this.localBestTimestampMs,
    this.networkBestHeight,
    this.readyPeers,
    this.totalPeers,
    this.syncStalled,
    this.clockDriftMs,
    this.walletDataHydrating,
  });

  final String status;
  final String? chain;
  final int? localBestHeight;
  final int? localBestTimestampMs;
  final int? networkBestHeight;
  final int? readyPeers;
  final int? totalPeers;
  final bool? syncStalled;
  final int? clockDriftMs;
  final bool? walletDataHydrating;

  Map<String, Object?> toBridgeJson() => {
        'status': status,
        'chain': chain,
        'localBestHeight': localBestHeight,
        'localBestTimestampMs': localBestTimestampMs,
        'networkBestHeight': networkBestHeight,
        'readyPeers': readyPeers,
        'connectedPeers': readyPeers,
        'totalPeers': totalPeers,
        'syncStalled': syncStalled,
        'clockDriftMs': clockDriftMs,
        'walletDataHydrating': walletDataHydrating,
      };
}

final class SessionDelegationSnapshot {
  const SessionDelegationSnapshot({
    required this.delegated,
    this.delegateAddress,
    this.delegatedSince,
    this.effectiveEpoch,
  });

  final bool delegated;
  final String? delegateAddress;
  final String? delegatedSince;
  final int? effectiveEpoch;

  Map<String, Object?> toBridgeJson() => {
        'delegate': delegated ? delegateAddress : null,
        'delegated_since': delegated ? delegatedSince : null,
        if (effectiveEpoch != null) 'effective_epoch': effectiveEpoch,
      };
}

final class SessionWalletSnapshot {
  const SessionWalletSnapshot({
    required this.address,
    required this.balance,
    required this.tokenAmount,
    required this.tokenSymbol,
    required this.lastUpdatedMs,
    required this.delegation,
  });

  final String address;
  final BigInt? balance;
  final double? tokenAmount;
  final String? tokenSymbol;
  final int? lastUpdatedMs;
  final SessionDelegationSnapshot delegation;

  Map<String, Object?> toBridgeJson() => {
        'address': address,
        'balance': balance?.toString(),
        'tokenAmount': tokenAmount,
        'tokenSymbol': tokenSymbol,
        'lastUpdatedMs': lastUpdatedMs,
        'staking': delegation.toBridgeJson(),
      };
}

final class SessionTransactionSubmission {
  const SessionTransactionSubmission({required this.transactionId});

  final String transactionId;
}

final class SessionMessageSignature {
  const SessionMessageSignature({
    required this.publicKey,
    required this.signature,
  });

  final String publicKey;
  final String signature;
}

final class SessionZkPassportVerifyOuterResult {
  const SessionZkPassportVerifyOuterResult({
    required this.verified,
    required this.elapsedMs,
    required this.publicInputsHex,
    required this.error,
  });

  final bool verified;
  final int elapsedMs;
  final List<String>? publicInputsHex;
  final String? error;
}

final class SessionZkPassportWrapOuterResult {
  const SessionZkPassportWrapOuterResult({
    required this.wrapped,
    required this.elapsedMs,
    required this.wrappedProofB64Url,
    required this.wrappedProofSizeBytes,
    required this.error,
  });

  final bool wrapped;
  final int elapsedMs;
  final String? wrappedProofB64Url;
  final int? wrappedProofSizeBytes;
  final String? error;
}

final class SessionZkPassportVerifyWrappedResult {
  const SessionZkPassportVerifyWrappedResult({
    required this.verified,
    required this.elapsedMs,
    required this.error,
  });

  final bool verified;
  final int elapsedMs;
  final String? error;
}

final class SessionZkPassportCompletion {
  const SessionZkPassportCompletion({required this.challengeId});

  final int challengeId;
}

final class SessionSleepSnapshot {
  const SessionSleepSnapshot({required this.enabled});

  final bool enabled;
}

/// Inert provider registration data. Authentication is always taken from the
/// exact native session; no bearer can be supplied by Flutter.
final class SessionSocialPushRegistration {
  const SessionSocialPushRegistration({
    required this.installationId,
    required this.providerToken,
    required this.platform,
    required this.permissionStatus,
    required this.mutationRevision,
  });

  final String installationId;
  final String providerToken;
  final String platform;
  final String permissionStatus;
  final int mutationRevision;
}

final class SessionSocialPushUnregistration {
  const SessionSocialPushUnregistration({
    required this.installationId,
    required this.mutationRevision,
    required this.reason,
  });

  final String installationId;
  final int mutationRevision;
  final String reason;
}

final class SessionSocialPushStatus {
  const SessionSocialPushStatus({
    required this.registered,
    required this.deliveryActive,
    required this.mutationRevision,
  });

  final bool registered;
  final bool deliveryActive;
  final int mutationRevision;
}

/// Admission was already closed for this exact session.
final class SessionAdmissionClosedException implements Exception {
  const SessionAdmissionClosedException();

  @override
  String toString() => 'SessionAdmissionClosedException()';
}

/// A callback retained and reused its operation after structured work settled.
final class SessionOperationExpiredException implements Exception {
  const SessionOperationExpiredException();

  @override
  String toString() => 'SessionOperationExpiredException()';
}

enum SessionProjectionStatus {
  signedOut,
  ready,
}

/// Immutable, non-authoritative identity/status information for features.
///
/// [nativeRevision] is the canonical unsigned decimal representation used by
/// the cross-repository protocol; it is data, not a native capability.
final class SessionIdentityProjection {
  const SessionIdentityProjection._({
    required this.nativeRevision,
    required this.status,
    this.participantId,
    this.accountId,
    this.address,
    this.publicKey,
  });

  factory SessionIdentityProjection.signedOut({
    required String nativeRevision,
  }) {
    _validateNativeRevision(nativeRevision);
    return SessionIdentityProjection._(
      nativeRevision: nativeRevision,
      status: SessionProjectionStatus.signedOut,
    );
  }

  factory SessionIdentityProjection.ready({
    required String nativeRevision,
    required int participantId,
    required String accountId,
    required String address,
    required String publicKey,
  }) {
    _validateNativeRevision(nativeRevision);
    if (participantId <= 0) {
      throw ArgumentError.value(
        participantId,
        'participantId',
        'Must be positive.',
      );
    }
    if (accountId.isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'Must be nonempty.');
    }
    if (address.isEmpty) {
      throw ArgumentError.value(address, 'address', 'Must be nonempty.');
    }
    if (publicKey.isEmpty) {
      throw ArgumentError.value(publicKey, 'publicKey', 'Must be nonempty.');
    }
    return SessionIdentityProjection._(
      nativeRevision: nativeRevision,
      status: SessionProjectionStatus.ready,
      participantId: participantId,
      accountId: accountId,
      address: address,
      publicKey: publicKey,
    );
  }

  static final BigInt _maxU64 = BigInt.parse('18446744073709551615');

  static void _validateNativeRevision(String value) {
    final parsed = BigInt.tryParse(value);
    if (parsed == null ||
        parsed.isNegative ||
        parsed > _maxU64 ||
        parsed.toString() != value) {
      throw ArgumentError.value(
        value,
        'nativeRevision',
        'Must be a canonical unsigned 64-bit decimal string.',
      );
    }
  }

  final String nativeRevision;
  final SessionProjectionStatus status;
  final int? participantId;
  final String? accountId;
  final String? address;
  final String? publicKey;
}

/// The one immutable feature publication for an exact session state.
///
/// A signed-out publication carries a permanently rejecting [operations]
/// runner; only a separately published ready session admits feature work.
final class SessionFeatureAccess {
  const SessionFeatureAccess({
    required this.identity,
    required this.operations,
  });

  final SessionIdentityProjection identity;
  final SessionOperationRunner operations;
}

/// Read-only view of the current immutable feature publication.
///
/// The implementation swaps [current] before emitting exactly one [changes]
/// event. No notifier, host, mutable scope, or publication callback is exposed.
abstract interface class SessionFeatureAccessView {
  SessionFeatureAccess get current;

  Stream<SessionFeatureAccess> get changes;
}
