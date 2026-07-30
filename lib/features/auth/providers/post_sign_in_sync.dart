import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
bool isSignInTransition(AuthStatus? previous, AuthStatus next) {
  if (next != AuthStatus.authenticated) return false;
  return previous == AuthStatus.unauthenticated || previous == AuthStatus.guest;
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
  })  : _reconcileNodeAccount = reconcileNodeAccount,
        _retryPendingZkCompletion = retryPendingZkCompletion;

  final Future<void> Function() _reconcileNodeAccount;
  final Future<void> Function() _retryPendingZkCompletion;

  /// The run started by the most recent sign-in transition, for tests and
  /// callers that need to observe completion. Null until the first sign-in.
  Future<void>? lastRun;

  void onAuthStatusChanged(AuthStatus? previous, AuthStatus next) {
    if (!isSignInTransition(previous, next)) return;
    _log.info('Sign-in detected - running post-sign-in sync');
    lastRun = _run();
    unawaited(lastRun);
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
