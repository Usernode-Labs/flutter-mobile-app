import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
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
/// **`fetch()`** — the API call. Use `ref.read()` to access dependency values
/// (watches are already registered by `watchDeps`). If called from
/// [silentRefresh] when deps are unavailable, let it throw — the base class
/// catches and preserves the last-good value.
abstract class LeaderboardNotifier<T> extends AsyncNotifier<T?> {
  late final _log = LoggingService.instance.withTag('usernode/$runtimeType');

  /// Perform the API call. All dependencies are guaranteed ready when called
  /// from [build] (guarded by [watchDeps]). Use `ref.read()` here, not
  /// `ref.watch()`.
  Future<T> fetch();

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
  Future<T?> build() async => watchDeps() ? await fetch() : null;

  /// Re-fetch live data without triggering a loading state transition.
  ///
  /// On success, updates [state] to the fresh value. On failure, preserves
  /// the last-good value (no `AsyncError` transition) so the UI stays stable.
  ///
  /// Leaderboard data is account/bucket scoped, and this runs outside the
  /// `build` that registered the identity watches — a slow response for the
  /// previous identity would otherwise be published after a sign-out or a
  /// user switch. The captured snapshot is therefore re-checked after the
  /// await, and a superseded result is dropped rather than published.
  Future<void> silentRefresh() async {
    final identity = IdentitySnapshots.current;
    try {
      final value = await fetch();
      if (!identity.sameScopeAs(IdentitySnapshots.current)) {
        _log.debug('$runtimeType refresh superseded by an identity change');
        return;
      }
      state = AsyncData(value);
    } catch (e) {
      _log.warn('$runtimeType refresh failed: $e');
    }
  }

  Future<void> refresh() async => silentRefresh();
}
