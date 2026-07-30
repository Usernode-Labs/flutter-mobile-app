import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
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
  NodeAccountReconciler(this._ref, {Future<void> Function()? restartNode})
      : _restartNode = restartNode ?? _defaultRestartNode;

  final Ref _ref;

  /// Restarts a running node so it re-reads the active account's key.
  /// Injectable for tests (the default touches the Rust backend).
  final Future<void> Function() _restartNode;
  Future<bool>? _inFlight;

  static Future<void> _defaultRestartNode() async {
    if (!RustBackendService.instance.isRunning) return;
    await RustBackendService.instance.stopNode();
    await RustBackendService.instance.startNode();
  }

  /// Runs a reconcile, coalescing concurrent calls onto one in-flight run
  /// (sign-in listener and onboarding tap can race; two parallel imports of
  /// the same account would duplicate registry entries).
  ///
  /// Returns `true` when the local state changed (account imported or a
  /// different account activated). Throws ([LeaderboardApiException],
  /// [AccountImportException], network errors) on failure so the caller can
  /// surface it; onboarding must not proceed without an account or the
  /// router loops back to onboarding forever (`hasAny == false`).
  Future<bool> reconcile() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final run = _reconcile().whenComplete(() => _inFlight = null);
    _inFlight = run;
    return run;
  }

  Future<bool> _reconcile() async {
    final api = _ref.read(leaderboardApiServiceProvider);
    final provisioned = await api.provisionWallet();
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
    // active — if the reconcile changes it, a running node is signing under
    // the OLD identity and must be restarted (the node binds the active
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

    if (changed) {
      if (previousActiveId != null) {
        // Active account switched away from a previously active one: restart
        // a running node so it picks up the new identity. Failure is logged,
        // not rethrown — the registry/bucket state is already correct and
        // the next node start self-heals.
        try {
          await _restartNode();
        } catch (e, st) {
          _log.error('Node restart after account switch failed',
              error: e, stackTrace: st);
          await SentryUtil.captureError(e, st, tag: 'reconcile_node_restart');
        }
      }
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

    // The session's identity is now reconciled — boot restores no longer
    // need to re-run this (set by completeLogin).
    await clearAccountReconcilePending();

    return changed;
  }
}
