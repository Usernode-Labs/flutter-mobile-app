import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/features/profile/providers/token_allocation_provider.dart';

class _MockRankingController extends RankingController {
  _MockRankingController(this._ranking);

  final RankingResult _ranking;

  @override
  Future<RankingResult?> build() async => _ranking;
}

ProviderContainer _container({
  int participantId = 19,
  int seasonId = 1,
  int eventId = 12,
  int totalTokens = 1250,
  bool termsAccepted = true,
}) {
  final container = ProviderContainer(
    overrides: [
      participantIdProvider.overrideWith((ref) => participantId),
      seasonEventContextProvider.overrideWith(
        (ref) => SeasonEventContext(seasonId: seasonId, eventId: eventId),
      ),
      rankingProvider.overrideWith(
        () => _MockRankingController(
          RankingResult(
            scope: 'event',
            rank: 67,
            totalPoints: 22468,
            totalTokens: totalTokens,
            offchainPoints: 22468,
            totalParticipants: 138,
            eventId: eventId,
            termsAccepted: termsAccepted,
          ),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('tokenAllocationProvider', () {
    test('maps total_tokens from the scoped ranking response', () async {
      final data = await _container().read(tokenAllocationProvider.future);

      expect(data, isNotNull);
      expect(data!.amount, 1250);
      expect(data.acknowledged, isFalse);
    });

    test('persists the reveal across provider containers', () async {
      final first = _container();
      await first.read(tokenAllocationProvider.future);
      await first.read(tokenAllocationProvider.notifier).acknowledge();

      expect(first.read(tokenAllocationProvider).value?.acknowledged, isTrue);

      final restored = await _container().read(tokenAllocationProvider.future);
      expect(restored?.acknowledged, isTrue);
    });

    test('carries terms acceptance used to gate the allocation UI', () async {
      final data = await _container(
        termsAccepted: false,
      ).read(tokenAllocationProvider.future);

      expect(data!.termsAccepted, isFalse);
    });

    test('scopes reveal state to the event and allocation value', () async {
      final first = _container();
      await first.read(tokenAllocationProvider.future);
      await first.read(tokenAllocationProvider.notifier).acknowledge();

      final otherEvent = await _container(
        eventId: 13,
      ).read(tokenAllocationProvider.future);
      final changedAllocation = await _container(
        totalTokens: 1500,
      ).read(tokenAllocationProvider.future);

      expect(otherEvent?.acknowledged, isFalse);
      expect(changedAllocation?.acknowledged, isFalse);
    });

    test('acknowledge is idempotent', () async {
      final container = _container();
      await container.read(tokenAllocationProvider.future);
      final notifier = container.read(tokenAllocationProvider.notifier);

      await notifier.acknowledge();
      await notifier.acknowledge();

      expect(
        container.read(tokenAllocationProvider).value?.acknowledged,
        isTrue,
      );
    });
  });
}
