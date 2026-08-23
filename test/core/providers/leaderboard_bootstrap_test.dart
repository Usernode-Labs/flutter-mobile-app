import 'dart:async';
import 'dart:convert';

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
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

const _namespace = 'aaaaaaaaaaaaaaaa';

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
  const address = 'address-a';
  final bucket = NetworkPrefs.bucketForAddress(address);
  FlutterSecureStorage.setMockInitialValues({
    'auth:v3:session_token': 'token-a',
  });
  SharedPreferences.setMockInitialValues({
    'testnet:identity:namespace': _namespace,
    'testnet:user:$_namespace:accounts:index': jsonEncode([
      {
        'id': 'account-a',
        'name': 'Node Account',
        'createdAt': '2026-01-01T00:00:00.000',
        'derivationPath': 'imported',
        'hdIndex': 0,
        'address': address,
        'publicKey': 'utpk1$address',
        'backupConfirmed': true,
        'isDemo': false,
      },
    ]),
    'testnet:user:$_namespace:accounts:activeId': 'account-a',
    'testnet:acct:$bucket:leaderboard:participant_id': 7,
    'testnet:acct:$bucket:identity:provisioned_season': 1,
    'testnet:acct:$bucket:identity:lifecycle_ownership_confirmed': true,
  });
  final controller = SessionController(
    tokenStore: AuthTokenStore(),
    guestFlag: AuthGuestFlag(),
    repository: AuthRepository(),
    suspendNode: () async {},
  );
  await controller.restore();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('leaderboardBootstrapProvider identity lease', () {
    test('does not fetch until the authenticated identity is ready', () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth:v3:session_token': 'token-a',
      });
      SharedPreferences.setMockInitialValues({
        'testnet:account:reconcile_pending': true,
        'testnet:acct:guest:leaderboard:participant_id': 7,
      });
      final controller = SessionController(
        tokenStore: AuthTokenStore(),
        guestFlag: AuthGuestFlag(),
        repository: AuthRepository(),
        suspendNode: () async {},
      );
      await controller.restore();
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

      final bootstrapSubscription = container.listen<AsyncValue<void>>(
        leaderboardBootstrapProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(bootstrapSubscription.close);
      await service.started.future;

      await controller.beginSeasonRollover(activeSeasonId: 2);
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
    });
  });
}
