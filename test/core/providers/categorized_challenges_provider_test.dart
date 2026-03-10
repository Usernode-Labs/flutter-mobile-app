import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/categorized_challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/utils/leaderboard_cache.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';

// ---------------------------------------------------------------------------
// Mock controllers
// ---------------------------------------------------------------------------

class _MockChallengesController extends ChallengesController {
  _MockChallengesController(this._data);
  final CachedData<List<ChallengeDto>>? _data;

  @override
  Future<CachedData<List<ChallengeDto>>?> build() async => _data;

  @override
  Future<void> silentRefresh() async {}

  @override
  Future<void> refresh() async {}
}

class _MockBreakdownController extends BreakdownController {
  _MockBreakdownController(this._data);
  final CachedData<BreakdownResult>? _data;

  @override
  Future<CachedData<BreakdownResult>?> build() async => _data;

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
        id: 100,
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
          challengesProvider
              .overrideWith(() => _MockChallengesController(null)),
          breakdownProvider.overrideWith(() => _MockBreakdownController(null)),
          zkIdentityIsCompleteProvider
              .overrideWithValue(const AsyncValue.data(false)),
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
          challengesProvider.overrideWith(() => _MockChallengesController(
                const CachedData(data: _challenges, isCached: false),
              )),
          breakdownProvider.overrideWith(() => _MockBreakdownController(null)),
          zkIdentityIsCompleteProvider
              .overrideWithValue(const AsyncValue.data(false)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(challengesProvider.future);
      await container.read(breakdownProvider.future);

      final result = container.read(categorizedChallengesProvider);
      expect(result, isNotNull);
      // Without breakdown, categorization falls back to dto.completed/enabled:
      // id=1 active, id=2 completed (dto.completed=true but no activity match
      // so enriched.participantCompleted is false → it's enabled → active).
      // Actually: without breakdown, activity is null for all, so
      // participantCompleted is false for all. Categorization:
      //   id=1: enabled=true, participantCompleted=false → active
      //   id=2: enabled=true, participantCompleted=false → active (no activity match!)
      //   id=3: enabled=false, participantCompleted=false → missed
      expect(result!.active.length, 3); // 2 API + 1 synthetic ZK Identity
      expect(result.completed.length, 0);
      expect(result.missed.length, 1);
    });

    test('categorizes with breakdown (enriched)', () async {
      final container = ProviderContainer(
        overrides: [
          challengesProvider.overrideWith(() => _MockChallengesController(
                const CachedData(data: _challenges, isCached: false),
              )),
          breakdownProvider.overrideWith(() => _MockBreakdownController(
                const CachedData(data: _breakdown, isCached: false),
              )),
          zkIdentityIsCompleteProvider
              .overrideWithValue(const AsyncValue.data(false)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(challengesProvider.future);
      await container.read(breakdownProvider.future);

      final result = container.read(categorizedChallengesProvider);
      expect(result, isNotNull);
      // With breakdown: "Prove Humanity" matches activity description →
      // participantCompleted=true → completed.
      //   id=1: active (no activity match, enabled)
      //   id=2: completed (activity match)
      //   id=3: missed (not enabled, no activity)
      expect(result!.active.length, 2); // 1 API + 1 synthetic ZK Identity
      // ZK Identity challenge is prepended; API challenge follows.
      expect(result.active[1].dto.goal, 'Produce Every Block');
      expect(result.completed.length, 1);
      expect(result.completed.first.dto.goal, 'Prove Humanity');
      expect(result.completed.first.earnedPoints, 1000);
      expect(result.missed.length, 1);
      expect(result.missed.first.dto.goal, 'Quick Challenge');
    });
  });
}
