import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart'
    show kMockParticipantId;
import 'package:crypto_mobile_app/core/services/challenge_ui_visual_fixture.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';

/// A drop-in [LeaderboardApiService] that serves in-memory, board-shaped
/// challenge fixtures while the Fair Rewards backend is not yet available.
///
/// It returns the exact wire shape the future API will serve — `ChallengeDto`s
/// carrying optional `metric{}`/`source{}` and a `BreakdownResult` carrying
/// `challenge_progress[]` — so the screens, providers, and presentation mapper
/// run identically against the mock and the real backend. Swapped in at the
/// `leaderboardApiServiceProvider` boundary via [AppConfig.useMockChallenges].
///
/// The fixtures reproduce the design board's perceived-time bands
/// (Featured / Today / This week / Season). See `active_challenge_bands`.
class MockChallengesApiService extends LeaderboardApiService {
  MockChallengesApiService();

  static const int _mockSeasonId = 1;
  static const String _seasonName = 'Season 1';

  @override
  Future<List<ChallengeDto>> getChallenges({
    int? seasonId,
    int? eventId,
    int? participantId,
    bool? activeOnly,
    bool? onlyScheduled,
  }) async {
    if (AppConfig.useChallengeUiVisualMatrix) {
      return ChallengeUiVisualFixture.challenges();
    }

    return _challenges();
  }

  @override
  Future<BreakdownResult> getBreakdown({
    required int participantId,
    int? seasonId,
    int? eventId,
  }) async {
    if (AppConfig.useChallengeUiVisualMatrix) {
      return ChallengeUiVisualFixture.breakdown();
    }

    return BreakdownResult(
      scope: 'season',
      displayName: _seasonName,
      totalPoints: 8000,
      offchainPoints: 8000,
      challengeProgress: _progress(),
    );
  }

  @override
  Future<List<SeasonDto>> getSeasons({
    int? seasonId,
    bool? onlyActiveSeasons,
    bool? onlyCurrentSeason,
    bool? onlyActiveEvents,
    bool? onlyCurrentEvents,
  }) async {
    if (AppConfig.useChallengeUiVisualMatrix) {
      return ChallengeUiVisualFixture.seasons();
    }

    return const [
      SeasonDto(
        id: _mockSeasonId,
        name: _seasonName,
        isActive: true,
        events: [],
      ),
    ];
  }

  @override
  Future<RankingResult> getRanking({
    required int participantId,
    int? seasonId,
    int? eventId,
  }) async {
    if (AppConfig.useChallengeUiVisualMatrix) {
      return ChallengeUiVisualFixture.ranking();
    }

    return const RankingResult(
      scope: 'season',
      rank: 44,
      totalPoints: 8000,
      offchainPoints: 8000,
      totalParticipants: 1280,
      seasonId: _mockSeasonId,
      seasonName: _seasonName,
    );
  }

  @override
  Future<LeaderboardResult> getLeaderboard({
    required int seasonId,
    int? eventId,
    int page = 1,
    int perPage = 50,
  }) async {
    if (AppConfig.useChallengeUiVisualMatrix) {
      return ChallengeUiVisualFixture.leaderboard(
        page: page,
        perPage: perPage,
      );
    }

    LeaderboardEntry entry(
      int rank,
      int id,
      String name,
      int points, {
      bool you = false,
    }) {
      return LeaderboardEntry(
        rank: rank,
        participantId: you ? kMockParticipantId : id,
        displayName: name,
        totalPoints: points,
        offchainPoints: points,
        totalProducedBlocks: 0,
        vrfTotalWonSlots: 0,
        successRate: 0,
        eventsParticipated: 1,
      );
    }

    final entries = [
      entry(1, 1001, 'node-alpha', 18420),
      entry(2, 1002, 'blocksmith', 16800),
      entry(3, 1003, 'epoch-runner', 15250),
      entry(44, kMockParticipantId, 'You', 8000, you: true),
      entry(45, 1005, 'testnet-node', 7960),
    ];

    return LeaderboardResult(
      season: const LeaderboardSeason(id: _mockSeasonId, name: _seasonName),
      events: const [],
      entries: entries,
      pagination: PaginationInfo(
        page: page,
        perPage: perPage,
        total: entries.length,
        totalPages: 1,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Fixtures
  // -------------------------------------------------------------------------

  /// ISO-8601 UTC string a fixed [offset] from now (positive = future).
  String _at(Duration offset) =>
      DateTime.now().toUtc().add(offset).toIso8601String();

  ChallengeDto _challenge({
    required int id,
    required String goal,
    required String reward,
    required ChallengeMetric metric,
    required Duration endsIn,
    String? task,
    String? description,
    String? subCategory,
    ChallengeSource? source,
  }) {
    return ChallengeDto(
      id: id,
      category: 'community',
      goal: goal,
      task: task ?? goal,
      reward: reward,
      description: description,
      metric: metric,
      source: source,
      subCategory: subCategory,
      scheduleStart: _at(const Duration(days: -2)),
      scheduleEnd: _at(endsIn),
      enabled: true,
      completed: false,
    );
  }

  // Order matters: the list is in backend display order, and the first active
  // challenge becomes the "Featured" band (#440).
  List<ChallengeDto> _challenges() => [
        _challenge(
          id: 101,
          goal: 'Propose an app change',
          reward: '500',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.binary,
            label: 'Proposal accepted',
            target: 1,
          ),
          endsIn: const Duration(days: 10),
          description:
              'Improve an existing dApp and help test the new application layer.',
          source: const ChallengeSource(
            type: 'external_source',
            label: 'Proposal form',
            url: 'https://example.com/propose',
            resolver: 'human',
          ),
        ),
        _challenge(
          id: 102,
          goal: 'Fill in survey',
          reward: '500',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.binary,
            label: 'Survey submitted',
            target: 1,
          ),
          endsIn: const Duration(hours: 5),
          description:
              'Share feedback that helps shape the next testnet season.',
          source: const ChallengeSource(
            type: 'external_source',
            label: 'Feedback survey',
            url: 'https://tally.so/r/example',
            resolver: 'human',
          ),
        ),
        _challenge(
          id: 103,
          goal: 'Rate the new wallet',
          reward: '500',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.binary,
            label: 'Survey submitted',
            target: 1,
          ),
          endsIn: const Duration(hours: 5),
          description: 'Tell us how the redesigned wallet feels to use.',
        ),
        _challenge(
          id: 104,
          goal: 'Give kudos',
          reward: '1500',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.count,
            label: 'Kudos given',
            target: 5,
          ),
          endsIn: const Duration(days: 4),
          description:
              'Recognize useful contributions from other members this season.',
        ),
        _challenge(
          id: 105,
          goal: 'Review proposals',
          reward: '1500',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.count,
            label: 'Proposals reviewed',
            target: 5,
          ),
          endsIn: const Duration(days: 4),
          description: 'Review and vote on community improvement proposals.',
        ),
        _challenge(
          id: 106,
          goal: 'Top 3 most-voted ideas',
          reward: '0',
          metric: const ChallengeMetric(kind: ChallengeMetricKind.rank),
          endsIn: const Duration(days: 4),
          description: 'Land one of your ideas in the community top 3.',
        ),
        _challenge(
          id: 107,
          goal: 'Produce Every Block',
          reward: '6500',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.percentage,
            label: 'Slot success rate',
          ),
          endsIn: const Duration(days: 128),
          subCategory: 'PRODUCE_BLOCKS_CHALLENGE',
          description:
              'Keep your node online and ready during the season window.',
        ),
        _challenge(
          id: 108,
          goal: 'Use dApps',
          reward: '1000',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.count,
            label: 'dApps used',
            target: 20,
          ),
          endsIn: const Duration(days: 30),
          description: 'Try the apps builders are shipping on the network.',
        ),
      ];

  List<ChallengeProgress> _progress() => const [
        ChallengeProgress(
          challengeId: 101,
          state: ChallengeProgressState.none,
        ),
        ChallengeProgress(
          challengeId: 102,
          state: ChallengeProgressState.none,
        ),
        ChallengeProgress(
          challengeId: 103,
          state: ChallengeProgressState.pending,
          pendingPoints: 500,
          description: 'Submitted',
        ),
        ChallengeProgress(
          challengeId: 104,
          state: ChallengeProgressState.inProgress,
          current: 2,
          target: 5,
          earnedPoints: 400,
        ),
        ChallengeProgress(
          challengeId: 105,
          state: ChallengeProgressState.pending,
          current: 5,
          target: 5,
          pendingPoints: 1500,
        ),
        ChallengeProgress(
          challengeId: 106,
          state: ChallengeProgressState.pending,
          description: 'Joined',
        ),
        ChallengeProgress(
          challengeId: 107,
          state: ChallengeProgressState.inProgress,
          current: 90,
          earnedPoints: 10550,
        ),
        ChallengeProgress(
          challengeId: 108,
          state: ChallengeProgressState.inProgress,
          current: 7,
          target: 20,
          earnedPoints: 350,
        ),
      ];
}
