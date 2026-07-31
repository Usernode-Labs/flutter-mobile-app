import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

/// Base class for leaderboard data providers.
///
/// Subclasses implement [fetch] (the API call) and [watchDeps] (reactive
/// dependency registration). The base class handles the build/refresh
/// lifecycle so each provider is ~30 lines.
///
/// ### Pattern guide
///
/// **`watchDeps()`** — called in [build] to register `ref.watch()` bindings.
/// Return `false` when a required dependency is missing (e.g. no participantId)
/// and the provider should resolve to `null` instead of fetching.
///
/// **`fetch(owner)`** — the API call. Use `ref.read()` to access dependency
/// values (watches are already registered by `watchDeps`). The exact
/// authenticated [owner] that started the read must guard any side effects
/// performed after an `await`. If called from [silentRefresh] when deps are
/// unavailable, let it throw — the base class catches and preserves the
/// last-good value.
abstract class LeaderboardNotifier<T> extends AsyncNotifier<T?> {
  late final _log = LoggingService.instance.withTag('usernode/$runtimeType');

  /// Perform the API call. All dependencies are guaranteed ready when called
  /// from [build] (guarded by [watchDeps]). Use `ref.read()` here, not
  /// `ref.watch()`.
  Future<T> fetch(AuthenticatedUserLease owner);

  /// Register reactive dependencies via `ref.watch()` and return whether all
  /// are satisfied. Called only in [build].
  ///
  /// Always register ALL watches before returning (don't short-circuit) so
  /// Riverpod tracks every dependency:
  /// ```dart
  /// @override
  /// bool watchDeps() {
  ///   final pid = ref.watch(participantIdProvider).valueOrNull;
  ///   final ctx = ref.watch(seasonEventContextProvider);
  ///   return pid != null && ctx.seasonId != null;
  /// }
  /// ```
  bool watchDeps() => true;

  @override
  Future<T?> build() async {
    // Watch the whole immutable identity, not the coarse authenticated bool.
    // A ready A -> ready B replacement has the same auth status but represents
    // a different owner, so every personalized provider must rebuild.
    final owner = _captureReadyOwner(ref.watch(identityProvider));
    final dependenciesReady = watchDeps();
    if (owner == null || !dependenciesReady) return null;

    final result = await fetch(owner);
    return canPublish(owner) ? result : null;
  }

  /// Re-fetch live data without triggering a loading state transition.
  ///
  /// On success, updates [state] to the fresh value. On failure, preserves
  /// the last-good value (no `AsyncError` transition) so the UI stays stable.
  Future<void> silentRefresh() async {
    final owner = readReadyOwner();
    if (owner == null) return;

    try {
      final result = await fetch(owner);
      if (canPublish(owner)) state = AsyncData(result);
    } catch (e) {
      // A disposed/replaced identity owns neither the state nor its logs. A
      // current failure is still useful and intentionally preserves the last
      // good value.
      if (canPublish(owner)) {
        _log.warn('$runtimeType refresh failed: $e');
      }
    }
  }

  Future<void> refresh() async => silentRefresh();

  /// Captures the exact ready authenticated identity for an imperative read.
  ///
  /// Exposed to specialized controllers such as paginated leaderboards so all
  /// manual state publication uses the same ownership rule as [silentRefresh].
  AuthenticatedUserLease? readReadyOwner() =>
      _captureReadyOwner(ref.read(identityProvider));

  /// Whether [owner] still owns this provider's publication surface.
  ///
  /// [AuthenticatedUserLease.isCurrent] also verifies the selected network;
  /// the provider-visible comparison prevents an overridden/headless container
  /// from publishing a result for a different identity snapshot.
  bool canPublish(AuthenticatedUserLease owner) {
    if (!owner.isCurrent) return false;
    try {
      final current = ref.read(identityProvider);
      return current.phase == IdentityPhase.ready &&
          owner.identityLease.identity.sameScopeAs(current);
    } catch (_) {
      // The hard identity cutover disposes the old provider container. An
      // operation completing afterward has no publication surface.
      return false;
    }
  }

  AuthenticatedUserLease? _captureReadyOwner(Identity identity) {
    if (identity.phase != IdentityPhase.ready) return null;
    return AuthenticatedUserLease.capture(identity);
  }
}
