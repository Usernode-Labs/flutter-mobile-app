import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/categorized_challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';

// ---------------------------------------------------------------------------
// Mock controllers
// ---------------------------------------------------------------------------

class _MockChallengesController extends ChallengesController {
  _MockChallengesController(this._data);
  final List<ChallengeDto>? _data;

  @override
  Future<List<ChallengeDto>?> build() async => _data;

  @override
  Future<void> silentRefresh() async {}

  @override
  Future<void> refresh() async {}
}

class _MockBreakdownController extends BreakdownController {
  _MockBreakdownController(this._data);
  final BreakdownResult? _data;

  @override
  Future<BreakdownResult?> build() async => _data;

  @override
  Future<void> silentRefresh() async {}

  @override
  Future<void> refresh() async {}
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const _challenges = [
  ChallengeDto(
    id: 1,
    category: 'technical',
    goal: 'Produce Every Block',
    task: 'Produce blocks.',
    reward: '8000',
    enabled: true,
    completed: false,
  ),
  ChallengeDto(
    id: 2,
    category: 'community',
    goal: 'Prove Humanity',
    task: 'Verify.',
    reward: '1000',
    enabled: true,
    completed: true,
  ),
  ChallengeDto(
    id: 3,
    category: 'flash',
    goal: 'Quick Challenge',
    task: 'Missed.',
    reward: '500',
    enabled: false,
    completed: false,
  ),
];

const _breakdown = BreakdownResult(
  scope: 'event',
  displayName: 'Test',
  totalPoints: 1000,
  offchainPoints: 0,
  eventBreakdown: EventBreakdown(
    eventId: 1,
    eventName: 'E1',
    totalPoints: 1000,
    offchainPoints: 0,
    activities: [
      BreakdownActivity(
        id: '100',
        activityType: 'COMMUNITY',
        points: 1000,
        description: 'Prove Humanity',
      ),
    ],
  ),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('categorizedChallengesProvider', () {
    test('returns null when challenges are not loaded', () async {
      final container = ProviderContainer(
        overrides: [
          challengesProvider.overrideWith(
            () => _MockChallengesController(null),
          ),
          breakdownProvider.overrideWith(() => _MockBreakdownController(null)),
        ],
      );
      addTearDown(container.dispose);

      // Wait for async providers to settle.
      await container.read(challengesProvider.future);

      final result = container.read(categorizedChallengesProvider);
      expect(result, isNull);
    });

    test('categorizes without breakdown (v1 fallback)', () async {
      final container = ProviderContainer(
        overrides: [
          challengesProvider.overrideWith(
            () => _MockChallengesController(_challenges),
          ),
          breakdownProvider.overrideWith(() => _MockBreakdownController(null)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(challengesProvider.future);
      await container.read(breakdownProvider.future);

      final result = container.read(categorizedChallengesProvider);
      expect(result, isNotNull);
      // id=3 (enabled=false, not over, no points) is hidden before enrichment.
      // A challenge is "over" when completed OR past its end date; over splits
      // by points won. Without breakdown nobody won points, so:
      //   id=1: enabled, not over → active
      //   id=2: completed=true but 0 points won → missed
      expect(result!.active.length, 1);
      expect(result.active.first.dto.goal, 'Produce Every Block');
      expect(result.completed.length, 0);
      expect(result.missed.length, 1);
      expect(result.missed.first.dto.goal, 'Prove Humanity');
    });

    test('categorizes with breakdown (enriched)', () async {
      final container = ProviderContainer(
        overrides: [
          challengesProvider.overrideWith(
            () => _MockChallengesController(_challenges),
          ),
          breakdownProvider.overrideWith(
            () => _MockBreakdownController(_breakdown),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(challengesProvider.future);
      await container.read(breakdownProvider.future);

      final result = container.read(categorizedChallengesProvider);
      expect(result, isNotNull);
      // id=3 (enabled=false) is filtered out before enrichment.
      // With breakdown: "Prove Humanity" matches activity description →
      // participantCompleted=true → completed.
      //   id=1: active (no activity match, enabled)
      //   id=2: completed (activity match)
      expect(result!.active.length, 1);
      expect(result.active.first.dto.goal, 'Produce Every Block');
      expect(result.completed.length, 1);
      expect(result.completed.first.dto.goal, 'Prove Humanity');
      expect(result.completed.first.earnedPoints, 1000);
      expect(result.missed.length, 0);
    });
  });
}
