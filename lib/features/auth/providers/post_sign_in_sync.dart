import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/features/onboarding/data/node_account_provisioning.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';

final _log = LoggingService.instance.withTag('usernode/IdentityDriver');

/// Drives the work each identity phase demands. The [SessionController] owns
/// WHAT the identity is; this driver owns making the app converge on it:
///
/// - [IdentityPhase.reconciling] → run the [NodeAccountReconciler]. Covers
///   fresh sign-ins, boot restores of an interrupted reconcile, and season
///   rollovers — every path that publishes a reconciling identity.
/// - transition into [IdentityPhase.ready] → retry any pending zkPassport
///   backend completion (the identity-keyed outbox row). Runs only once the
///   identity is settled so a proof is never submitted under an unsettled
///   bucket/token pairing.
///
/// Node lifecycle is platform-controlled (thin-shell migration): SV chrome
/// requests start/stop over bridge v4 once the identity settles. The driver
/// no longer starts the node itself — neither for guests (the guest keyless
/// start is gone) nor after reconcile.
///
/// Failures are logged and reported, never rethrown: this is opportunistic
/// repair, and each unit has its own recovery path (the persisted
/// reconciling phase re-runs on next boot, cold-start ZK retry).
class IdentityDriver {
  IdentityDriver({
    required Future<void> Function() reconcileNodeAccount,
    required Future<void> Function() retryPendingZkCompletion,
  })  : _reconcileNodeAccount = reconcileNodeAccount,
        _retryPendingZkCompletion = retryPendingZkCompletion;

  final Future<void> Function() _reconcileNodeAccount;
  final Future<void> Function() _retryPendingZkCompletion;

  /// The run started by the most recent identity change, for tests and
  /// callers that need to observe completion. Null until the first trigger.
  Future<void>? lastRun;

  void onIdentityChanged(Identity? previous, Identity next) {
    if (next.phase == IdentityPhase.reconciling) {
      // The reconciler coalesces per epoch, so redundant triggers are cheap.
      _log.info('Identity reconciling (epoch ${next.epoch}) - '
          'running account reconcile');
      lastRun = _runReconcile();
      unawaited(lastRun);
      return;
    }
    final becameReady = next.phase == IdentityPhase.ready &&
        previous?.phase != IdentityPhase.ready;
    if (becameReady) {
      lastRun = _runZkRetry();
      unawaited(lastRun);
    }
  }

  Future<void> _runReconcile() async {
    try {
      await _reconcileNodeAccount();
    } catch (e, st) {
      _log.warn('Account reconcile failed: $e');
      await SentryUtil.captureError(e, st, tag: 'identity_reconcile');
    }
  }

  Future<void> _runZkRetry() async {
    try {
      await _retryPendingZkCompletion();
    } catch (e, st) {
      _log.warn('Pending zk completion retry failed: $e');
      await SentryUtil.captureError(e, st, tag: 'identity_zk_retry');
    }
  }
}

/// Always-alive listener wiring [IdentityDriver] to [identityProvider].
/// Read once from the app root (like `backendLifecycleProvider`) so the
/// listener exists for the whole app lifetime.
final identityDriverProvider = Provider<IdentityDriver>((ref) {
  final driver = IdentityDriver(
    reconcileNodeAccount: () =>
        ref.read(nodeAccountReconcilerProvider).reconcile(),
    retryPendingZkCompletion: () =>
        ref.read(zkPassportPipelineProvider.notifier).retryPendingCompletion(),
  );
  ref.listen<Identity>(
    identityProvider,
    driver.onIdentityChanged,
    fireImmediately: true,
  );
  return driver;
});

/// The backend's ACTIVE season id from the authoritative `/seasons` response
/// — NOT the user-selected reporting season (`seasonEventContextProvider`,
/// which the season picker mutates and bootstrap restores from cache).
/// Null while unknown (loading, unauthenticated, or no active season).
int? activeSeasonIdOf(List<SeasonDto>? seasons) {
  if (seasons == null) return null;
  for (final season in seasons) {
    if (season.isActive) return season.id;
  }
  return null;
}

/// Always-alive listener that hands the authoritative active season to the
/// [SessionController]. `/wallet/provision` allocates per season: a user who
/// stays signed in across a rollover would otherwise keep the previous
/// season's wallet (and be stuck on stale-registration) until they logged
/// out and back in — no sign-in transition ever fires for them.
///
/// The controller compares the reported season against the identity's
/// provisioned season (persisted at reconcile commit) and re-enters the
/// reconciling phase only on a genuine mismatch, so this can safely fire on
/// every `/seasons` refresh.
final seasonRolloverSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<SeasonDto>?>>(seasonsProvider, (previous, next) {
    final activeSeasonId = activeSeasonIdOf(next.valueOrNull);
    if (activeSeasonId == null) return;
    unawaited(
      ref
          .read(identityProvider.notifier)
          .beginSeasonRollover(activeSeasonId: activeSeasonId),
    );
  });
});
