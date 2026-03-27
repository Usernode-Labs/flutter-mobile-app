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

final _log = LoggingService.instance.withTag('usernode/LeaderboardBootstrap');

const _seasonIdKey = 'leaderboard:season_id';
const _seasonNameKey = 'leaderboard:season_name';
const _eventIdKey = 'leaderboard:event_id';
const _eventNameKey = 'leaderboard:event_name';

/// Bootstraps leaderboard state from persisted data and registration results.
///
/// Two primary use cases:
///
/// 1. **After v2 registration** — call [handleRegistration] to persist
///    participant + season data, then set the returned context:
///    ```dart
///    final ctx = await LeaderboardBootstrap.handleRegistration(v2Result);
///    ref.read(seasonEventContextProvider.notifier).state = ctx;
///    ref.invalidate(participantIdProvider);
///    ```
///
/// 2. **Cold start** — watch [leaderboardBootstrapProvider] in the app shell
///    to auto-restore the [SeasonEventContext] from SharedPreferences.
class LeaderboardBootstrap {
  /// Persist registration data. Returns the [SeasonEventContext] to set on
  /// [seasonEventContextProvider].
  static Future<SeasonEventContext> handleRegistration(
    RegistrationV2Result result,
  ) async {
    await saveParticipantId(result.participantId);
    final ctx = SeasonEventContext(
      seasonId: result.seasonId,
      seasonName: result.seasonName,
    );
    if (result.seasonId != null) {
      await _persistContext(ctx);
    }
    _log.info(
      'Persisted participant=${result.participantId}, '
      'season=${result.seasonId} (${result.seasonName})',
    );
    return ctx;
  }

  /// Load persisted season context for cold-start hydration.
  /// Returns null if no leaderboard data has been persisted.
  static Future<SeasonEventContext?> loadPersistedContext() async {
    final prefs = await SharedPreferences.getInstance();
    final seasonId = prefs.getInt(NetworkPrefs.prefixKey(_seasonIdKey));
    if (seasonId == null) return null;
    final seasonName = prefs.getString(NetworkPrefs.prefixKey(_seasonNameKey));
    final eventId = prefs.getInt(NetworkPrefs.prefixKey(_eventIdKey));
    final eventName = prefs.getString(NetworkPrefs.prefixKey(_eventNameKey));
    return SeasonEventContext(
      seasonId: seasonId,
      seasonName: seasonName,
      eventId: eventId,
      eventName: eventName,
    );
  }

  /// Persist a season/event selection (e.g. when the user switches season
  /// via a [DropdownChip] in the leaderboard UI).
  static Future<void> persistSeasonEvent(SeasonEventContext ctx) async {
    if (ctx.seasonId == null && ctx.eventId == null) return;
    await _persistContext(ctx);
  }

  // -- private ---------------------------------------------------------------

  static Future<void> _persistContext(SeasonEventContext ctx) async {
    final prefs = await SharedPreferences.getInstance();
    if (ctx.seasonId != null) {
      await prefs.setInt(NetworkPrefs.prefixKey(_seasonIdKey), ctx.seasonId!);
    }
    if (ctx.seasonName != null) {
      await prefs.setString(
        NetworkPrefs.prefixKey(_seasonNameKey),
        ctx.seasonName!,
      );
    }
    if (ctx.eventId != null) {
      await prefs.setInt(NetworkPrefs.prefixKey(_eventIdKey), ctx.eventId!);
    }
    if (ctx.eventName != null) {
      await prefs.setString(
        NetworkPrefs.prefixKey(_eventNameKey),
        ctx.eventName!,
      );
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

/// SharedPreferences key for the stale-banner dismiss flag.
/// Used by the banner widget and cleared on re-registration.
const staleBannerDismissedKey = 'registration:stale_banner_dismissed';

/// Refresh all active leaderboard providers silently.
/// For pull-to-refresh on the leaderboard screen.
Future<void> refreshAllLeaderboardData(Ref ref) async {
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
  final persisted = await LeaderboardBootstrap.loadPersistedContext();

  // Fast path: restore full context immediately so downstream providers
  // get data without waiting for the API.
  if (persisted != null && persisted.eventId != null) {
    _log.info(
      'Restored full context: seasonId=${persisted.seasonId}, '
      'eventId=${persisted.eventId}',
    );
    ref.read(seasonEventContextProvider.notifier).state = persisted;
    // Fall through to the API call below to validate freshness
    // and update the context if a newer event is active.
  } else {
    _log.info(
      persisted != null
          ? 'Persisted seasonId=${persisted.seasonId} but no eventId, '
              'resolving from seasons API…'
          : 'No persisted context, auto-selecting from seasons API…',
    );
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
              orElse: () => null) ??
          seasons
              .cast<SeasonDto?>()
              .firstWhere((s) => s!.isActive, orElse: () => null) ??
          seasons.last)
      : (seasons
              .cast<SeasonDto?>()
              .firstWhere((s) => s!.isActive, orElse: () => null) ??
          seasons.last);

  // Resolve event: active one, or last in the list.
  SeasonEventDto? event;
  if (season.events.isNotEmpty) {
    event = season.events
            .cast<SeasonEventDto?>()
            .firstWhere((e) => e!.isActive, orElse: () => null) ??
        season.events.last;
  }

  final ctx = SeasonEventContext(
    seasonId: season.id,
    seasonName: season.name,
    eventId: event?.id,
    eventName: event?.name,
  );
  ref.read(seasonEventContextProvider.notifier).state = ctx;
  await LeaderboardBootstrap.persistSeasonEvent(ctx);
  _log.info(
    'Auto-selected season=${season.id} (${season.name}), '
    'event=${event?.id} (${event?.name})',
  );

  // Validate registration freshness against current active event
  // Pass the original persisted context (before API override) for comparison
  await _validateRegistrationFreshness(ref,
      currentActiveEventId: event?.id, persisted: persisted);
});

/// Checks whether the persisted registration belongs to the current active
/// event. Sets [registrationFreshnessProvider] accordingly.
Future<void> _validateRegistrationFreshness(
  Ref ref, {
  required int? currentActiveEventId,
  SeasonEventContext? persisted,
}) async {
  if (currentActiveEventId == null) {
    _log.info('No active event to validate registration against');
    return;
  }

  persisted ??= await LeaderboardBootstrap.loadPersistedContext();
  final participantId = await ref.read(participantIdProvider.future);

  if (participantId == null) {
    // No registration at all — nothing to check
    return;
  }

  // Case 1 — persisted eventId matches current active event
  if (persisted?.eventId != null &&
      persisted!.eventId == currentActiveEventId) {
    _log.info('Registration is current (eventId=${persisted.eventId})');
    ref.read(registrationFreshnessProvider.notifier).state =
        RegistrationFreshness.current;
    return;
  }

  // Case 2 — persisted eventId exists but doesn't match
  if (persisted?.eventId != null &&
      persisted!.eventId != currentActiveEventId) {
    _log.warn(
      'Registration is stale: persisted eventId=${persisted.eventId}, '
      'current=$currentActiveEventId',
    );
    ref.read(registrationFreshnessProvider.notifier).state =
        RegistrationFreshness.stale;
    return;
  }

  // Case 3 — no persisted eventId (legacy v1 registration)
  // Verify via API whether participant is in the current event
  _log.info(
    'No persisted eventId — checking API for participant $participantId '
    'in event $currentActiveEventId',
  );
  try {
    final service = ref.read(leaderboardApiServiceProvider);
    await service.getRanking(
      participantId: participantId,
      eventId: currentActiveEventId,
    );
    // Success — participant is in the current event, backfill eventId
    _log.info('Participant is in current event — backfilling eventId');
    ref.read(registrationFreshnessProvider.notifier).state =
        RegistrationFreshness.current;
    final updated = (persisted ?? const SeasonEventContext()).copyWith(
      eventId: currentActiveEventId,
    );
    await LeaderboardBootstrap.persistSeasonEvent(updated);
  } on LeaderboardApiException catch (e) {
    // Only 404 means "participant not in this event".
    // Any other status (500, 503, etc.) is a server error — don't block the user.
    if (e.statusCode == 404) {
      _log.warn('Participant not in current event (404): $e');
      ref.read(registrationFreshnessProvider.notifier).state =
          RegistrationFreshness.stale;
    } else {
      _log.warn(
          'Ranking API returned ${e.statusCode} — leaving freshness unknown');
    }
  } catch (e) {
    // Network error — don't block the user
    _log.warn('Failed to verify registration freshness: $e');
    // Leave as unknown
  }
}
