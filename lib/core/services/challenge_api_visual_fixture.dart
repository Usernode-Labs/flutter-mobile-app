import '../models/leaderboard_api_models.dart';

/// API-shaped challenge fixtures for visual contract checks.
///
/// The raw maps mirror `MobileApiController` response envelopes. Consumers
/// must parse through [ChallengeDto.fromJson] and [BreakdownResult.fromJson]
/// before mapping to UI, so Widgetbook/tests exercise the production contract
/// rather than hand-authored card props.
class ChallengeApiVisualCase {
  const ChallengeApiVisualCase({
    required this.id,
    required this.group,
    required this.title,
    required this.challengesResponse,
    required this.breakdownResponse,
  });

  final String id;
  final String group;
  final String title;
  final Map<String, dynamic> challengesResponse;
  final Map<String, dynamic> breakdownResponse;

  List<ChallengeDto> get challenges =>
      ChallengeApiVisualFixture.parseChallengesResponse(challengesResponse);

  ChallengeDto get challenge => challenges.single;

  BreakdownResult get breakdown =>
      ChallengeApiVisualFixture.parseBreakdownResponse(breakdownResponse);

  ChallengeProgress? get progress => breakdown.progressForChallenge(challenge);
}

class ChallengeApiVisualFixture {
  const ChallengeApiVisualFixture._();

  static const int seasonId = 1;
  static const String seasonName = 'Season 1';
  static const int participantId = 15;
  static const String participantName = 'API Contract User';

  static List<ChallengeApiVisualCase> get cases => List.unmodifiable(_cases);

  static List<ChallengeDto> parseChallengesResponse(
    Map<String, dynamic> response,
  ) {
    final data = response['data'] as List? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ChallengeDto.fromJson)
        .toList(growable: false);
  }

  static BreakdownResult parseBreakdownResponse(
    Map<String, dynamic> response,
  ) {
    final data = response['data'];
    return BreakdownResult.fromJson(data as Map<String, dynamic>);
  }

  static final List<ChallengeApiVisualCase> _cases = [
    _eventCase(
      id: 'presentation-featured',
      group: 'Presentation Flags',
      title: 'Featured from API',
      challenge: _challenge(
        id: 2100,
        eventId: 21,
        eventName: 'Phase 1',
        goal: 'Build and ship your hackathon app',
        task: 'Ship meaningful app changes.',
        reward: 'Up to 25,000 pts',
        metric: _metric(kind: 'count', label: 'PRs', target: 10),
        description: 'Ship meaningful app changes.',
        featured: true,
        featuredOrder: 1,
        displayOrder: 8,
      ),
      progress: _progress(
        challengeId: 2100,
        state: 'in_progress',
        current: 2,
        target: 10,
        pendingPoints: 5000,
        description: '2 accepted app changes',
      ),
    ),
    _eventCase(
      id: 'metric-null-none',
      group: 'Metric Null',
      title: 'No metric, untouched',
      challenge: _challenge(
        id: 2101,
        eventId: 21,
        eventName: 'Phase 1',
        goal: 'Read the onboarding note',
        task: 'Read the note and acknowledge it.',
        reward: '500 pts',
        metric: null,
        description: 'Read the current onboarding note.',
        activities: null,
      ),
      progress: _progress(
        challengeId: 2101,
        state: 'none',
        description: 'Read the current onboarding note.',
      ),
    ),
    _eventCase(
      id: 'metric-null-pending-points',
      group: 'Metric Null',
      title: 'No metric, pending points',
      challenge: _challenge(
        id: 2121,
        eventId: 21,
        eventName: 'Phase 1',
        goal: 'Share form feedback',
        task: 'Submit one useful form response.',
        reward: '500 pts',
        metric: null,
        description: 'Submit one useful form response.',
        ctaLabel: 'Open form',
        ctaLink: 'https://docs.google.com/forms/d/example/viewform',
        mobileCtaLabel: 'Open form',
        mobileCtaLink: 'https://docs.google.com/forms/d/example/viewform',
      ),
      progress: _progress(
        challengeId: 2121,
        state: 'none',
        current: 1,
        pendingPoints: 500,
        description: 'You submitted the feedback form.',
      ),
    ),
    _eventCase(
      id: 'metric-null-earned',
      group: 'Metric Null',
      title: 'No metric, completed',
      challenge: _challenge(
        id: 2151,
        eventId: 21,
        eventName: 'Phase 1',
        goal: 'Attend the kickoff',
        task: 'Attend the kickoff session.',
        reward: '500 pts',
        metric: null,
        description: 'Attend the kickoff session.',
        completed: true,
      ),
      progress: _progress(
        challengeId: 2151,
        state: 'earned',
        earnedPoints: 500,
      ),
    ),
    _eventCase(
      id: 'binary-pending',
      group: 'Binary',
      title: 'Binary pending review',
      challenge: _challenge(
        id: 2102,
        eventId: 21,
        eventName: 'Phase 1',
        goal: 'Submit app feedback',
        task: 'Submit one useful feedback item.',
        reward: '500 pts',
        metric: _metric(kind: 'binary', label: 'Submitted', target: 1),
        description: 'Submit one useful feedback item.',
        activitiesTotal: 0.0,
        activities: const [],
      ),
      progress: _progress(
        challengeId: 2102,
        state: 'pending',
        target: 1,
        pendingPoints: 500,
        description: 'Submitted',
      ),
    ),
    _eventCase(
      id: 'binary-earned',
      group: 'Binary',
      title: 'Binary completed',
      challenge: _challenge(
        id: 2152,
        eventId: 21,
        eventName: 'Phase 1',
        goal: 'Ship one app improvement',
        task: 'Submit one accepted app improvement.',
        reward: '500 pts',
        metric: _metric(kind: 'binary', label: 'Done', target: 1),
        description: 'Submit one accepted app improvement.',
        completed: true,
      ),
      progress: _progress(
        challengeId: 2152,
        state: 'earned',
        target: 1,
        earnedPoints: 500,
      ),
    ),
    _eventCase(
      id: 'count-none-zero',
      group: 'Count',
      title: 'Count untouched',
      challenge: _challenge(
        id: 2103,
        eventId: 21,
        eventName: 'Phase 1',
        goal: 'Complete 3 dApp actions',
        task: 'Perform 3 tracked dApp actions.',
        reward: '300 pts',
        metric: _metric(kind: 'count', label: 'Actions', target: 3),
        description: 'Perform 3 tracked dApp actions.',
      ),
      progress: _progress(
        challengeId: 2103,
        state: 'none',
        target: 3,
        description: 'Perform 3 tracked dApp actions.',
      ),
    ),
    _eventCase(
      id: 'count-in-progress',
      group: 'Count',
      title: 'Count recognized action',
      challenge: _challenge(
        id: 2104,
        eventId: 21,
        eventName: 'Phase 1',
        goal: 'Complete 3 dApp actions',
        task: 'Perform 3 tracked dApp actions.',
        reward: '300 pts',
        metric: _metric(kind: 'count', label: 'Actions', target: 3),
        description: 'Perform 3 tracked dApp actions.',
      ),
      progress: _progress(
        challengeId: 2104,
        state: 'in_progress',
        current: 1,
        target: 3,
        pendingPoints: 100,
        description: '1 recognized Echo dApp action',
      ),
    ),
    _eventCase(
      id: 'count-pending-missing-current',
      group: 'Count',
      title: 'Pending with no metric_current',
      challenge: _challenge(
        id: 2105,
        eventId: 21,
        eventName: 'Phase 1',
        goal: 'Complete 3 dApp actions',
        task: 'Perform 3 tracked dApp actions.',
        reward: '300 pts',
        metric: _metric(kind: 'count', label: 'Actions', target: 3),
        description: 'Perform 3 tracked dApp actions.',
      ),
      progress: _progress(
        challengeId: 2105,
        state: 'pending',
        target: 3,
        pendingPoints: 300,
        description: 'Submitted',
      ),
    ),
    _eventCase(
      id: 'count-over-target',
      group: 'Count',
      title: 'Count over target clamps',
      challenge: _challenge(
        id: 2106,
        eventId: 21,
        eventName: 'Phase 1',
        goal: 'Try five dApps',
        task: 'Try at least 3 dApps.',
        reward: '300 pts',
        metric: _metric(kind: 'count', label: 'Actions', target: 3),
        description: 'Try at least 3 dApps.',
      ),
      progress: _progress(
        challengeId: 2106,
        state: 'earned',
        current: 5,
        target: 3,
        earnedPoints: 300,
        description: '5 recognized dApp actions',
      ),
    ),
    _eventCase(
      id: 'count-label-null',
      group: 'Count',
      title: 'Count without label',
      challenge: _challenge(
        id: 2107,
        eventId: 21,
        eventName: 'Phase 1',
        goal: 'Give kudos',
        task: 'Give kudos to builders.',
        reward: '1,500 pts',
        metric: _metric(kind: 'count', target: 5),
        description: 'Give kudos to builders.',
      ),
      progress: _progress(
        challengeId: 2107,
        state: 'in_progress',
        current: 2,
        target: 5,
        earnedPoints: 400.0,
        description: '2 recognized kudos actions',
      ),
    ),
    _eventCase(
      id: 'count-target-null',
      group: 'Count',
      title: 'Count target null',
      challenge: _challenge(
        id: 2108,
        eventId: 21,
        eventName: 'Phase 1',
        goal: 'Open-ended kudos',
        task: 'Give kudos whenever useful.',
        reward: 'Up to 1,500 pts',
        metric: _metric(kind: 'count', label: 'Kudos', target: null),
        description: 'Give kudos whenever useful.',
      ),
      progress: _progress(
        challengeId: 2108,
        state: 'in_progress',
        current: 2,
        target: null,
        earnedPoints: 400,
        description: '2 recognized kudos actions',
      ),
    ),
    _eventCase(
      id: 'sum-fractional',
      group: 'Sum',
      title: 'Sum fractional current',
      challenge: _challenge(
        id: 2109,
        eventId: 21,
        eventName: 'Phase 1',
        goal: 'Collect dev data',
        task: 'Collect useful developer data.',
        reward: '1,500 pts',
        metric: _metric(kind: 'sum', label: 'Data points', target: 100.0),
        description: 'Collect useful developer data.',
      ),
      progress: _progress(
        challengeId: 2109,
        state: 'in_progress',
        current: 12.5,
        target: 100.0,
        earnedPoints: 187.5,
        description: '12.5 data points accepted',
      ),
    ),
    _eventCase(
      id: 'percentage-in-progress',
      group: 'Percentage',
      title: 'Percentage success',
      challenge: _challenge(
        id: 2110,
        eventId: 21,
        eventName: 'Phase 1',
        goal: 'Maintain node success',
        task: 'Keep success rate healthy.',
        reward: '2,500 pts',
        metric: _metric(kind: 'percentage', label: 'Success rate'),
        description: 'Keep success rate healthy.',
      ),
      progress: _progress(
        challengeId: 2110,
        state: 'in_progress',
        current: 62.5,
        earnedPoints: 1200,
        description: '62.5% success',
      ),
    ),
    _eventCase(
      id: 'rank-in-progress',
      group: 'Rank',
      title: 'Rank with reasoning text',
      challenge: _challenge(
        id: 2111,
        eventId: 21,
        eventName: 'Phase 1',
        goal: 'Reach top 10',
        task: 'Reach top 10 in the phase ranking.',
        reward: '3,000 pts',
        metric: _metric(kind: 'rank', label: 'Rank'),
        description: 'Reach top 10 in the phase ranking.',
      ),
      progress: _progress(
        challengeId: 2111,
        state: 'in_progress',
        earnedPoints: 1000,
        description: 'Rank 7',
      ),
    ),
    _eventCase(
      id: 'unknown-kind',
      group: 'Unknown Metric',
      title: 'Unknown metric kind',
      challenge: _challenge(
        id: 2112,
        eventId: 21,
        eventName: 'Phase 1',
        goal: 'Maintain a streak',
        task: 'Maintain a contribution streak.',
        reward: '700 pts',
        metric: _metric(kind: 'streak', label: 'Days', target: 7),
        description: 'Maintain a contribution streak.',
      ),
      progress: _progress(
        challengeId: 2112,
        state: 'in_progress',
        current: 3,
        target: 7,
        earnedPoints: 300,
        description: '3-day streak',
      ),
    ),
    _seasonCase(
      id: 'season-nested-progress',
      group: 'Scope Resolution',
      title: 'Season nested progress',
      challenge: _challenge(
        id: 2113,
        eventId: 22,
        eventName: 'Phase 2',
        goal: 'Season nested count',
        task: 'Progress comes from events[].challenge_progress.',
        reward: '900 pts',
        metric: _metric(kind: 'count', label: 'Actions', target: 9),
        description: 'Progress comes from events[].challenge_progress.',
      ),
      events: [
        _eventData(
          eventId: 22,
          eventName: 'Phase 2',
          progress: [
            _progress(
              challengeId: 2113,
              state: 'in_progress',
              current: 4,
              target: 9,
              earnedPoints: 400,
              description: '4 recognized actions',
            ),
          ],
        ),
      ],
    ),
    _seasonCase(
      id: 'season-sparse-missing-progress',
      group: 'Scope Resolution',
      title: 'Season sparse missing event',
      challenge: _challenge(
        id: 2114,
        eventId: 23,
        eventName: 'Untouched Phase',
        goal: 'Untouched phase challenge',
        task: 'Season breakdown omits untouched event progress.',
        reward: '300 pts',
        metric: _metric(kind: 'count', label: 'Actions', target: 3),
        description: 'Season breakdown omits untouched event progress.',
      ),
      events: [
        _eventData(
          eventId: 22,
          eventName: 'Phase 2',
          progress: [
            _progress(
              challengeId: 9999,
              state: 'earned',
              earnedPoints: 100,
              description: 'Other event only',
            ),
          ],
        ),
      ],
    ),
    _seasonCase(
      id: 'duplicate-event-id-wins',
      group: 'Scope Resolution',
      title: 'Duplicate challenge id resolves by event',
      challenge: _challenge(
        id: 2115,
        eventId: 24,
        eventName: 'Target Phase',
        goal: 'Duplicate id event match',
        task: 'Use event_id to choose the correct progress.',
        reward: '500 pts',
        metric: _metric(kind: 'count', label: 'Actions', target: 5),
        description: 'Use event_id to choose the correct progress.',
      ),
      events: [
        _eventData(
          eventId: 23,
          eventName: 'Other Phase',
          progress: [
            _progress(
              challengeId: 2115,
              state: 'earned',
              current: 5,
              target: 5,
              earnedPoints: 500,
              description: 'Wrong phase complete',
            ),
          ],
        ),
        _eventData(
          eventId: 24,
          eventName: 'Target Phase',
          progress: [
            _progress(
              challengeId: 2115,
              state: 'in_progress',
              current: 1,
              target: 5,
              earnedPoints: 100,
              description: 'Correct phase progress',
            ),
          ],
        ),
      ],
    ),
    _seasonCase(
      id: 'event-null-unambiguous',
      group: 'Scope Resolution',
      title: 'Missing event_id unambiguous fallback',
      challenge: _challenge(
        id: 2116,
        eventId: null,
        eventName: null,
        goal: 'Legacy missing event id',
        task: 'Fallback succeeds when one progress match exists.',
        reward: '500 pts',
        metric: _metric(kind: 'count', label: 'Actions', target: 5),
        description: 'Fallback succeeds when one progress match exists.',
      ),
      events: [
        _eventData(
          eventId: 25,
          eventName: 'Only Phase',
          progress: [
            _progress(
              challengeId: 2116,
              state: 'in_progress',
              current: 2,
              target: 5,
              earnedPoints: 200,
              description: 'Only matching progress',
            ),
          ],
        ),
      ],
    ),
    _seasonCase(
      id: 'event-null-ambiguous',
      group: 'Scope Resolution',
      title: 'Missing event_id ambiguous fallback',
      challenge: _challenge(
        id: 2117,
        eventId: null,
        eventName: null,
        goal: 'Ambiguous missing event id',
        task: 'Fallback returns no progress when matches collide.',
        reward: '500 pts',
        metric: _metric(kind: 'count', label: 'Actions', target: 5),
        description: 'Fallback returns no progress when matches collide.',
      ),
      events: [
        _eventData(
          eventId: 26,
          eventName: 'Phase A',
          progress: [
            _progress(
              challengeId: 2117,
              state: 'in_progress',
              current: 1,
              target: 5,
              earnedPoints: 100,
              description: 'Phase A progress',
            ),
          ],
        ),
        _eventData(
          eventId: 27,
          eventName: 'Phase B',
          progress: [
            _progress(
              challengeId: 2117,
              state: 'earned',
              current: 5,
              target: 5,
              earnedPoints: 500,
              description: 'Phase B progress',
            ),
          ],
        ),
      ],
    ),
    _globalCase(
      id: 'global-nested-progress',
      group: 'Scope Resolution',
      title: 'Global nested progress',
      challenge: _challenge(
        id: 2118,
        eventId: 28,
        eventName: 'Global Phase',
        goal: 'Global nested challenge',
        task: 'Progress comes from seasons[].events[].challenge_progress.',
        reward: '800 pts',
        metric: _metric(kind: 'sum', label: 'Points', target: 80),
        description: 'Progress comes from global nested events.',
      ),
      seasons: [
        _seasonData(
          seasonId: seasonId,
          seasonName: seasonName,
          events: [
            _eventData(
              eventId: 28,
              eventName: 'Global Phase',
              progress: [
                _progress(
                  challengeId: 2118,
                  state: 'in_progress',
                  current: 40,
                  target: 80,
                  earnedPoints: 400,
                  description: '40 points accepted',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

  static ChallengeApiVisualCase _eventCase({
    required String id,
    required String group,
    required String title,
    required Map<String, dynamic> challenge,
    required Map<String, dynamic> progress,
  }) {
    return ChallengeApiVisualCase(
      id: id,
      group: group,
      title: title,
      challengesResponse: _challengesResponse(challenge),
      breakdownResponse: _breakdownResponse(
        _eventBreakdownData(
          eventId: challenge['event_id'] as int? ?? 21,
          eventName: challenge['event_name'] as String? ?? 'Phase',
          progress: [progress],
        ),
      ),
    );
  }

  static ChallengeApiVisualCase _seasonCase({
    required String id,
    required String group,
    required String title,
    required Map<String, dynamic> challenge,
    required List<Map<String, dynamic>> events,
  }) {
    return ChallengeApiVisualCase(
      id: id,
      group: group,
      title: title,
      challengesResponse: _challengesResponse(challenge),
      breakdownResponse: _breakdownResponse(
        _seasonBreakdownData(events: events),
      ),
    );
  }

  static ChallengeApiVisualCase _globalCase({
    required String id,
    required String group,
    required String title,
    required Map<String, dynamic> challenge,
    required List<Map<String, dynamic>> seasons,
  }) {
    return ChallengeApiVisualCase(
      id: id,
      group: group,
      title: title,
      challengesResponse: _challengesResponse(challenge),
      breakdownResponse: _breakdownResponse(
        {
          'display_name': participantName,
          'scope': 'global',
          'total_points': 1234.0,
          'offchain_points': 200.0,
          'seasons': seasons,
        },
      ),
    );
  }

  static Map<String, dynamic> _challengesResponse(
    Map<String, dynamic> challenge,
  ) =>
      {
        'success': true,
        'data': [challenge],
      };

  static Map<String, dynamic> _breakdownResponse(Map<String, dynamic> data) => {
        'success': true,
        'data': data,
      };

  static Map<String, dynamic> _eventBreakdownData({
    required int eventId,
    required String eventName,
    required List<Map<String, dynamic>> progress,
  }) =>
      {
        'display_name': participantName,
        'scope': 'event',
        'event': {'id': eventId, 'name': eventName},
        'total_points': _sumEarned(progress),
        'offchain_points': _sumEarned(progress),
        'rank': null,
        'first_block_points': 0,
        'top_3_points': 0,
        'success_50_percent_points': 0,
        'produced_blocks': 0,
        'vrf_won_slots': 0,
        'success_rate': null,
        'challenge_progress': progress,
        'activities': const [],
      };

  static Map<String, dynamic> _seasonBreakdownData({
    required List<Map<String, dynamic>> events,
  }) =>
      {
        'display_name': participantName,
        'scope': 'season',
        'season': {'id': seasonId, 'name': seasonName},
        'total_points': 1234.0,
        'offchain_points': 200.0,
        'events': events,
      };

  static Map<String, dynamic> _seasonData({
    required int seasonId,
    required String seasonName,
    required List<Map<String, dynamic>> events,
  }) =>
      {
        'season_id': seasonId,
        'season_name': seasonName,
        'total_points': 1234.0,
        'offchain_points': 200.0,
        'events': events,
      };

  static Map<String, dynamic> _eventData({
    required int eventId,
    required String eventName,
    required List<Map<String, dynamic>> progress,
  }) =>
      {
        'event_id': eventId,
        'event_name': eventName,
        'total_points': _sumEarned(progress),
        'offchain_points': _sumEarned(progress),
        'rank': 5,
        'first_block_points': 0,
        'top_3_points': 0,
        'success_50_percent_points': 0,
        'produced_blocks': 0,
        'vrf_won_slots': 0,
        'success_rate': null,
        'challenge_progress': progress,
        'activities': const [],
      };

  static Map<String, dynamic> _challenge({
    required int id,
    required int? eventId,
    required String? eventName,
    String eventType = 'phase',
    String category = 'COMMUNITY',
    String? subCategory = 'ACTIVITY_CHALLENGE',
    required String goal,
    required String task,
    required String reward,
    required Map<String, dynamic>? metric,
    required String description,
    String requirements = 'Complete the task during the active schedule.',
    String rewardLogic = 'Points are awarded after verification.',
    String ctaType = 'url',
    String ctaLabel = 'Get Started',
    String ctaLink = 'https://example.com',
    String mobileCtaType = 'app',
    String mobileCtaLabel = 'Open',
    String mobileCtaLink = '/dapps',
    String? scheduleStart = '2026-06-01T00:00:00+00:00',
    String? scheduleEnd = '2099-01-01T00:00:00+00:00',
    bool enabled = true,
    bool completed = false,
    int displayOrder = 0,
    bool featured = false,
    int? featuredOrder,
    List<Map<String, dynamic>>? activities,
    num? activitiesTotal,
  }) =>
      {
        'id': id,
        if (eventId != null) 'event_id': eventId,
        if (eventName != null) 'event_name': eventName,
        'event_type': eventType,
        'category': category,
        'sub_category': subCategory,
        'goal': goal,
        'task': task,
        'reward': reward,
        'metric': metric,
        'description': description,
        'requirements': requirements,
        'reward_logic': rewardLogic,
        'cta_type': ctaType,
        'cta_label': ctaLabel,
        'cta_link': ctaLink,
        'mobile_cta_type': mobileCtaType,
        'mobile_cta_label': mobileCtaLabel,
        'mobile_cta_link': mobileCtaLink,
        'schedule_start': scheduleStart,
        'schedule_end': scheduleEnd,
        'enabled': enabled,
        'completed': completed,
        'display_order': displayOrder,
        'featured': featured,
        'featured_order': featuredOrder,
        if (activities != null) 'activities': activities,
        if (activitiesTotal != null) 'activities_total': activitiesTotal,
      };

  static Map<String, dynamic> _metric({
    required String kind,
    String? label,
    num? target,
  }) =>
      {
        'kind': kind,
        'label': label,
        'target': target,
      };

  static Map<String, dynamic> _progress({
    required int challengeId,
    required String state,
    num? current,
    num? target,
    num pendingPoints = 0,
    num earnedPoints = 0,
    String? description,
  }) =>
      {
        'challenge_id': challengeId,
        'state': state,
        'current': current,
        'target': target,
        'pending_points': pendingPoints,
        'earned_points': earnedPoints,
        'description': description,
      };

  static num _sumEarned(List<Map<String, dynamic>> progress) {
    return progress.fold<num>(
      0,
      (sum, item) => sum + ((item['earned_points'] as num?) ?? 0),
    );
  }
}
