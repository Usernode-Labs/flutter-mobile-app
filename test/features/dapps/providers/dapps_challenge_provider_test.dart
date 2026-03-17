import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/utils/leaderboard_cache.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/dapps/providers/dapps_challenge_provider.dart';

ChallengeDto _makeDto({
  int id = 1,
  bool enabled = true,
  bool completed = false,
  String? subCategory,
}) {
  return ChallengeDto(
    id: id,
    category: 'technical',
    goal: 'Goal',
    task: 'Task',
    reward: '1000',
    enabled: enabled,
    completed: completed,
    subCategory: subCategory,
  );
}

ProviderContainer _container({
  AsyncValue<CachedData<List<ChallengeDto>>?> challengesState =
      const AsyncData(null),
}) {
  return ProviderContainer(
    overrides: [
      challengesProvider.overrideWith(() {
        final controller = _StubChallengesController(challengesState);
        return controller;
      }),
    ],
  );
}

class _StubChallengesController
    extends AsyncNotifier<CachedData<List<ChallengeDto>>?>
    implements ChallengesController {
  _StubChallengesController(this._state);

  final AsyncValue<CachedData<List<ChallengeDto>>?> _state;

  @override
  Future<CachedData<List<ChallengeDto>>?> build() async {
    state = _state;
    return _state.value;
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> silentRefresh() async {}
}

void main() {
  group('dappsLiveProvider', () {
    test('returns false when challenges are null', () {
      final container = _container();
      addTearDown(container.dispose);

      expect(container.read(dappsLiveProvider), isFalse);
    });

    test('returns false when no matching challenge', () {
      final container = _container(
        challengesState: AsyncData(CachedData(
          data: [_makeDto(subCategory: 'OTHER')],
          isCached: false,
        )),
      );
      addTearDown(container.dispose);

      expect(container.read(dappsLiveProvider), isFalse);
    });

    test('returns false when matching challenge is disabled', () {
      final container = _container(
        challengesState: AsyncData(CachedData(
          data: [_makeDto(subCategory: kDappsSubCategory, enabled: false)],
          isCached: false,
        )),
      );
      addTearDown(container.dispose);

      expect(container.read(dappsLiveProvider), isFalse);
    });

    test('returns true when matching challenge is enabled', () {
      final container = _container(
        challengesState: AsyncData(CachedData(
          data: [_makeDto(subCategory: kDappsSubCategory, enabled: true)],
          isCached: false,
        )),
      );
      addTearDown(container.dispose);

      expect(container.read(dappsLiveProvider), isTrue);
    });
  });
}
