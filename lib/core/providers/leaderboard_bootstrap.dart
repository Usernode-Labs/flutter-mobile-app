import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

final _log = LoggingService.instance.withTag('usernode/LeaderboardBootstrap');

const _seasonIdKey = 'leaderboard:season_id';
const _seasonNameKey = 'leaderboard:season_name';

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
    await _persistSeason(result.seasonId, result.seasonName);
    _log.info(
      'Persisted participant=${result.participantId}, '
      'season=${result.seasonId} (${result.seasonName})',
    );
    return SeasonEventContext(
      seasonId: result.seasonId,
      seasonName: result.seasonName,
    );
  }

  /// Load persisted season context for cold-start hydration.
  /// Returns null if no leaderboard data has been persisted.
  static Future<SeasonEventContext?> loadPersistedContext() async {
    final prefs = await SharedPreferences.getInstance();
    final seasonId = prefs.getInt(NetworkPrefs.prefixKey(_seasonIdKey));
    if (seasonId == null) return null;
    final seasonName = prefs.getString(NetworkPrefs.prefixKey(_seasonNameKey));
    return SeasonEventContext(seasonId: seasonId, seasonName: seasonName);
  }

  /// Persist a season/event selection (e.g. when the user switches season
  /// via a [DropdownChip] in the leaderboard UI).
  static Future<void> persistSeasonEvent(SeasonEventContext ctx) async {
    if (ctx.seasonId == null) return;
    await _persistSeason(ctx.seasonId!, ctx.seasonName);
  }

  // -- private ---------------------------------------------------------------

  static Future<void> _persistSeason(
    int seasonId,
    String? seasonName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(NetworkPrefs.prefixKey(_seasonIdKey), seasonId);
    if (seasonName != null) {
      await prefs.setString(
        NetworkPrefs.prefixKey(_seasonNameKey),
        seasonName,
      );
    }
  }
}

/// Refresh all active leaderboard providers silently.
/// For pull-to-refresh on the leaderboard screen.
Future<void> refreshAllLeaderboardData(Ref ref) async {
  await Future.wait([
    ref.read(rankingProvider.notifier).silentRefresh(),
    ref.read(challengesProvider.notifier).silentRefresh(),
    ref.read(leaderboardProvider.notifier).silentRefresh(),
    ref.read(breakdownProvider.notifier).silentRefresh(),
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
  final ctx = await LeaderboardBootstrap.loadPersistedContext();
  if (ctx != null) {
    _log.info('Restored season context: seasonId=${ctx.seasonId}');
    ref.read(seasonEventContextProvider.notifier).state = ctx;
  }
});
