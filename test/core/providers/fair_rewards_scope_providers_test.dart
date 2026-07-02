import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';

class _RecordingLeaderboardApiService extends LeaderboardApiService {
  ({
    int? seasonId,
    int? eventId,
    int? participantId,
    bool? activeOnly
  })? challengesCall;
  ({int participantId, int? seasonId, int? eventId})? breakdownCall;
  ({int participantId, int? seasonId, int? eventId})? rankingCall;

  @override
  Future<List<ChallengeDto>> getChallenges({
    int? seasonId,
    int? eventId,
    int? participantId,
    bool? activeOnly,
    bool? onlyScheduled,
  }) async {
    challengesCall = (
      seasonId: seasonId,
      eventId: eventId,
      participantId: participantId,
      activeOnly: activeOnly,
    );
    return const [];
  }

  @override
  Future<BreakdownResult> getBreakdown({
    required int participantId,
    int? seasonId,
    int? eventId,
  }) async {
    breakdownCall = (
      participantId: participantId,
      seasonId: seasonId,
      eventId: eventId,
    );
    return BreakdownResult(
      scope: eventId != null ? 'event' : 'season',
      displayName: 'Alice',
      totalPoints: 0,
      offchainPoints: 0,
      eventBreakdown: eventId == null
          ? null
          : EventBreakdown(
              eventId: eventId,
              eventName: 'Phase $eventId',
              totalPoints: 0,
              offchainPoints: 0,
            ),
      seasonBreakdown: eventId != null
          ? null
          : SeasonBreakdown(
              seasonId: seasonId!,
              seasonName: 'Season $seasonId',
              totalPoints: 0,
              offchainPoints: 0,
            ),
    );
  }

  @override
  Future<RankingResult> getRanking({
    required int participantId,
    int? seasonId,
    int? eventId,
  }) async {
    rankingCall = (
      participantId: participantId,
      seasonId: seasonId,
      eventId: eventId,
    );
    return RankingResult(
      scope: eventId != null ? 'event' : 'season',
      rank: 1,
      totalPoints: 0,
      offchainPoints: 0,
      totalParticipants: 1,
      seasonId: eventId == null ? seasonId : null,
      eventId: eventId,
    );
  }

  @override
  void dispose() {}
}

ProviderContainer _container(
  _RecordingLeaderboardApiService service,
  SeasonEventContext context,
) {
  final container = ProviderContainer(
    overrides: [
      leaderboardApiServiceProvider.overrideWithValue(service),
      participantIdProvider.overrideWith((ref) => 42),
      seasonEventContextProvider.overrideWith((ref) => context),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('Fair Rewards scoped providers', () {
    test('event id takes precedence over season id', () async {
      final service = _RecordingLeaderboardApiService();
      final container = _container(
        service,
        const SeasonEventContext(
          seasonId: 1,
          seasonName: 'Season 1',
          eventId: 3,
          eventName: 'Phase 1',
        ),
      );

      await container.read(challengesProvider.future);
      await container.read(breakdownProvider.future);
      await container.read(rankingProvider.future);

      expect(service.challengesCall?.seasonId, isNull);
      expect(service.challengesCall?.eventId, 3);
      expect(service.challengesCall?.participantId, 42);
      expect(service.challengesCall?.activeOnly, isTrue);
      expect(service.breakdownCall?.seasonId, isNull);
      expect(service.breakdownCall?.eventId, 3);
      expect(service.breakdownCall?.participantId, 42);
      expect(service.rankingCall?.seasonId, isNull);
      expect(service.rankingCall?.eventId, 3);
      expect(service.rankingCall?.participantId, 42);
    });

    test('season id is used when no event is selected', () async {
      final service = _RecordingLeaderboardApiService();
      final container = _container(
        service,
        const SeasonEventContext(seasonId: 1, seasonName: 'Season 1'),
      );

      await container.read(challengesProvider.future);
      await container.read(breakdownProvider.future);
      await container.read(rankingProvider.future);

      expect(service.challengesCall?.seasonId, 1);
      expect(service.challengesCall?.eventId, isNull);
      expect(service.challengesCall?.activeOnly, isTrue);
      expect(service.breakdownCall?.seasonId, 1);
      expect(service.breakdownCall?.eventId, isNull);
      expect(service.rankingCall?.seasonId, 1);
      expect(service.rankingCall?.eventId, isNull);
    });

    test('breakdown and ranking providers do not fetch global scope', () async {
      final service = _RecordingLeaderboardApiService();
      final container = _container(service, const SeasonEventContext());

      final breakdown = await container.read(breakdownProvider.future);
      final ranking = await container.read(rankingProvider.future);

      expect(breakdown, isNull);
      expect(ranking, isNull);
      expect(service.breakdownCall, isNull);
      expect(service.rankingCall, isNull);
    });
  });
}
