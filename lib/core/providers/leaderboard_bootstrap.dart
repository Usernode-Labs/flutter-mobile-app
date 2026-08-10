import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

final _log = LoggingService.instance.withTag('usernode/LeaderboardBootstrap');

const _seasonIdKey = 'leaderboard:season_id';
const _seasonNameKey = 'leaderboard:season_name';
const _eventIdKey = 'leaderboard:event_id';
const _eventNameKey = 'leaderboard:event_name';

/// Bootstraps leaderboard state from persisted data: watch
/// [leaderboardBootstrapProvider] in the app shell to auto-restore the
/// [SeasonEventContext] from SharedPreferences on cold start.
class LeaderboardBootstrap {
  /// Load persisted season context for cold-start hydration.
  /// Returns null if no leaderboard data has been persisted.
  static Future<SeasonEventContext?> loadPersistedContext(
      {String? bucket}) async {
    final seasonIdKey = _accountKey(_seasonIdKey, bucket: bucket);
    final seasonNameKey = _accountKey(_seasonNameKey, bucket: bucket);
    final eventIdKey = _accountKey(_eventIdKey, bucket: bucket);
    final eventNameKey = _accountKey(_eventNameKey, bucket: bucket);
    final prefs = await SharedPreferences.getInstance();
    final seasonId = prefs.getInt(seasonIdKey);
    if (seasonId == null) return null;
    final seasonName = prefs.getString(seasonNameKey);
    final eventId = prefs.getInt(eventIdKey);
    final eventName = prefs.getString(eventNameKey);
    return SeasonEventContext(
      seasonId: seasonId,
      seasonName: seasonName,
      eventId: eventId,
      eventName: eventName,
    );
  }

  /// Persist a season/event selection (e.g. when the user picks an event
  /// or "All Events" via the event picker).
  static Future<void> persistSeasonEvent(
    SeasonEventContext ctx, {
    String? bucket,
  }) async {
    if (ctx.seasonId == null && ctx.eventId == null) return;
    await _persistContext(ctx, bucket: bucket);
  }

  // -- private ---------------------------------------------------------------

  static String _accountKey(String key, {String? bucket}) => bucket == null
      ? NetworkPrefs.prefixAccountKey(key)
      : NetworkPrefs.prefixAccountKeyFor(key, bucket);

  static Future<void> _persistContext(
    SeasonEventContext ctx, {
    String? bucket,
  }) async {
    final seasonIdKey = _accountKey(_seasonIdKey, bucket: bucket);
    final seasonNameKey = _accountKey(_seasonNameKey, bucket: bucket);
    final eventIdKey = _accountKey(_eventIdKey, bucket: bucket);
    final eventNameKey = _accountKey(_eventNameKey, bucket: bucket);
    final prefs = await SharedPreferences.getInstance();
    if (ctx.seasonId != null) {
      await prefs.setInt(seasonIdKey, ctx.seasonId!);
    }
    if (ctx.seasonName != null) {
      await prefs.setString(seasonNameKey, ctx.seasonName!);
    }
    if (ctx.eventId != null) {
      await prefs.setInt(eventIdKey, ctx.eventId!);
    } else {
      await prefs.remove(eventIdKey);
    }
    if (ctx.eventName != null) {
      await prefs.setString(eventNameKey, ctx.eventName!);
    } else {
      await prefs.remove(eventNameKey);
    }
  }
}

/// Refresh all active leaderboard providers silently.
/// Called from zkpassport flow completion and other non-screen contexts.
/// Screen pull-to-refresh calls individual provider refreshes directly.
/// Throttled to at most once every 5 seconds.
DateTime? _lastRefreshAt;

Future<void> refreshAllLeaderboardData(Ref ref) async {
  final now = DateTime.now();
  if (_lastRefreshAt != null &&
      now.difference(_lastRefreshAt!) < const Duration(seconds: 5)) {
    return;
  }

  // Don't consume the throttle window if deps aren't ready — the
  // silentRefresh calls would all fail and swallow the errors, leaving
  // the UI stale with no retry until the window expires.
  final pid = ref.read(participantIdProvider).valueOrNull;
  final ctx = ref.read(seasonEventContextProvider);
  if (pid == null || ctx.seasonId == null) return;

  _lastRefreshAt = now;

  await Future.wait([
    ref.read(challengesProvider.notifier).silentRefresh(),
    ref.read(breakdownProvider.notifier).silentRefresh(),
    ref.read(seasonsProvider.notifier).silentRefresh(),
  ]);
}

/// Auto-restores [seasonEventContextProvider] from persisted data on cold start.
///
/// Watch this in the app shell or splash screen to trigger restoration:
/// ```dart
/// ref.watch(leaderboardBootstrapProvider);
/// ```
///
/// Downstream providers ([challengesProvider], [breakdownProvider], etc.)
/// watch [seasonEventContextProvider] and rebuild automatically once the
/// context is populated.
final leaderboardBootstrapProvider = FutureProvider<void>((ref) async {
  // AuthStatus maps both reconciling and ready to authenticated. Leaderboard
  // state is account/bucket scoped, so capture the exact identity instead and
  // wait until reconciliation has proved ownership before reading or fetching.
  final identity = ref.watch(identityProvider);
  if (identity.phase != IdentityPhase.ready) return;

  var runIsActive = true;
  ref.onDispose(() => runIsActive = false);
  bool identityStillCurrent() =>
      runIsActive && identity.sameScopeAs(ref.read(identityProvider));

  final persisted = await LeaderboardBootstrap.loadPersistedContext(
    bucket: identity.bucket,
  );
  if (!identityStillCurrent()) return;

  // Fast path: restore persisted context immediately so downstream
  // providers get data without waiting for the API. A null eventId
  // is valid (= "All Events" selection).
  if (persisted != null && persisted.seasonId != null) {
    _log.info(
      'Restored context: seasonId=${persisted.seasonId}, '
      'eventId=${persisted.eventId ?? "All Events"}',
    );
    ref.read(seasonEventContextProvider.notifier).state = persisted;
    // Fall through to validate freshness and verify the persisted
    // event still exists in the season.
  } else {
    _log.info('No persisted context, auto-selecting from seasons API…');
  }

  // Single API call to resolve seasons + validate freshness.
  List<SeasonDto> seasons;
  try {
    final service = ref.read(leaderboardApiServiceProvider);
    seasons = await service.getSeasons();
  } catch (e) {
    if (!identityStillCurrent()) return;
    _log.warn('Failed to fetch seasons for auto-select: $e');
    // If we have partial persisted data, use it rather than nothing.
    if (persisted != null) {
      ref.read(seasonEventContextProvider.notifier).state = persisted;
    }
    return;
  }
  if (!identityStillCurrent()) return;

  if (seasons.isEmpty) {
    _log.info('No seasons available — skipping auto-select');
    if (persisted != null) {
      ref.read(seasonEventContextProvider.notifier).state = persisted;
    }
    return;
  }

  // Resolve season: prefer persisted seasonId, then active, then last.
  // FIXME(follow-up): The seasons API is newest-first; both no-match fallbacks
  // must use seasons.first rather than the oldest seasons.last.
  final season = persisted?.seasonId != null
      ? (seasons.cast<SeasonDto?>().firstWhere(
                (s) => s!.id == persisted!.seasonId,
                orElse: () => null,
              ) ??
          seasons.cast<SeasonDto?>().firstWhere(
                (s) => s!.isActive,
                orElse: () => null,
              ) ??
          seasons.last)
      : (seasons.cast<SeasonDto?>().firstWhere(
                (s) => s!.isActive,
                orElse: () => null,
              ) ??
          seasons.last);

  // Resolve event: preserve persisted eventId if it still exists in the
  // season, otherwise default to "All Events" (null eventId).
  SeasonEventDto? resolvedEvent;
  if (persisted?.eventId != null && season.events.isNotEmpty) {
    resolvedEvent = season.events
        .cast<SeasonEventDto?>()
        .firstWhere((e) => e!.id == persisted!.eventId, orElse: () => null);
  }

  final ctx = SeasonEventContext(
    seasonId: season.id,
    seasonName: season.name,
    eventId: resolvedEvent?.id,
    eventName: resolvedEvent?.name,
  );
  ref.read(seasonEventContextProvider.notifier).state = ctx;
  await LeaderboardBootstrap.persistSeasonEvent(
    ctx,
    bucket: identity.bucket,
  );
  if (!identityStillCurrent()) return;
  _log.info(
    'Bootstrap: season=${season.id} (${season.name}), '
    'event=${resolvedEvent?.id ?? "All Events"}',
  );

  // Registration-freshness validation is retired: the stale-registration
  // screen it fed was deleted with the platform-owned login migration.
});
