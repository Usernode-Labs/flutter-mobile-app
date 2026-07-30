import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/identity_lifecycle.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
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
/// Reconciliation runs on every sign-in (see `postSignInSyncProvider`) and
/// from onboarding, NOT just when no local account exists: the registry
/// persists across logout, so "some account exists locally" says nothing
/// about whether it belongs to the CURRENT session's user. Without the
/// ownership check, user B signing in on user A's device would run the node
/// (and every wallet-scoped backend call) against A's wallet.
class NodeAccountReconciler {
  NodeAccountReconciler(
    this._ref, {
    Future<void> Function({required bool startIfSuspended})? ensureNodeIdentity,
    int Function()? currentGeneration,
  })  : _ensureNodeIdentity = ensureNodeIdentity ?? _defaultEnsureNodeIdentity,
        _currentGeneration =
            currentGeneration ?? (() => IdentityGenerations.current);

  final Ref _ref;

  /// Brings the node runtime in line with the (just reconciled) active
  /// account. Injectable for tests (the default touches the Rust backend).
  final Future<void> Function({required bool startIfSuspended})
      _ensureNodeIdentity;

  /// Source of the identity generation (see [IdentityGenerations]);
  /// injectable for tests.
  final int Function() _currentGeneration;

  Future<bool>? _inFlight;
  int? _inFlightGeneration;

  /// Serializes an account switch with node startup and binds the runtime to
  /// the active account:
  ///
  /// - waits for any in-flight [RustBackendService.startNode] — a cold-boot
  ///   start may already have captured the OLD account's key while
  ///   `isRunning` is still false, so deciding before it settles would race;
  /// - a running node is stopped and started again (re-reads the active
  ///   account's key at start);
  /// - a node that is NOT running is only started when login suspended it
  ///   ([NodeIdentitySuspension]) — otherwise a deliberately stopped node
  ///   stays stopped;
  /// - `startNode() == false` is a failure: the caller must not report the
  ///   node identity as confirmed.
  static Future<void> _defaultEnsureNodeIdentity(
      {required bool startIfSuspended}) async {
    final svc = RustBackendService.instance;
    await svc.waitForStartCompletion();
    if (svc.isRunning) {
      await svc.stopNode();
    } else if (!startIfSuspended) {
      return;
    }
    final started = await svc.startNode();
    if (!started) {
      throw StateError('Node failed to start under the reconciled account');
    }
  }

  /// Runs a reconcile, coalescing concurrent calls FOR THE SAME identity
  /// generation onto one in-flight run (sign-in listener and onboarding tap
  /// can race; two parallel imports of the same account would duplicate
  /// registry entries).
  ///
  /// A caller from a NEWER generation (the user signed out / another user
  /// signed in while a run was in flight) never joins the stale run — its
  /// result would belong to the wrong session. It waits the stale run out,
  /// then starts a fresh one.
  ///
  /// Returns `true` when the local state changed (account imported or a
  /// different account activated). Throws ([LeaderboardApiException],
  /// [AccountImportException], network errors) on failure so the caller can
  /// surface it; onboarding must not proceed without an account or the
  /// router loops back to onboarding forever (`hasAny == false`).
  Future<bool> reconcile() {
    final gen = _currentGeneration();
    final inFlight = _inFlight;
    if (inFlight != null && _inFlightGeneration == gen) return inFlight;

    late Future<bool> run;
    run = _runAfter(inFlight, gen).whenComplete(() {
      if (identical(_inFlight, run)) {
        _inFlight = null;
        _inFlightGeneration = null;
      }
    });
    _inFlight = run;
    _inFlightGeneration = gen;
    return run;
  }

  Future<bool> _runAfter(Future<bool>? previous, int gen) async {
    if (previous != null) {
      try {
        await previous;
      } catch (_) {
        // The stale run's failure was surfaced to its own caller.
      }
    }
    if (_currentGeneration() != gen) {
      // Superseded while waiting; the newest session's caller runs its own.
      return false;
    }
    return _reconcile(gen);
  }

  Future<bool> _reconcile(int gen) async {
    final api = _ref.read(leaderboardApiServiceProvider);
    final provisioned = await api.provisionWallet();
    // The provision round-trip is the long pole: if the session changed
    // while it was in flight, this response belongs to a user who is no
    // longer signed in. Mutating local state with it would hand their
    // wallet to the current session (or to nobody). Abort before ANY
    // mutation; the pending marker stays set so the new session's own
    // reconcile repairs state.
    if (_currentGeneration() != gen) {
      _log.warn('Discarding stale provision response (session changed)');
      return false;
    }
    // NEVER log provisioned.secretKey — address only.
    _log.info('Wallet provisioned', context: {
      'address': provisioned.address,
      'newlyAllocated': provisioned.newlyAllocated,
    });

    final repo = await AccountsRepository.create();
    final accounts = await repo.list();
    final existing =
        accounts.where((a) => a.address == provisioned.address).firstOrNull;

    // Captured before any mutation: non-null means some account was already
    // active — if the reconcile changes it, a node is (or may start) running
    // under the OLD identity and must be bounced (the node binds the active
    // account's key at start; backendLifecycleProvider only reacts to
    // has-any-account flips, not switches).
    final previousActiveId = repo.getActiveId();

    var changed = false;
    if (existing != null) {
      if (repo.getActiveId() != existing.id) {
        await repo.setActiveId(existing.id);
        changed = true;
        _log.info('Activated existing local account for provisioned address');
      } else {
        _log.trace('Provisioned account already active - nothing to do');
      }
    } else {
      await repo.importFromSecretKey(
        name: 'Node Account',
        secretKey: provisioned.secretKey,
      );
      changed = true;
      _log.info('Imported platform-allocated node account');
    }

    // The provisioned account is now active — resolve its storage bucket,
    // then move a participant id a pre-account login left in the guest
    // bucket. The migration is idempotent and re-runs on every reconcile, so
    // an interruption between import and migration self-heals on the next
    // sign-in or onboarding attempt.
    await refreshActiveAccountBucket(guest: false);
    await migrateGuestParticipantId();

    // Bind the node runtime to the reconciled account when (a) login
    // suspended it because ownership was unknown, or (b) this run switched
    // the active account away from a previously active one. Failure keeps
    // the pending marker set (below): the registry/bucket are correct, but
    // "which key the runtime holds" is not yet confirmed.
    final suspended = NodeIdentitySuspension.isSuspended;
    var nodeIdentityConfirmed = true;
    if (suspended || (changed && previousActiveId != null)) {
      try {
        await _ensureNodeIdentity(startIfSuspended: suspended);
        NodeIdentitySuspension.clear();
      } catch (e, st) {
        nodeIdentityConfirmed = false;
        _log.error('Node restart after account reconcile failed',
            error: e, stackTrace: st);
        await SentryUtil.captureError(e, st, tag: 'reconcile_node_restart');
      }
    }

    if (changed) {
      // Let the router and account-gated UI see the new state immediately.
      // backendLifecycleProvider watches hasAnyAccountProvider and starts
      // the node when it flips false -> true (fresh-install import).
      _ref.invalidate(hasAnyAccountProvider);
      _ref.invalidate(accountsProvider);
      _ref.invalidate(activeAccountProvider);
      // Onboarding completion is bucket-scoped; after a switch the new
      // identity's flag must drive routing now, not on the next cold start.
      _ref.invalidate(hasCompletedOnboardingProvider);
    }
    _ref.invalidate(participantIdProvider);
    // Rebuild providers that cache bucket-scoped reads (recipient history
    // etc.) — they can't see a mid-session bucket switch otherwise.
    _ref.read(identityRevisionProvider.notifier).state++;

    // Clear the boot-recovery marker only when this run still belongs to the
    // current session AND the node runtime is confirmed under the reconciled
    // account. Otherwise leave it set: the next sign-in or boot restore
    // re-runs the reconcile and repairs whatever this run couldn't confirm.
    if (_currentGeneration() == gen && nodeIdentityConfirmed) {
      await clearAccountReconcilePending();
    }

    return changed;
  }
}
