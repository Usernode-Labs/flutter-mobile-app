import 'dart:async';

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
    return SessionIdentityProjection._(
      nativeRevision: nativeRevision,
      status: SessionProjectionStatus.ready,
      participantId: participantId,
      accountId: accountId,
      address: address,
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
