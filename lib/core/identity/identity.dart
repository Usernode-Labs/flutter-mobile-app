import 'package:flutter/foundation.dart';

import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

/// Where the current identity is in its lifecycle.
///
/// The app has exactly one identity at a time, and it moves through these
/// phases under the control of `SessionController` — nothing else transitions
/// it. The phases that matter for gating:
///
/// - [reconciling]: a session exists but the device's account-scoped state
///   (registry, storage bucket, node runtime key) has NOT been confirmed to
///   belong to it. Signing, node starts, and wallet routes are refused in
///   this phase — the active local account may still belong to a previously
///   signed-in user.
/// - [ready]: the identity is fully settled — account activated, bucket
///   resolved, and participant id installed. Node admission may now open.
enum IdentityPhase {
  /// Boot: nothing resolved yet.
  unknown,

  /// An identity-changing transition is closing account-sensitive gates.
  transitioning,

  /// No session and no explicit guest choice.
  unauthenticated,

  /// Explicit guest session. Guest node ownership is not currently exposed.
  guest,

  /// Authenticated, but the account reconcile has not confirmed ownership.
  reconciling,

  /// Authenticated and fully settled.
  ready,
}

/// An immutable snapshot of "who the app is right now".
///
/// Every field is fixed at publish time. Async work captures the snapshot
/// once when it starts and compares [epoch] before applying results — a
/// changed epoch means the identity this work was started for no longer
/// exists, and the work must abort rather than apply another identity's
/// result. See docs/identity-lifecycle-invariants.md.
@immutable
class Identity {
  const Identity({
    required this.epoch,
    required this.phase,
    this.participantId,
    this.accountId,
    this.address,
    this.provisionedSeasonId,
  });

  const Identity.unknown({this.epoch = 0})
      : phase = IdentityPhase.unknown,
        participantId = null,
        accountId = null,
        address = null,
        provisionedSeasonId = null;

  /// Monotonic identity generation. Bumped on every transition that changes
  /// WHO the identity is (initial login, participant replacement, logout,
  /// guest, 401, season rollover) — NOT on same-participant bearer rotation
  /// or reconciling → ready, which preserve/complete the same identity.
  final int epoch;

  final IdentityPhase phase;

  /// The platform user id (v4 `user.id`) for authenticated identities.
  final int? participantId;

  /// The active on-chain account confirmed to belong to this identity
  /// (null until the reconcile confirms one, and for guests).
  final String? accountId;

  /// The confirmed account's address. Determines [bucket].
  final String? address;

  /// The season `/wallet/provision` allocated the account for. Used to
  /// detect season rollovers that require re-provisioning.
  final int? provisionedSeasonId;

  /// The per-identity storage bucket all account-scoped reads/writes resolve
  /// to. Guest bucket until an account is confirmed.
  String get bucket => address == null
      ? NetworkPrefs.guestBucket
      : NetworkPrefs.bucketForAddress(address!);

  bool get isAuthenticated =>
      phase == IdentityPhase.reconciling || phase == IdentityPhase.ready;

  /// Whether account-scoped state can be trusted to belong to this identity.
  bool get isSettled =>
      phase != IdentityPhase.transitioning &&
      phase != IdentityPhase.reconciling &&
      phase != IdentityPhase.unknown;

  /// Current product eligibility for owning an active node runtime.
  ///
  /// The keyless/view-only construction remains available below this gate for
  /// a future explicit guest-node feature. Until its key and operating mode
  /// are decided, only a signed-in identity whose account binding is fully
  /// reconciled may start or resume a node.
  bool get allowsNodeStart => phase == IdentityPhase.ready;

  /// Signing (dApp bridge, Send flow) requires an authenticated identity whose
  /// account ownership has been reconciled. Retained local wallets grant no
  /// authority while logged out or in guest mode.
  bool get allowsSigning => phase == IdentityPhase.ready;

  /// Exact equality for async work that must not cross identity publication.
  bool sameScopeAs(Identity other) =>
      epoch == other.epoch &&
      phase == other.phase &&
      participantId == other.participantId &&
      accountId == other.accountId &&
      address == other.address &&
      provisionedSeasonId == other.provisionedSeasonId;

  Identity copyWith({
    int? epoch,
    IdentityPhase? phase,
    int? participantId,
    String? accountId,
    String? address,
    int? provisionedSeasonId,
    bool clearAccount = false,
    bool clearParticipantId = false,
    bool clearProvisionedSeasonId = false,
  }) {
    return Identity(
      epoch: epoch ?? this.epoch,
      phase: phase ?? this.phase,
      participantId:
          clearParticipantId ? null : (participantId ?? this.participantId),
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      address: clearAccount ? null : (address ?? this.address),
      provisionedSeasonId: clearProvisionedSeasonId
          ? null
          : (provisionedSeasonId ?? this.provisionedSeasonId),
    );
  }

  @override
  String toString() => 'Identity(epoch: $epoch, phase: ${phase.name}, '
      'participantId: $participantId, accountId: $accountId, '
      'seasonId: $provisionedSeasonId)';
}

/// The exact credential attached to one authenticated request.
@immutable
class AuthCredentialLease {
  const AuthCredentialLease({
    required this.epoch,
    required this.token,
  });

  final int epoch;
  final String token;

  @override
  String toString() => 'AuthCredentialLease(epoch: $epoch, token: <redacted>)';
}

/// The credential changed while an authenticated request was being prepared.
class StaleAuthCredentialException implements Exception {
  const StaleAuthCredentialException();

  @override
  String toString() => 'StaleAuthCredentialException()';
}

/// Ambient read-only mirror of the current [Identity] for code that has no
/// provider access (the Rust node façade, HTTP clients, webview bridge
/// handlers).
///
/// Single writer: only `SessionController` publishes here (enforced by
/// ds_lints). Everything else captures `IdentitySnapshots.current` once at
/// the start of an operation and compares epochs before applying results.
class IdentitySnapshots {
  IdentitySnapshots._();

  static Identity _current = const Identity.unknown();

  static Identity get current => _current;

  /// Publish a new snapshot. ONLY `SessionController` may call this — the
  /// snapshot must never diverge from the provider-visible identity.
  static void publish(Identity identity) => _current = identity;

  @visibleForTesting
  static void reset() => _current = const Identity.unknown();
}
