import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/event_points_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

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
  static Future<SeasonEventContext?> loadPersistedContext() async {
    final prefs = await SharedPreferences.getInstance();
    final seasonId = prefs.getInt(NetworkPrefs.prefixAccountKey(_seasonIdKey));
    if (seasonId == null) return null;
    final seasonName =
        prefs.getString(NetworkPrefs.prefixAccountKey(_seasonNameKey));
    final eventId = prefs.getInt(NetworkPrefs.prefixAccountKey(_eventIdKey));
    final eventName =
        prefs.getString(NetworkPrefs.prefixAccountKey(_eventNameKey));
    return SeasonEventContext(
      seasonId: seasonId,
      seasonName: seasonName,
      eventId: eventId,
      eventName: eventName,
    );
  }

  /// Persist a season/event selection (e.g. when the user picks an event
  /// or "All Events" via the event picker).
  static Future<void> persistSeasonEvent(SeasonEventContext ctx) async {
    if (ctx.seasonId == null && ctx.eventId == null) return;
    await _persistContext(ctx);
  }

  // -- private ---------------------------------------------------------------

  static Future<void> _persistContext(SeasonEventContext ctx) async {
    final prefs = await SharedPreferences.getInstance();
    if (ctx.seasonId != null) {
      await prefs.setInt(
          NetworkPrefs.prefixAccountKey(_seasonIdKey), ctx.seasonId!);
    }
    if (ctx.seasonName != null) {
      await prefs.setString(
        NetworkPrefs.prefixAccountKey(_seasonNameKey),
        ctx.seasonName!,
      );
    }
    if (ctx.eventId != null) {
      await prefs.setInt(
          NetworkPrefs.prefixAccountKey(_eventIdKey), ctx.eventId!);
    } else {
      await prefs.remove(NetworkPrefs.prefixAccountKey(_eventIdKey));
    }
    if (ctx.eventName != null) {
      await prefs.setString(
        NetworkPrefs.prefixAccountKey(_eventNameKey),
        ctx.eventName!,
      );
    } else {
      await prefs.remove(NetworkPrefs.prefixAccountKey(_eventNameKey));
    }
  }
}

// ---------------------------------------------------------------------------
// Registration freshness detection
// ---------------------------------------------------------------------------

enum RegistrationFreshness { current, stale, unknown }

final registrationFreshnessProvider = StateProvider<RegistrationFreshness>(
  (ref) => RegistrationFreshness.unknown,
);

/// Refresh all active leaderboard providers silently.
/// Called from zkpassport flow completion and other non-screen contexts.
/// Screen pull-to-refresh calls individual provider refreshes directly.
/// Throttled to at most once every 5 seconds.
DateTime? _lastRefreshAt;

/// Reset throttle state for testing.
@visibleForTesting
void resetRefreshThrottle() => _lastRefreshAt = null;

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
    ref.read(rankingProvider.notifier).silentRefresh(),
    ref.read(challengesProvider.notifier).silentRefresh(),
    ref.read(leaderboardProvider.notifier).silentRefresh(),
    ref.read(breakdownProvider.notifier).silentRefresh(),
    ref.read(seasonsProvider.notifier).silentRefresh(),
    ref.read(eventPointsProvider.notifier).silentRefresh(),
  ]);
}

/// Auto-restores [seasonEventContextProvider] from persisted data on cold start.
///
/// Watch this in the app shell or splash screen to trigger restoration:
/// ```dart
/// ref.watch(leaderboardBootstrapProvider);
/// ```
///
/// Downstream providers ([rankingProvider], [challengesProvider], etc.) watch
/// [seasonEventContextProvider] and rebuild automatically once the context is
/// populated.
final leaderboardBootstrapProvider = FutureProvider<void>((ref) async {
  // The router keeps this provider alive for EVERY session type, but the
  // v4 data endpoints (starting with /seasons below) all require a session
  // token — an unauthenticated call 401s and tears down the session via
  // onUnauthorized, which would bounce a restored guest to the auth
  // landing. Watching the status also re-runs the bootstrap after login.
  if (ref.watch(authStatusProvider) != AuthStatus.authenticated) return;

  final persisted = await LeaderboardBootstrap.loadPersistedContext();

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
    _log.warn('Failed to fetch seasons for auto-select: $e');
    // If we have partial persisted data, use it rather than nothing.
    if (persisted != null) {
      ref.read(seasonEventContextProvider.notifier).state = persisted;
    }
    return;
  }

  if (seasons.isEmpty) {
    _log.info('No seasons available — skipping auto-select');
    if (persisted != null) {
      ref.read(seasonEventContextProvider.notifier).state = persisted;
    }
    return;
  }

  // Resolve season: prefer persisted seasonId, then active, then last.
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
  await LeaderboardBootstrap.persistSeasonEvent(ctx);
  _log.info(
    'Bootstrap: season=${season.id} (${season.name}), '
    'event=${resolvedEvent?.id ?? "All Events"}',
  );

  // Validate registration freshness at the season level.
  // With season continuity, registration happens via the season phase
  // and auto-enroll covers all events — so freshness is about whether
  // the user is registered in the current active season.
  await _validateRegistrationFreshness(ref,
      currentSeasonId: season.id, persisted: persisted);
});

/// Checks whether the persisted registration belongs to the current active
/// season. Sets [registrationFreshnessProvider] accordingly.
///
/// With season continuity, users register once via the season phase and are
/// auto-enrolled in all events. Staleness means the user's registration
/// belongs to a different (older) season.
Future<void> _validateRegistrationFreshness(
  Ref ref, {
  required int currentSeasonId,
  SeasonEventContext? persisted,
}) async {
  persisted ??= await LeaderboardBootstrap.loadPersistedContext();
  final participantId = await ref.read(participantIdProvider.future);

  if (participantId == null) {
    return;
  }

  // Case 1 — persisted seasonId matches current season → current
  if (persisted?.seasonId != null && persisted!.seasonId == currentSeasonId) {
    _log.info('Registration is current (seasonId=${persisted.seasonId})');
    ref.read(registrationFreshnessProvider.notifier).state =
        RegistrationFreshness.current;
    return;
  }

  // Case 2 — persisted seasonId exists but doesn't match → stale
  if (persisted?.seasonId != null && persisted!.seasonId != currentSeasonId) {
    _log.warn(
      'Registration is stale: persisted seasonId=${persisted.seasonId}, '
      'current=$currentSeasonId',
    );
    ref.read(registrationFreshnessProvider.notifier).state =
        RegistrationFreshness.stale;
    return;
  }

  // Case 3 — no persisted seasonId (legacy registration)
  // Verify via API whether participant has data in the current season
  _log.info(
    'No persisted seasonId — checking API for participant $participantId '
    'in season $currentSeasonId',
  );
  try {
    final service = ref.read(leaderboardApiServiceProvider);
    await service.getRanking(seasonId: currentSeasonId);
    _log.info('Participant is in current season — backfilling seasonId');
    ref.read(registrationFreshnessProvider.notifier).state =
        RegistrationFreshness.current;
    final updated = (persisted ?? const SeasonEventContext()).copyWith(
      seasonId: currentSeasonId,
    );
    await LeaderboardBootstrap.persistSeasonEvent(updated);
  } on LeaderboardApiException catch (e) {
    if (e.statusCode == 404) {
      _log.warn('Participant not in current season (404): $e');
      ref.read(registrationFreshnessProvider.notifier).state =
          RegistrationFreshness.stale;
    } else {
      _log.warn(
          'Ranking API returned ${e.statusCode} — leaving freshness unknown');
    }
  } catch (e) {
    _log.warn('Failed to verify registration freshness: $e');
  }
}
