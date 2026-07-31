import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';

const _identityA = Identity(
  epoch: 1,
  phase: IdentityPhase.ready,
  participantId: 11,
  accountId: 'account-a',
  address: 'address-a',
);

const _identityB = Identity(
  epoch: 2,
  phase: IdentityPhase.ready,
  participantId: 22,
  accountId: 'account-b',
  address: 'address-b',
);

const _rankingA = RankingResult(
  scope: 'season',
  rank: 11,
  totalPoints: 110,
  offchainPoints: 110,
  totalParticipants: 100,
  seasonId: 1,
);

const _rankingB = RankingResult(
  scope: 'season',
  rank: 22,
  totalPoints: 220,
  offchainPoints: 220,
  totalParticipants: 100,
  seasonId: 1,
);

BreakdownResult _breakdown(String owner, int eventId) => BreakdownResult(
      scope: 'season',
      displayName: owner,
      totalPoints: eventId,
      offchainPoints: eventId,
      seasonBreakdown: SeasonBreakdown(
        seasonId: 1,
        seasonName: 'Season 1',
        totalPoints: eventId,
        offchainPoints: eventId,
        events: [
          EventBreakdown(
            eventId: eventId,
            eventName: 'Event $eventId',
            totalPoints: eventId,
            offchainPoints: eventId,
          ),
        ],
      ),
    );

class _TestSessionController extends SessionController {
  _TestSessionController()
      : super(
          tokenStore: AuthTokenStore(),
          guestFlag: AuthGuestFlag(),
          repository: AuthRepository(),
          suspendNode: () async {},
        );

  void replaceWith(Identity identity) {
    IdentitySnapshots.publish(identity);
    state = identity;
  }
}

class _DeferredCalls<T> {
  final requests = <Completer<T>>[];
  Completer<void> _changed = Completer<void>();

  Future<T> add() {
    final request = Completer<T>();
    requests.add(request);
    final changed = _changed;
    _changed = Completer<void>();
    changed.complete();
    return request.future;
  }

  Future<Completer<T>> at(int index) async {
    while (requests.length <= index) {
      await _changed.future;
    }
    return requests[index];
  }
}

class _DeferredLeaderboardApiService extends LeaderboardApiService {
  final ranking = _DeferredCalls<RankingResult>();
  final breakdown = _DeferredCalls<BreakdownResult>();

  @override
  Future<RankingResult> getRanking({
    int? seasonId,
    int? eventId,
    IdentityLease? authority,
  }) =>
      ranking.add();

  @override
  Future<BreakdownResult> getBreakdown({
    int? seasonId,
    int? eventId,
    IdentityLease? authority,
  }) =>
      breakdown.add();

  @override
  void dispose() {}
}

ProviderContainer _container(
  _TestSessionController identity,
  _DeferredLeaderboardApiService service,
) {
  final container = ProviderContainer(
    overrides: [
      identityProvider.overrideWith((ref) => identity),
      leaderboardApiServiceProvider.overrideWithValue(service),
    ],
  );
  container.read(seasonEventContextProvider.notifier).state =
      const SeasonEventContext(seasonId: 1, seasonName: 'Season 1');
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    IdentitySnapshots.reset();
  });
  tearDown(IdentitySnapshots.reset);

  test('silent refresh from A cannot overwrite rebuilt B ranking', () async {
    final identity = _TestSessionController()..replaceWith(_identityA);
    final service = _DeferredLeaderboardApiService();
    final container = _container(identity, service);
    final subscription = container.listen<AsyncValue<RankingResult?>>(
      rankingProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final initial = container.read(rankingProvider.future);
    (await service.ranking.at(0)).complete(_rankingA);
    expect((await initial)?.rank, 11);

    final staleRefresh =
        container.read(rankingProvider.notifier).silentRefresh();
    final staleRequest = await service.ranking.at(1);

    // Both snapshots are authenticated and ready. Only an exact identity
    // watch distinguishes this replacement from an ordinary rebuild.
    identity.replaceWith(_identityB);
    final currentRequest = await service.ranking.at(2);
    currentRequest.complete(_rankingB);
    expect((await container.read(rankingProvider.future))?.rank, 22);

    staleRequest.complete(_rankingA);
    await staleRefresh;
    await container.pump();

    expect(container.read(rankingProvider).value?.rank, 22);
    expect(service.ranking.requests, hasLength(3));
  });

  test('stale A breakdown cannot mutate B event picker state', () async {
    final identity = _TestSessionController()..replaceWith(_identityA);
    final service = _DeferredLeaderboardApiService();
    final container = _container(identity, service);

    final subscription = container.listen<AsyncValue<BreakdownResult?>>(
      breakdownProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final staleRequest = await service.breakdown.at(0);

    identity.replaceWith(_identityB);
    final currentRequest = await service.breakdown.at(1);
    currentRequest.complete(_breakdown('B', 22));
    expect(
      (await container.read(breakdownProvider.future))?.displayName,
      'B',
    );
    expect(container.read(participantEventIdsProvider), {22});

    staleRequest.complete(_breakdown('A', 11));
    await pumpEventQueue();

    expect(container.read(breakdownProvider).value?.displayName, 'B');
    expect(container.read(participantEventIdsProvider), {22});
  });
}
