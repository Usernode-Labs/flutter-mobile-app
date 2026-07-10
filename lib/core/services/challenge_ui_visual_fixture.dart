import '../models/leaderboard_api_models.dart';

enum ChallengeVisualMetricType {
  binary,
  count,
  sum,
  percentage,
  rank,
  technicalOngoing,
}

enum ChallengeVisualUiPhase {
  open,
  inProgress,
  pending,
  completed,
}

class ChallengeVisualMatrixCase {
  const ChallengeVisualMatrixCase({
    required this.metricType,
    required this.phase,
    required this.challenge,
    required this.progress,
  });

  final ChallengeVisualMetricType metricType;
  final ChallengeVisualUiPhase phase;
  final ChallengeDto challenge;
  final ChallengeProgress progress;
}

class ChallengeUiVisualFixture {
  const ChallengeUiVisualFixture._();

  static const int seasonId = 1;
  static const int eventId = 1;
  static const String seasonName = 'Challenge UI Visual Matrix';
  static const String eventName = 'Phase 1';
  static const String participantName = 'Visual Matrix User';
  static const int participantId = 1;

  static List<ChallengeVisualMatrixCase> get activeCases => _cases
      .where((item) => item.phase != ChallengeVisualUiPhase.completed)
      .toList(growable: false);

  static List<ChallengeVisualMatrixCase> get completedCases => _cases
      .where((item) => item.phase == ChallengeVisualUiPhase.completed)
      .toList(growable: false);

  static List<ChallengeVisualMatrixCase> get allCases =>
      List.unmodifiable(_cases);

  static List<ChallengeDto> challenges() =>
      _cases.map((item) => item.challenge).toList(growable: false);

  static List<SeasonDto> seasons() => const [
        SeasonDto(
          id: seasonId,
          name: seasonName,
          isActive: true,
        ),
      ];

  static BreakdownResult breakdown() => BreakdownResult(
        scope: 'season',
        displayName: participantName,
        totalPoints: _totalEarnedPoints,
        offchainPoints: _totalEarnedPoints,
        seasonBreakdown: SeasonBreakdown(
          seasonId: seasonId,
          seasonName: seasonName,
          totalPoints: _totalEarnedPoints,
          offchainPoints: _totalEarnedPoints,
          events: [
            EventBreakdown(
              eventId: eventId,
              eventName: eventName,
              totalPoints: _totalEarnedPoints,
              offchainPoints: _totalEarnedPoints,
              challengeProgress:
                  _cases.map((item) => item.progress).toList(growable: false),
            ),
          ],
        ),
      );

  static RankingResult ranking() => RankingResult(
        scope: 'season',
        rank: 12,
        totalPoints: _totalEarnedPoints,
        offchainPoints: _totalEarnedPoints,
        totalParticipants: 1280,
        seasonId: seasonId,
        seasonName: seasonName,
      );

  static LeaderboardResult leaderboard({
    int page = 1,
    int perPage = 50,
  }) =>
      LeaderboardResult(
        season: const LeaderboardSeason(id: seasonId, name: seasonName),
        events: const [],
        entries: [
          LeaderboardEntry(
            rank: 10,
            participantId: 910,
            displayName: 'State Runner',
            totalPoints: _totalEarnedPoints + 2000,
            offchainPoints: _totalEarnedPoints + 2000,
            totalProducedBlocks: 0,
            vrfTotalWonSlots: 0,
            successRate: 0,
            eventsParticipated: 1,
          ),
          LeaderboardEntry(
            rank: 11,
            participantId: 911,
            displayName: 'Phase Mapper',
            totalPoints: _totalEarnedPoints + 1000,
            offchainPoints: _totalEarnedPoints + 1000,
            totalProducedBlocks: 0,
            vrfTotalWonSlots: 0,
            successRate: 0,
            eventsParticipated: 1,
          ),
          LeaderboardEntry(
            rank: 12,
            participantId: participantId,
            displayName: participantName,
            totalPoints: _totalEarnedPoints,
            offchainPoints: _totalEarnedPoints,
            totalProducedBlocks: 0,
            vrfTotalWonSlots: 0,
            successRate: 0,
            eventsParticipated: 1,
          ),
          LeaderboardEntry(
            rank: 13,
            participantId: 913,
            displayName: 'Progress Checker',
            totalPoints: _totalEarnedPoints - 1000,
            offchainPoints: _totalEarnedPoints - 1000,
            totalProducedBlocks: 0,
            vrfTotalWonSlots: 0,
            successRate: 0,
            eventsParticipated: 1,
          ),
        ],
        pagination: PaginationInfo(
          page: page,
          perPage: perPage,
          total: 4,
          totalPages: 1,
        ),
      );

  static final int _totalEarnedPoints = _cases.fold<int>(
    0,
    (sum, item) => sum + item.progress.earnedPoints,
  );

  static final List<ChallengeVisualMatrixCase> _cases = [
    for (final phase in ChallengeVisualUiPhase.values) ..._phaseCases(phase),
  ];

  static List<ChallengeVisualMatrixCase> _phaseCases(
    ChallengeVisualUiPhase phase,
  ) {
    final suffix = _phaseTitle(phase);
    final index = phase.index + 1;

    return [
      _case(
        metricType: ChallengeVisualMetricType.binary,
        phase: phase,
        id: 1100 + index,
        goal: 'Survey - $suffix',
        description: 'Answer one product question',
        reward: '500',
        metric: const ChallengeMetric(
          kind: ChallengeMetricKind.binary,
          target: 1,
        ),
        progress: _binaryProgress(1100 + index, phase),
      ),
      _case(
        metricType: ChallengeVisualMetricType.count,
        phase: phase,
        id: 1200 + index,
        goal: 'Kudos - $suffix',
        description: 'Send kudos to builders',
        reward: '1500',
        metric: const ChallengeMetric(
          kind: ChallengeMetricKind.count,
          label: 'Kudos sent',
          target: 5,
        ),
        progress: _countProgress(1200 + index, phase),
      ),
      _case(
        metricType: ChallengeVisualMetricType.sum,
        phase: phase,
        id: 1300 + index,
        goal: 'Points - $suffix',
        description: 'Earn app activity points',
        reward: '2000',
        metric: const ChallengeMetric(
          kind: ChallengeMetricKind.sum,
          label: 'Activity points',
          target: 100,
        ),
        progress: _sumProgress(1300 + index, phase),
      ),
      _case(
        metricType: ChallengeVisualMetricType.percentage,
        phase: phase,
        id: 1400 + index,
        goal: 'Success Rate - $suffix',
        description: 'Keep the node success rate healthy',
        reward: '2500',
        metric: const ChallengeMetric(
          kind: ChallengeMetricKind.percentage,
          label: 'Success rate',
        ),
        progress: _percentageProgress(1400 + index, phase),
      ),
      _case(
        metricType: ChallengeVisualMetricType.rank,
        phase: phase,
        id: 1500 + index,
        goal: 'Rank - $suffix',
        description: 'Reach a visible leaderboard rank',
        reward: '3000',
        metric: const ChallengeMetric(kind: ChallengeMetricKind.rank),
        progress: _rankProgress(1500 + index, phase),
      ),
      _case(
        metricType: ChallengeVisualMetricType.technicalOngoing,
        phase: phase,
        id: 1600 + index,
        goal: 'Produce Blocks - $suffix',
        description: 'Keep producing expected node blocks',
        reward: '6500',
        subCategory: 'PRODUCE_BLOCKS_CHALLENGE',
        metric: const ChallengeMetric(
          kind: ChallengeMetricKind.percentage,
          label: 'Slot success rate',
        ),
        progress: _technicalProgress(1600 + index, phase),
      ),
    ];
  }

  static ChallengeVisualMatrixCase _case({
    required ChallengeVisualMetricType metricType,
    required ChallengeVisualUiPhase phase,
    required int id,
    required String goal,
    required String description,
    required String reward,
    required ChallengeMetric metric,
    required ChallengeProgress progress,
    String subCategory = 'ACTIVITY_CHALLENGE',
  }) {
    final completed = phase == ChallengeVisualUiPhase.completed;

    return ChallengeVisualMatrixCase(
      metricType: metricType,
      phase: phase,
      challenge: ChallengeDto(
        id: id,
        eventId: eventId,
        eventName: eventName,
        goal: goal,
        task: goal,
        description: description,
        reward: reward,
        category: 'community',
        subCategory: subCategory,
        source: const ChallengeSource(type: 'fixture'),
        metric: metric,
        scheduleStart: '2026-06-01T00:00:00Z',
        scheduleEnd: '2099-01-01T00:00:00Z',
        enabled: true,
        completed: completed,
        activitiesTotal: completed ? progress.earnedPoints : 0,
      ),
      progress: progress,
    );
  }

  static ChallengeProgress _binaryProgress(
    int challengeId,
    ChallengeVisualUiPhase phase,
  ) =>
      switch (phase) {
        ChallengeVisualUiPhase.open => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.none,
          ),
        ChallengeVisualUiPhase.inProgress => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.inProgress,
            description: 'Started',
          ),
        ChallengeVisualUiPhase.pending => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.pending,
            pendingPoints: 500,
            description: 'Submitted',
          ),
        ChallengeVisualUiPhase.completed => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.earned,
            earnedPoints: 500,
          ),
      };

  static ChallengeProgress _countProgress(
    int challengeId,
    ChallengeVisualUiPhase phase,
  ) =>
      switch (phase) {
        ChallengeVisualUiPhase.open => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.none,
          ),
        ChallengeVisualUiPhase.inProgress => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.inProgress,
            current: 2,
            target: 5,
            earnedPoints: 400,
          ),
        ChallengeVisualUiPhase.pending => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.pending,
            current: 5,
            target: 5,
            pendingPoints: 1500,
          ),
        ChallengeVisualUiPhase.completed => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.earned,
            current: 5,
            target: 5,
            earnedPoints: 1500,
          ),
      };

  static ChallengeProgress _sumProgress(
    int challengeId,
    ChallengeVisualUiPhase phase,
  ) =>
      switch (phase) {
        ChallengeVisualUiPhase.open => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.none,
          ),
        ChallengeVisualUiPhase.inProgress => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.inProgress,
            current: 40,
            target: 100,
            earnedPoints: 800,
          ),
        ChallengeVisualUiPhase.pending => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.pending,
            current: 100,
            target: 100,
            pendingPoints: 2000,
          ),
        ChallengeVisualUiPhase.completed => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.earned,
            current: 100,
            target: 100,
            earnedPoints: 2000,
          ),
      };

  static ChallengeProgress _percentageProgress(
    int challengeId,
    ChallengeVisualUiPhase phase,
  ) =>
      switch (phase) {
        ChallengeVisualUiPhase.open => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.none,
          ),
        ChallengeVisualUiPhase.inProgress => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.inProgress,
            current: 62,
            earnedPoints: 1200,
          ),
        ChallengeVisualUiPhase.pending => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.pending,
            current: 100,
            pendingPoints: 2500,
          ),
        ChallengeVisualUiPhase.completed => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.earned,
            current: 100,
            earnedPoints: 2500,
          ),
      };

  static ChallengeProgress _rankProgress(
    int challengeId,
    ChallengeVisualUiPhase phase,
  ) =>
      switch (phase) {
        ChallengeVisualUiPhase.open => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.none,
          ),
        ChallengeVisualUiPhase.inProgress => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.inProgress,
            description: 'Rank 7',
            earnedPoints: 1000,
          ),
        ChallengeVisualUiPhase.pending => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.pending,
            description: 'Rank submitted',
          ),
        ChallengeVisualUiPhase.completed => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.earned,
            description: 'Rank 3',
            earnedPoints: 3000,
          ),
      };

  static ChallengeProgress _technicalProgress(
    int challengeId,
    ChallengeVisualUiPhase phase,
  ) =>
      switch (phase) {
        ChallengeVisualUiPhase.open => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.none,
          ),
        ChallengeVisualUiPhase.inProgress => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.inProgress,
            current: 90,
            earnedPoints: 4050,
          ),
        ChallengeVisualUiPhase.pending => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.pending,
            current: 100,
            earnedPoints: 6500,
          ),
        ChallengeVisualUiPhase.completed => ChallengeProgress(
            challengeId: challengeId,
            state: ChallengeProgressState.earned,
            current: 98,
            earnedPoints: 6500,
          ),
      };

  static String _phaseTitle(ChallengeVisualUiPhase phase) => switch (phase) {
        ChallengeVisualUiPhase.open => 'Open',
        ChallengeVisualUiPhase.inProgress => 'In Progress',
        ChallengeVisualUiPhase.pending => 'Pending',
        ChallengeVisualUiPhase.completed => 'Completed',
      };
}
