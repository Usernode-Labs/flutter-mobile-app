import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

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
  NodeAccountReconciler(this._ref);

  final Ref _ref;
  Future<bool>? _inFlight;

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
      // Let the router and account-gated UI see the new state immediately.
      // backendLifecycleProvider watches hasAnyAccountProvider and starts
      // the node when it flips false -> true.
      _ref.invalidate(hasAnyAccountProvider);
      _ref.invalidate(accountsProvider);
      _ref.invalidate(activeAccountProvider);
    }
    _ref.invalidate(participantIdProvider);

    return changed;
  }
}
