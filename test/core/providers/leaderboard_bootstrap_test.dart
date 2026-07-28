import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ---------------------------------------------------------------------------
  // loadPersistedContext
  // ---------------------------------------------------------------------------

  group('loadPersistedContext', () {
    test('returns null when nothing persisted', () async {
      final ctx = await LeaderboardBootstrap.loadPersistedContext();
      expect(ctx, isNull);
    });

    test('returns context when season data exists', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        NetworkPrefs.prefixAccountKey('leaderboard:season_id'),
        2,
      );
      await prefs.setString(
        NetworkPrefs.prefixAccountKey('leaderboard:season_name'),
        'Season 2',
      );

      final ctx = await LeaderboardBootstrap.loadPersistedContext();

      expect(ctx, isNotNull);
      expect(ctx!.seasonId, 2);
      expect(ctx.seasonName, 'Season 2');
      expect(ctx.eventId, isNull);
    });

    test('returns context with null name if only ID persisted', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        NetworkPrefs.prefixAccountKey('leaderboard:season_id'),
        3,
      );

      final ctx = await LeaderboardBootstrap.loadPersistedContext();

      expect(ctx, isNotNull);
      expect(ctx!.seasonId, 3);
      expect(ctx.seasonName, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // persistSeasonEvent
  // ---------------------------------------------------------------------------

  group('persistSeasonEvent', () {
    test('persists season data from context', () async {
      const ctx = SeasonEventContext(
        seasonId: 5,
        seasonName: 'Season 5',
        eventId: 10,
        eventName: 'Event 10',
      );

      await LeaderboardBootstrap.persistSeasonEvent(ctx);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(NetworkPrefs.prefixAccountKey('leaderboard:season_id')),
        5,
      );
      expect(
        prefs.getString(
            NetworkPrefs.prefixAccountKey('leaderboard:season_name')),
        'Season 5',
      );
    });

    test('no-op when seasonId is null', () async {
      const ctx = SeasonEventContext();

      await LeaderboardBootstrap.persistSeasonEvent(ctx);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(NetworkPrefs.prefixAccountKey('leaderboard:season_id')),
        isNull,
      );
    });

    test('overwrites previously persisted season', () async {
      // Persist initial data
      await LeaderboardBootstrap.persistSeasonEvent(
        const SeasonEventContext(seasonId: 1, seasonName: 'S1'),
      );

      // Overwrite
      await LeaderboardBootstrap.persistSeasonEvent(
        const SeasonEventContext(seasonId: 2, seasonName: 'S2'),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(NetworkPrefs.prefixAccountKey('leaderboard:season_id')),
        2,
      );
      expect(
        prefs.getString(
            NetworkPrefs.prefixAccountKey('leaderboard:season_name')),
        'S2',
      );
    });

    test('persists event-only context (v1 registration path)', () async {
      await LeaderboardBootstrap.persistSeasonEvent(
        const SeasonEventContext(eventId: 10, eventName: 'Event 10'),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(NetworkPrefs.prefixAccountKey('leaderboard:event_id')),
        10,
      );
      expect(
        prefs
            .getString(NetworkPrefs.prefixAccountKey('leaderboard:event_name')),
        'Event 10',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // RegistrationFreshness enum
  // ---------------------------------------------------------------------------

  group('RegistrationFreshness', () {
    test('enum values exist', () {
      expect(RegistrationFreshness.values, hasLength(3));
      expect(RegistrationFreshness.current, isNotNull);
      expect(RegistrationFreshness.stale, isNotNull);
      expect(RegistrationFreshness.unknown, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Stale registration detection (unit-level, no Riverpod container)
  // ---------------------------------------------------------------------------

  group('Stale detection via persisted context', () {
    test('matching eventId indicates current registration', () async {
      await LeaderboardBootstrap.persistSeasonEvent(
        const SeasonEventContext(
            seasonId: 1, seasonName: 'S1', eventId: 10, eventName: 'E10'),
      );

      final ctx = await LeaderboardBootstrap.loadPersistedContext();
      // eventId matches the "current active event" (10)
      expect(ctx!.eventId, 10);
      // In the real bootstrap, this would set RegistrationFreshness.current
    });

    test('mismatched eventId indicates stale registration', () async {
      await LeaderboardBootstrap.persistSeasonEvent(
        const SeasonEventContext(
            seasonId: 1, seasonName: 'S1', eventId: 5, eventName: 'E5'),
      );

      final ctx = await LeaderboardBootstrap.loadPersistedContext();
      // eventId (5) != current active event (10)
      expect(ctx!.eventId, isNot(equals(10)));
      // In the real bootstrap, this would set RegistrationFreshness.stale
    });

    test('no eventId with participant indicates legacy v1 registration',
        () async {
      // Only season persisted (legacy v1 path)
      await LeaderboardBootstrap.persistSeasonEvent(
        const SeasonEventContext(seasonId: 1, seasonName: 'S1'),
      );

      final ctx = await LeaderboardBootstrap.loadPersistedContext();
      expect(ctx!.eventId, isNull);
      // In the real bootstrap, this would trigger an API check
    });
  });
}
