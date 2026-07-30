import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/features/onboarding/data/node_account_provisioning.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';

final _log = LoggingService.instance.withTag('usernode/PostSignInSync');

/// True when the auth state change is a genuine sign-in: a settled signed-out
/// state ([AuthStatus.unauthenticated] or [AuthStatus.guest]) transitioning to
/// [AuthStatus.authenticated].
///
/// Boot restore (`unknown -> authenticated`, a stored token found at startup)
/// is intentionally excluded: cold-start recovery paths already run then, and
/// reconciling on every launch would add a network round-trip to each boot.
/// The exception is an interrupted reconcile — see [isBootRestore] and the
/// reconcile-pending marker handling in [PostSignInSync.onAuthStatusChanged].
bool isSignInTransition(AuthStatus? previous, AuthStatus next) {
  if (next != AuthStatus.authenticated) return false;
  return previous == AuthStatus.unauthenticated || previous == AuthStatus.guest;
}

/// True when the auth state change is a boot restore: a stored session token
/// found at startup ([AuthStatus.unknown] or no previous state transitioning
/// to [AuthStatus.authenticated]).
bool isBootRestore(AuthStatus? previous, AuthStatus next) {
  if (next != AuthStatus.authenticated) return false;
  return previous == null || previous == AuthStatus.unknown;
}

/// Runs session-dependent repair work whenever a sign-in completes:
///
/// 1. Reconciles the local node account against the authenticated user's
///    platform allocation ([NodeAccountReconciler]) — the local registry
///    persists across logout, so a different user signing in on the same
///    device must not inherit the previous user's wallet.
/// 2. Retries any pending zkPassport backend completion — a proof preserved
///    across a 401 would otherwise wait for the next cold start while the
///    optimistic local registration renders as complete.
///
/// Failures are logged and reported, never rethrown: this is opportunistic
/// repair, and each unit also has its own recovery path (onboarding retry,
/// cold-start retry).
class PostSignInSync {
  PostSignInSync({
    required Future<void> Function() reconcileNodeAccount,
    required Future<void> Function() retryPendingZkCompletion,
    Future<bool> Function() isReconcilePending = isAccountReconcilePending,
  })  : _reconcileNodeAccount = reconcileNodeAccount,
        _retryPendingZkCompletion = retryPendingZkCompletion,
        _isReconcilePending = isReconcilePending;

  final Future<void> Function() _reconcileNodeAccount;
  final Future<void> Function() _retryPendingZkCompletion;
  final Future<bool> Function() _isReconcilePending;

  /// The run started by the most recent sign-in transition, for tests and
  /// callers that need to observe completion. Null until the first sign-in.
  Future<void>? lastRun;

  void onAuthStatusChanged(AuthStatus? previous, AuthStatus next) {
    if (isSignInTransition(previous, next)) {
      _log.info('Sign-in detected - running post-sign-in sync');
      lastRun = _run();
      unawaited(lastRun);
      return;
    }
    if (isBootRestore(previous, next)) {
      // A login whose reconcile never completed (app killed, network drop)
      // leaves a pending marker; without this the device would stay under
      // the previous identity across restarts because no further sign-in
      // transition ever happens.
      lastRun = _runIfReconcilePending();
      unawaited(lastRun);
    }
  }

  Future<void> _runIfReconcilePending() async {
    bool pending;
    try {
      pending = await _isReconcilePending();
    } catch (e) {
      _log.warn('Reconcile-pending check failed: $e');
      return;
    }
    if (!pending) return;
    _log.info('Boot restore with unfinished reconcile - running sync');
    await _run();
  }

  Future<void> _run() async {
    // Reconcile first: the ZK retry reads account-bucket-scoped state
    // (pending record, participant id), which the reconcile settles.
    try {
      await _reconcileNodeAccount();
    } catch (e, st) {
      _log.warn('Post-sign-in account reconcile failed: $e');
      await SentryUtil.captureError(e, st, tag: 'post_sign_in_reconcile');
    }
    try {
      await _retryPendingZkCompletion();
    } catch (e, st) {
      _log.warn('Post-sign-in zk completion retry failed: $e');
      await SentryUtil.captureError(e, st, tag: 'post_sign_in_zk_retry');
    }
  }
}

/// Always-alive listener wiring [PostSignInSync] to [authStatusProvider].
/// Read once from the app root (like `backendLifecycleProvider`) so the
/// listener exists for the whole app lifetime.
final postSignInSyncProvider = Provider<PostSignInSync>((ref) {
  final sync = PostSignInSync(
    reconcileNodeAccount: () =>
        ref.read(nodeAccountReconcilerProvider).reconcile(),
    retryPendingZkCompletion: () =>
        ref.read(zkPassportPipelineProvider.notifier).retryPendingCompletion(),
  );
  ref.listen<AuthStatus>(
    authStatusProvider,
    sync.onAuthStatusChanged,
  );
  return sync;
});

/// True when a season-context change is a genuine rollover: both sides carry
/// a season id and they differ. `null -> id` transitions (fresh install,
/// first discovery after a cache clear) are NOT rollovers — the sign-in /
/// onboarding reconcile covers those, and treating them as rollovers would
/// reconcile on every fresh boot.
bool isSeasonRollover(int? previousSeasonId, int? nextSeasonId) {
  return previousSeasonId != null &&
      nextSeasonId != null &&
      previousSeasonId != nextSeasonId;
}

/// Always-alive listener that re-runs the account reconcile when the active
/// season changes mid-session. `/wallet/provision` allocates per season: a
/// user who stays signed in across a rollover would otherwise keep the
/// previous season's wallet (and be stuck on stale-registration) until they
/// logged out and back in — no sign-in transition ever fires for them.
///
/// The persisted season context is bucket-scoped and restored at boot, so a
/// rollover that happened while the app was closed still surfaces here as
/// `restored old id -> freshly fetched new id`.
final seasonRolloverSyncProvider = Provider<void>((ref) {
  ref.listen<SeasonEventContext>(seasonEventContextProvider, (previous, next) {
    if (!isSeasonRollover(previous?.seasonId, next.seasonId)) return;
    if (ref.read(authStatusProvider) != AuthStatus.authenticated) return;
    _log.info('Active season changed '
        '(${previous?.seasonId} -> ${next.seasonId}) - reconciling account');
    unawaited(() async {
      try {
        // Marked so an interrupted rollover reconcile is retried on the next
        // boot restore, exactly like an interrupted sign-in reconcile.
        await markAccountReconcilePending();
        await ref.read(nodeAccountReconcilerProvider).reconcile();
      } catch (e, st) {
        _log.warn('Season-rollover reconcile failed: $e');
        await SentryUtil.captureError(e, st, tag: 'season_rollover_reconcile');
      }
    }());
  });
});
