import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Monotonic counter identifying the current identity "generation". Bumped on
/// every session transition (login, logout, continue-as-guest, 401 token
/// invalidation).
///
/// Async identity work — account reconciliation, ZK pending-completion
/// retries, deferred 401 handling — captures `current` when it starts and
/// re-checks it before mutating state or joining an in-flight run. A stale
/// generation means the session the work was started for no longer exists:
/// the work must abort (leaving persisted markers in place so the new
/// session's own run repairs state) rather than apply another user's result.
///
/// See docs/identity-lifecycle-invariants.md (I10).
class IdentityGenerations {
  IdentityGenerations._();

  static int _current = 0;

  static int get current => _current;

  static int bump() => ++_current;

  @visibleForTesting
  static void reset() => _current = 0;
}

/// Flag set at login when the running node was suspended because the active
/// local account's ownership is unknown (it may belong to a previously
/// signed-in user). Consumed by `NodeAccountReconciler`, which restarts the
/// node under the reconciled account and clears the flag.
class NodeIdentitySuspension {
  NodeIdentitySuspension._();

  static bool _suspended = false;

  static bool get isSuspended => _suspended;

  static void markSuspended() => _suspended = true;

  static void clear() => _suspended = false;
}

/// Bumped whenever the active storage bucket changes OUTSIDE an auth-status
/// transition (i.e. mid-session, by `NodeAccountReconciler`). Providers that
/// read bucket-scoped storage during `build()` must watch this alongside
/// `authStatusProvider` so a reconciled account switch rebuilds them —
/// otherwise user B is served values cached from user A's bucket.
final identityRevisionProvider = StateProvider<int>((ref) => 0);
