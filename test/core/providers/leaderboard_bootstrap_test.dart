import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

class _RecordingSeasonsService extends LeaderboardApiService {
  _RecordingSeasonsService({this.blocked = false})
      : super(baseUrl: 'https://example.test/api/v4/mobile');

  final bool blocked;
  final started = Completer<void>();
  final release = Completer<List<SeasonDto>>();
  int calls = 0;

  @override
  Future<List<SeasonDto>> getSeasons({
    int? seasonId,
    bool? onlyActiveSeasons,
    bool? onlyCurrentSeason,
    bool? onlyActiveEvents,
    bool? onlyCurrentEvents,
  }) async {
    calls++;
    if (!started.isCompleted) started.complete();
    if (blocked) return release.future;
    return const <SeasonDto>[];
  }
}

Future<SessionController> _readyIdentityController() async {
  final controller = SessionController(
    tokenStore: AuthTokenStore(),
    guestFlag: AuthGuestFlag(),
    repository: AuthRepository(),
    suspendNode: () async {},
  );
  await controller.completeLogin(
    const AuthSession(
      token: 'token-a',
      participant: Participant(
        id: 7,
        email: 'a@example.test',
        emailConfirmed: true,
      ),
    ),
  );
  await controller.reconcileSucceeded(
    epoch: IdentitySnapshots.current.epoch,
    accountId: 'account-a',
    address: 'address-a',
    participantId: 7,
    provisionedSeasonId: 1,
  );
  return controller;
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    IdentitySnapshots.reset();
    NetworkPrefs.setActiveBucket(null, guest: true);
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

    test('resets to unknown as soon as the exact identity changes', () async {
      final controller = await _readyIdentityController();
      final container = ProviderContainer(overrides: [
        identityProvider.overrideWith((ref) => controller),
      ]);
      addTearDown(container.dispose);

      container.read(registrationFreshnessProvider.notifier).state =
          RegistrationFreshness.current;
      expect(
        container.read(registrationFreshnessProvider),
        RegistrationFreshness.current,
      );

      await controller.continueAsGuest();

      expect(
        container.read(registrationFreshnessProvider),
        RegistrationFreshness.unknown,
      );
    });
  });

  group('resolvePreferredSeason', () {
    const newest = SeasonDto(id: 3, name: 'Season 3', isActive: false);
    const active = SeasonDto(id: 2, name: 'Season 2', isActive: true);
    const oldest = SeasonDto(id: 1, name: 'Season 1', isActive: false);
    const seasons = [newest, active, oldest];

    test('keeps the persisted season when it is still available', () {
      expect(
        resolvePreferredSeason(seasons, preferredSeasonId: oldest.id),
        same(oldest),
      );
    });

    test('falls back to the active season when the persisted one is gone', () {
      expect(
        resolvePreferredSeason(seasons, preferredSeasonId: 99),
        same(active),
      );
    });

    test('falls back to the newest season when none is active', () {
      expect(
        resolvePreferredSeason(const [newest, oldest]),
        same(newest),
      );
    });

    test('rejects an empty response instead of inventing a selection', () {
      expect(
        () => resolvePreferredSeason(const []),
        throwsArgumentError,
      );
    });
  });

  group('leaderboardBootstrapProvider identity lease', () {
    test('does not fetch until the authenticated identity is ready', () async {
      final controller = SessionController(
        tokenStore: AuthTokenStore(),
        guestFlag: AuthGuestFlag(),
        repository: AuthRepository(),
        suspendNode: () async {},
      );
      await controller.completeLogin(
        const AuthSession(
          token: 'token-a',
          participant: Participant(
            id: 7,
            email: 'a@example.test',
            emailConfirmed: true,
          ),
        ),
      );
      final service = _RecordingSeasonsService();
      final container = ProviderContainer(overrides: [
        identityProvider.overrideWith((ref) => controller),
        leaderboardApiServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(container.dispose);
      addTearDown(service.dispose);

      await container.read(leaderboardBootstrapProvider.future);
      expect(service.calls, 0);

      await controller.reconcileSucceeded(
        epoch: IdentitySnapshots.current.epoch,
        accountId: 'account-a',
        address: 'address-a',
        participantId: 7,
        provisionedSeasonId: 1,
      );
      await container.read(leaderboardBootstrapProvider.future);

      expect(service.calls, 1);
    });

    test('drops a seasons response after its captured identity changes',
        () async {
      final controller = await _readyIdentityController();
      final service = _RecordingSeasonsService(blocked: true);
      final container = ProviderContainer(overrides: [
        identityProvider.overrideWith((ref) => controller),
        leaderboardApiServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(container.dispose);
      addTearDown(service.dispose);
      addTearDown(() {
        if (!service.release.isCompleted) {
          service.release.complete(const <SeasonDto>[]);
        }
      });

      container.read(registrationFreshnessProvider.notifier).state =
          RegistrationFreshness.stale;
      final bootstrapSubscription = container.listen<AsyncValue<void>>(
        leaderboardBootstrapProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(bootstrapSubscription.close);
      await service.started.future;

      await controller.continueAsGuest();
      await container.pump();
      final currentBootstrap =
          container.read(leaderboardBootstrapProvider.future);
      service.release.complete([
        const SeasonDto(
          id: 2,
          name: 'Season B',
          isActive: true,
        ),
      ]);
      // The identity change invalidates the original provider generation.
      // Await the replacement generation instead of its abandoned `.future`,
      // then flush the released stale continuation before asserting.
      await currentBootstrap;
      await pumpEventQueue();

      expect(container.read(seasonEventContextProvider).seasonId, isNull);
      expect(
        container.read(registrationFreshnessProvider),
        RegistrationFreshness.unknown,
      );
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
