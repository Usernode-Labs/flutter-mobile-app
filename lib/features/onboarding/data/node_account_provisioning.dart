import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/account.dart';

final _log =
    LoggingService.instance.withTag('usernode/NodeAccountProvisioning');

typedef ProvisionedAccountMaterial = ({String address, String publicKey});
typedef ProvisionedAccountDeriver = ProvisionedAccountMaterial Function(
  String secretKey,
);
typedef NodeIdentityBinder = Future<void> Function(
  NodeStartAuthority authority,
);

class ProvisionedWalletIntegrityException implements Exception {
  const ProvisionedWalletIntegrityException(this.reason);

  final String reason;

  @override
  String toString() => 'ProvisionedWalletIntegrityException($reason)';
}

ProvisionedAccountMaterial _deriveProvisionedAccount(String secretKey) {
  final account = accountFromPrivateKey(secretKey: secretKey.trim());
  return (address: account.address, publicKey: account.publicKey);
}

/// Reconciles the local account registry with the signed-in user's
/// platform-allocated on-chain account.
final nodeAccountReconcilerProvider = Provider<NodeAccountReconciler>(
  (ref) => NodeAccountReconciler(ref),
);

/// Fetches the authenticated user's allocated account from
/// `POST /wallet/provision` and makes it the active local account:
/// activated when it already exists in the registry, imported when it does
/// not.
///
/// The retired v2 registration flow imported a server-allocated secret key;
/// the v4 provisioning endpoint restores exactly that: the backend returns
/// the user's allocated account (the same one on every device — migrated
/// users and reinstalls included), allocating one from the season pool for
/// fresh users. A client-generated random key cannot work here: the backend
/// rejects wallets without a matching `onchain_accounts` row (zkPassport
/// completion, slot-outcome attribution), so the account must come from the
/// platform.
///
/// This is the ONLY component that resolves [IdentityPhase.reconciling]: it
/// runs whenever the [SessionController] publishes a reconciling identity
/// (sign-in, interrupted-reconcile boot restore, season rollover) and
/// commits the result through [SessionController.reconcileSucceeded], which
/// re-validates the epoch inside the controller's serialized transition
/// queue. A run whose epoch was superseded (logout, another sign-in) aborts
/// before mutating shared state; the new identity's own reconcile repairs
/// whatever the stale run left behind.
class NodeAccountReconciler {
  NodeAccountReconciler(
    this._ref, {
    NodeIdentityBinder? ensureNodeIdentity,
    Identity Function()? currentIdentity,
    ProvisionedAccountDeriver? deriveProvisionedAccount,
  })  : _ensureNodeIdentity = ensureNodeIdentity ?? _defaultEnsureNodeIdentity,
        _currentIdentity = currentIdentity ?? (() => IdentitySnapshots.current),
        _deriveAccount = deriveProvisionedAccount ?? _deriveProvisionedAccount;

  final Ref _ref;

  /// Brings the node runtime in line with the (just reconciled) active
  /// account. Injectable for tests (the default touches the Rust backend).
  final NodeIdentityBinder _ensureNodeIdentity;

  /// Source of the current identity snapshot; injectable for tests.
  final Identity Function() _currentIdentity;
  final ProvisionedAccountDeriver _deriveAccount;

  Future<bool>? _inFlight;
  int? _inFlightEpoch;

  /// Serializes an account switch with node startup and binds the runtime to
  /// the reconciled active account:
  ///
  /// - waits for any in-flight [RustBackendService.startNode] — a cold-boot
  ///   start may already have captured the OLD account's key while
  ///   `isRunning` is still false, so deciding before it settles would race;
  /// - a running node is stopped (login/rollover already suspended the node,
  ///   but wake/alarm paths may have raced the suspension) and started again
  ///   under the now-active account's key;
  /// - the start receives a [NodeStartAuthority] naming this exact reconcile,
  ///   network, account and address. Reconciliation authority automatically
  ///   forces a fresh runtime because the build-time producer key cannot be
  ///   swapped on a live runtime;
  /// - `startNode() == false` is a failure (including a failed wallet-signer
  ///   bind, which startNode treats as a failed start): the caller must not
  ///   commit the reconcile with an unconfirmed node identity.
  static Future<void> _defaultEnsureNodeIdentity(
    NodeStartAuthority authority,
  ) async {
    final svc = RustBackendService.instance;
    await svc.waitForStartCompletion();
    if (svc.isRunning) {
      await svc.stopNode();
    }
    final started = await svc.startNode(
      authority: authority,
    );
    if (!started) {
      throw StateError('Node failed to start under the reconciled account');
    }
  }

  /// Runs a reconcile, coalescing concurrent calls FOR THE SAME identity
  /// epoch onto one in-flight run (the identity driver and onboarding tap
  /// can race; two parallel imports of the same account would duplicate
  /// registry entries).
  ///
  /// A caller under a NEWER epoch (the user signed out / another user signed
  /// in while a run was in flight) never joins the stale run — its result
  /// would belong to the wrong session. It waits the stale run out, then
  /// starts a fresh one.
  ///
  /// Returns `true` when the reconcile committed (identity became ready).
  /// Returns `false` when there was nothing to do (identity not in the
  /// reconciling phase) or the run was superseded. Throws
  /// ([LeaderboardApiException], [AccountImportException], network errors)
  /// on failure so the caller can surface it; onboarding must not proceed
  /// without an account or the router loops back to onboarding forever
  /// (`hasAny == false`).
  Future<bool> reconcile() {
    final identity = _currentIdentity();
    if (identity.phase != IdentityPhase.reconciling) {
      _log.trace('Reconcile requested but identity is ${identity.phase.name} '
          '- nothing to do');
      return Future.value(false);
    }
    final epoch = identity.epoch;
    final inFlight = _inFlight;
    if (inFlight != null && _inFlightEpoch == epoch) return inFlight;

    late Future<bool> run;
    run = _runAfter(inFlight, epoch).whenComplete(() {
      if (identical(_inFlight, run)) {
        _inFlight = null;
        _inFlightEpoch = null;
      }
    });
    _inFlight = run;
    _inFlightEpoch = epoch;
    return run;
  }

  bool _stillCurrent(int epoch) {
    final identity = _currentIdentity();
    return identity.epoch == epoch &&
        identity.phase == IdentityPhase.reconciling;
  }

  Future<bool> _runAfter(Future<bool>? previous, int epoch) async {
    if (previous != null) {
      try {
        await previous;
      } catch (_) {
        // The stale run's failure was surfaced to its own caller.
      }
    }
    if (!_stillCurrent(epoch)) {
      // Superseded while waiting; the newest identity's caller runs its own.
      return false;
    }
    return _reconcile(epoch);
  }

  /// Resolves the participant ID this reconcile installs into the account
  /// bucket. Normally carried on the reconciling identity snapshot (staged
  /// at login / read from the guest bucket at boot restore); when absent
  /// (legacy interrupted state), it is recovered from the authenticated
  /// `/me` endpoint so a crash can never permanently lose the ID.
  Future<int> _resolveParticipantId(Identity identity) async {
    final identityParticipantId = identity.participantId;
    if (identityParticipantId != null) return identityParticipantId;
    final staged = await loadParticipantIdInBucket(NetworkPrefs.guestBucket);
    if (staged != null) return staged;
    try {
      final me = await _ref.read(accountApiServiceProvider).getMe();
      return me.id;
    } catch (e) {
      _log.warn('Could not recover participant id from /me: $e');
      // A ready identity without a participant id cannot safely address all
      // of its account-scoped state. Keep the reconcile marker and phase so a
      // later retry can recover /me instead of committing a partial identity.
      rethrow;
    }
  }

  Future<bool> _reconcile(int epoch) async {
    // Gate-closing transitions publish the reconciling identity BEFORE
    // their persistence writes finish (see SessionController.completeLogin),
    // so the session token this authenticated call needs may not be
    // readable yet. Wait for the transition queue to drain first.
    await _ref.read(identityProvider.notifier).transitionsSettled;
    if (!_stillCurrent(epoch)) return false;

    final identity = _currentIdentity();
    // Provisioning repairs interrupted legacy reconciles whose participant ID
    // is not available locally yet, so it needs exact request authority—not a
    // participant-owned data scope. `/me` recovers that stable owner below.
    final identityLease = IdentityLease.capture(identity);
    bool workIsCurrent() => _stillCurrent(epoch) && identityLease.isCurrent;
    final api = _ref.read(leaderboardApiServiceProvider);
    final provisioned = await api.provisionWallet(authority: identityLease);
    // The provision round-trip is the long pole: if the identity changed
    // while it was in flight, this response belongs to a user who is no
    // longer signed in. Mutating local state with it would hand their
    // wallet to the current session (or to nobody). Abort before ANY
    // mutation; the reconciling identity persists (marker) so the new
    // identity's own reconcile repairs state.
    if (!workIsCurrent()) {
      _log.warn('Discarding stale provision response (identity changed)');
      return false;
    }
    final ProvisionedAccountMaterial derived;
    try {
      derived = _deriveAccount(provisioned.secretKey);
    } catch (_) {
      throw const ProvisionedWalletIntegrityException(
        'secret key could not be decoded',
      );
    }
    if (derived.address != provisioned.address ||
        derived.publicKey != provisioned.publicKey) {
      throw const ProvisionedWalletIntegrityException(
        'derived account does not match the provision response',
      );
    }
    // NEVER log provisioned.secretKey — address only.
    _log.info('Wallet provisioned', context: {
      'address': provisioned.address,
      'newlyAllocated': provisioned.newlyAllocated,
      'seasonId': provisioned.seasonId,
    });

    final participantId = await _resolveParticipantId(identity);

    final repo = await AccountsRepository.create(
      network: identityLease.network,
    );
    final accounts = await repo.list();
    final existing =
        accounts.where((a) => a.address == provisioned.address).firstOrNull;

    // Re-validate before every shared-state mutation: each `await` above is
    // a suspension point where a newer identity can appear, and the final
    // epoch check inside reconcileSucceeded cannot undo registry writes.
    if (!workIsCurrent()) return false;

    var changed = false;
    String accountId;
    if (existing != null) {
      accountId = existing.id;
      if (repo.getActiveId() != existing.id) {
        await repo.setActiveId(existing.id);
        changed = true;
        _log.info('Activated existing local account for provisioned address');
      } else {
        _log.trace('Provisioned account already active - nothing to do');
      }
    } else {
      final imported = await repo.importFromSecretKey(
        name: 'Node Account',
        secretKey: provisioned.secretKey,
      );
      accountId = imported.id;
      changed = true;
      _log.info('Imported platform-allocated node account');
    }

    // Install the participant ID into the provisioned account's bucket
    // (explicitly addressed — does not depend on which bucket is active).
    // Writing before the commit is safe even for a run that later turns out
    // stale: the value lands in the provisioned USER'S OWN bucket, never in
    // another identity's.
    await installParticipantIdInBucket(
      participantId: participantId,
      bucket: NetworkPrefs.bucketForAddress(provisioned.address),
      network: identityLease.network,
    );

    // Bind the node runtime to the reconciled account BEFORE committing:
    // the identity must not become ready (unblocking wallet routes, signing
    // and node starts) while the runtime may still hold another account's
    // key. Throws on failure — the identity stays reconciling and the next
    // boot restore or sign-in retries.
    if (!workIsCurrent()) return false;
    final accountScope = AccountStorageScope(
      network: identityLease.network,
      bucket: NetworkPrefs.bucketForAddress(provisioned.address),
      accountId: accountId,
      address: provisioned.address,
    );
    final nodeAuthority = NodeStartAuthority.forReconciliation(
      identityLease: identityLease,
      accountScope: accountScope,
    );
    if (nodeAuthority == null || !nodeAuthority.isCurrent) return false;
    await _ensureNodeIdentity(nodeAuthority);
    if (!workIsCurrent()) return false;

    // Commit: SessionController re-validates the epoch inside its serialized
    // transition queue, so a commit racing a login/logout loses cleanly.
    final committed =
        await _ref.read(identityProvider.notifier).reconcileSucceeded(
              epoch: epoch,
              accountId: accountId,
              address: provisioned.address,
              participantId: participantId,
              provisionedSeasonId: provisioned.seasonId,
            );
    if (!committed) return false;

    if (changed) {
      // Let the router and account-gated UI see the new state immediately.
      // backendLifecycleProvider watches hasAnyAccountProvider and starts
      // the node when it flips false -> true (fresh-install import).
      _ref.invalidate(hasAnyAccountProvider);
      _ref.invalidate(accountsProvider);
      _ref.invalidate(activeAccountProvider);
    }
    // Onboarding completion is bucket-scoped. Reconcile always moves the
    // active bucket from guest to the confirmed account, even when that
    // account was already active in the registry (`changed == false`).
    _ref.invalidate(hasCompletedOnboardingProvider);
    _ref.invalidate(participantIdProvider);

    return true;
  }
}
