import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/identity/block_production_store.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';

final _log =
    LoggingService.instance.withTag('usernode/NodeAccountProvisioning');

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
/// queue. A same-user season rollover can supersede an older run; terminal
/// reset closes the gate and discards the entire process instead of handing
/// that work to another identity.
class NodeAccountReconciler {
  NodeAccountReconciler(
    this._ref, {
    Future<void> Function()? ensureNodeIdentity,
    Identity Function()? currentIdentity,
    Future<AccountsRepository> Function()? accountsRepository,
    Identity Function(Identity)? accountAuthorityIdentity,
  })  : _ensureNodeIdentity = ensureNodeIdentity ?? _defaultEnsureNodeIdentity,
        _currentIdentity = currentIdentity ?? (() => IdentitySnapshots.current),
        _accountsRepository =
            accountsRepository ?? AccountsRepository.createForMigration,
        _accountAuthorityIdentity =
            accountAuthorityIdentity ?? ((value) => value);

  final Ref _ref;

  /// Brings the node runtime in line with the (just reconciled) active
  /// account. Injectable for tests (the default touches the Rust backend).
  final Future<void> Function() _ensureNodeIdentity;

  /// Source of the current identity snapshot; injectable for tests.
  final Identity Function() _currentIdentity;
  final Future<AccountsRepository> Function() _accountsRepository;
  final Identity Function(Identity) _accountAuthorityIdentity;

  Future<bool>? _inFlight;
  int? _inFlightEpoch;
  Future<bool>? _refreshInFlight;
  int? _refreshInFlightEpoch;

  /// Refreshes backend-authoritative facts for an already-ready identity.
  ///
  /// `/me` owns block-production release and `/seasons` owns the active
  /// season. Both responses are captured under one exact identity snapshot;
  /// a replacement epoch discards them before they can affect the current
  /// session. Concurrent lifecycle/connectivity/timer triggers coalesce.
  Future<bool> refreshAuthoritativeState() {
    final identity = _currentIdentity();
    if (identity.phase != IdentityPhase.ready || identity.address == null) {
      return Future.value(false);
    }
    final inFlight = _refreshInFlight;
    if (inFlight != null && _refreshInFlightEpoch == identity.epoch) {
      return inFlight;
    }

    late Future<bool> run;
    run = _refreshAfter(inFlight, identity).whenComplete(() {
      if (identical(_refreshInFlight, run)) {
        _refreshInFlight = null;
        _refreshInFlightEpoch = null;
      }
    });
    _refreshInFlight = run;
    _refreshInFlightEpoch = identity.epoch;
    return run;
  }

  Future<bool> _refreshAfter(
    Future<bool>? previous,
    Identity identity,
  ) async {
    if (previous != null) {
      try {
        await previous;
      } catch (_) {
        // The previous identity's caller observes its own failure.
      }
    }
    if (!_stillReady(identity)) return false;
    return _refresh(identity);
  }

  bool _stillReady(Identity expected) {
    final current = _currentIdentity();
    return current.phase == IdentityPhase.ready &&
        current.sameScopeAs(expected);
  }

  Future<bool> _refresh(Identity expected) async {
    // Refresh the providers themselves so profile and season consumers see
    // the same authoritative values used by reconciliation.
    // Keep these sequential so provider failures retain their concrete error
    // type; record `.wait` wraps them in ParallelWaitError and would hide a
    // transient network/API failure from the driver's retry classifier.
    final me = await _ref.refresh(meProvider.future);
    if (me == null || !_stillReady(expected)) return false;
    final seasons = await _ref.refresh(seasonsProvider.future);
    if (seasons == null || !_stillReady(expected)) return false;

    // This is the sole ready-state writer of release authority. Address the
    // captured bucket explicitly; never derive it from ambient active state.
    await installBlockProductionReleasedInBucket(
      released: me.bpReleased,
      bucket: NetworkPrefs.bucketForAddress(expected.address!),
    );
    if (!_stillReady(expected)) return false;

    final activeSeasonId = seasons
        .where((season) => season.isActive)
        .map((season) => season.id)
        .firstOrNull;
    if (activeSeasonId != null) {
      await _ref.read(identityProvider.notifier).beginSeasonRollover(
            activeSeasonId: activeSeasonId,
            expectedIdentity: expected,
          );
    }
    return _stillReady(expected);
  }

  /// Serializes an account switch with the node runtime WITHOUT starting it
  /// (node lifecycle is platform-controlled — SV chrome requests the start
  /// over bridge v4 once the identity is ready):
  ///
  /// - waits for any in-flight [RustBackendService.startNode] — a wake/alarm
  ///   start may already have captured the OLD account's key while
  ///   `isRunning` is still false, so deciding before it settles would race;
  /// - a running node is stopped so the runtime never outlives the account
  ///   whose producer key and wallet signer it captured at build time (there
  ///   is no swap API). The platform-requested start after `ready` builds a
  ///   fresh runtime under the reconciled account's key.
  static Future<void> _defaultEnsureNodeIdentity() async {
    final svc = RustBackendService.instance;
    await svc.waitForStartCompletion();
    if (svc.isRunning) {
      await svc.stopNode();
    }
  }

  /// Runs a reconcile, coalescing concurrent calls FOR THE SAME identity
  /// epoch onto one in-flight run (the identity driver and onboarding tap
  /// can race; two parallel imports of the same account would duplicate
  /// registry entries).
  ///
  /// A caller under a newer same-user season epoch never joins the stale run.
  /// It waits the stale run out, then starts a fresh one. Account changes are
  /// terminal application resets and do not reach this path in-process.
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
    final api = _ref.read(leaderboardApiServiceProvider);
    final provisioned = await api.provisionWallet();
    // The provision round-trip is the long pole: if the identity changed
    // while it was in flight, this response belongs to a user who is no
    // longer signed in. Mutating local state with it would hand their
    // wallet to the current session (or to nobody). Abort before ANY
    // mutation; the reconciling identity persists (marker) so the new
    // identity's own reconcile repairs state.
    if (!_stillCurrent(epoch)) {
      _log.warn('Discarding stale provision response (identity changed)');
      return false;
    }
    // NEVER log provisioned.secretKey — address only.
    _log.info('Wallet provisioned', context: {
      'address': provisioned.address,
      'newlyAllocated': provisioned.newlyAllocated,
      'seasonId': provisioned.seasonId,
    });

    // A Ready identity retains its exact account while the active season is
    // refreshed. The backend may allocate a different per-season account,
    // but that is an account-authority replacement and therefore cannot be
    // imported into the current session. Retire first; a normal sign-in will
    // create the fresh session allowed to activate the new binding.
    final retainedAddress = identity.address;
    if (retainedAddress != null) {
      if (provisioned.address != retainedAddress) {
        _log.info('Season rollover returned a different account; '
            'retiring the current session before activation');
        await _ref.read(identityProvider.notifier).logout(
              expectedIdentity: identity,
            );
        return false;
      }
      final retainedAccountId = identity.accountId;
      final retainedParticipantId = identity.participantId;
      if (retainedAccountId == null || retainedParticipantId == null) {
        throw StateError('Ready season rollover lacks its retained authority');
      }
      return _ref.read(identityProvider.notifier).reconcileSucceeded(
            epoch: epoch,
            accountId: retainedAccountId,
            address: retainedAddress,
            participantId: retainedParticipantId,
            provisionedSeasonId: provisioned.seasonId,
          );
    }

    final participantId = await _resolveParticipantId(identity);

    // Re-validate before every shared-state mutation: each `await` above is
    // a suspension point where a newer identity can appear, and the final
    // epoch check inside reconcileSucceeded cannot undo registry writes.
    if (!_stillCurrent(epoch)) return false;

    final repo = await _accountsRepository();
    final reconciliation = await repo.reconcileProvisionedAccount(
      identity: _accountAuthorityIdentity(identity),
      address: provisioned.address,
      secretKey: provisioned.secretKey,
      name: 'Node Account',
    );
    final changed = reconciliation.changed;
    final accountId = reconciliation.account.id;

    // Install the participant ID into the provisioned account's bucket
    // (explicitly addressed — does not depend on which bucket is active).
    // Writing before the commit is safe even for a run that later turns out
    // stale: the value lands in the provisioned USER'S OWN bucket, never in
    // another identity's.
    await installParticipantIdInBucket(
      participantId: participantId,
      bucket: NetworkPrefs.bucketForAddress(provisioned.address),
    );

    // Persist the block-production release decision alongside the account.
    // NodeService reads it at start time to decide whether the runtime gets
    // a producer key; a node must never produce for an unreleased user.
    await installBlockProductionReleasedInBucket(
      released: provisioned.bpReleased,
      bucket: NetworkPrefs.bucketForAddress(provisioned.address),
    );

    // Tear down any runtime still bound to a previous account BEFORE
    // committing: the identity must not become ready (unblocking wallet
    // routes, signing and node starts) while the runtime may still hold
    // another account's key. The node is NOT restarted here — the platform
    // requests the start once it observes the ready identity. Throws on
    // failure — the identity stays reconciling and the next boot restore or
    // sign-in retries.
    if (!_stillCurrent(epoch)) return false;
    await _ensureNodeIdentity();
    if (!_stillCurrent(epoch)) return false;

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
      // Let account-gated UI see the new state immediately.
      _ref.invalidate(hasAnyAccountProvider);
      _ref.invalidate(accountsProvider);
    }
    _ref.invalidate(participantIdProvider);

    return true;
  }
}
