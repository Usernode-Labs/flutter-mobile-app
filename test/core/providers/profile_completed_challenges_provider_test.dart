import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/profile_completed_challenges_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';

class _RecordingLeaderboardApiService extends LeaderboardApiService {
  ({
    int? seasonId,
    int? eventId,
    int? participantId,
    bool? activeOnly,
  })? challengesCall;
  ({int participantId, int? seasonId, int? eventId})? breakdownCall;

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
    return const [
      ChallengeDto(
        id: 101,
        eventId: 11,
        eventName: 'Season 1 Phase',
        category: 'community',
        goal: 'Season 1 Win',
        task: 'Finish something in season 1.',
        reward: '100',
        enabled: true,
        completed: false,
        scheduleEnd: '2026-12-01T00:00:00Z',
      ),
      ChallengeDto(
        id: 202,
        eventId: 22,
        eventName: 'Season 2 Phase',
        category: 'community',
        goal: 'Season 2 Win',
        task: 'Finish something in season 2.',
        reward: '200',
        enabled: true,
        completed: false,
      ),
      ChallengeDto(
        id: 303,
        eventId: 22,
        eventName: 'Season 2 Phase',
        category: 'community',
        goal: 'Season 2 Open',
        task: 'Still open.',
        reward: '300',
        enabled: true,
        completed: false,
      ),
      ChallengeDto(
        id: 404,
        category: 'community',
        goal: 'Ambiguous duplicated challenge',
        task: 'This id exists in two events.',
        reward: '999',
        enabled: true,
        completed: false,
        activitiesTotal: 999,
      ),
    ];
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
    return const BreakdownResult(
      scope: 'global',
      displayName: 'Participant 19',
      totalPoints: 300,
      offchainPoints: 300,
      globalSeasons: [
        SeasonBreakdown(
          seasonId: 1,
          seasonName: 'Season 1',
          totalPoints: 100,
          offchainPoints: 100,
          events: [
            EventBreakdown(
              eventId: 11,
              eventName: 'Season 1 Phase',
              totalPoints: 100,
              offchainPoints: 100,
              challengeProgress: [
                ChallengeProgress(
                  challengeId: 101,
                  state: ChallengeProgressState.none,
                  earnedPoints: 100,
                ),
                ChallengeProgress(
                  challengeId: 404,
                  state: ChallengeProgressState.earned,
                  earnedPoints: 999,
                ),
              ],
            ),
          ],
        ),
        SeasonBreakdown(
          seasonId: 2,
          seasonName: 'Season 2',
          totalPoints: 200,
          offchainPoints: 200,
          events: [
            EventBreakdown(
              eventId: 22,
              eventName: 'Season 2 Phase',
              totalPoints: 200,
              offchainPoints: 200,
              challengeProgress: [
                ChallengeProgress(
                  challengeId: 202,
                  state: ChallengeProgressState.earned,
                  earnedPoints: 200,
                ),
                ChallengeProgress(
                  challengeId: 303,
                  state: ChallengeProgressState.inProgress,
                  earnedPoints: 0,
                ),
                ChallengeProgress(
                  challengeId: 404,
                  state: ChallengeProgressState.earned,
                  earnedPoints: 999,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {}
}

void main() {
  test('fetches completed profile history across all seasons', () async {
    final service = _RecordingLeaderboardApiService();
    final container = ProviderContainer(
      overrides: [
        leaderboardApiServiceProvider.overrideWithValue(service),
        participantIdProvider.overrideWith((ref) => 19),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(
      profileCompletedChallengesProvider.future,
    );

    expect(result, isNotNull);
    expect(result!.completed.map((c) => c.dto.id), [101, 202]);
    expect(service.challengesCall?.participantId, 19);
    expect(service.challengesCall?.seasonId, isNull);
    expect(service.challengesCall?.eventId, isNull);
    expect(service.challengesCall?.activeOnly, isFalse);
    expect(service.breakdownCall?.participantId, 19);
    expect(service.breakdownCall?.seasonId, isNull);
    expect(service.breakdownCall?.eventId, isNull);
  });

  test('excludes ambiguous global duplicate IDs from completed history',
      () async {
    final service = _RecordingLeaderboardApiService();
    final container = ProviderContainer(
      overrides: [
        leaderboardApiServiceProvider.overrideWithValue(service),
        participantIdProvider.overrideWith((ref) => 19),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(
      profileCompletedChallengesProvider.future,
    );

    expect(result!.completed.map((c) => c.dto.id), isNot(contains(404)));
  });
}
