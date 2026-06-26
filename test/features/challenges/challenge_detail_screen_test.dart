import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/produced_blocks_provider.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/challenges/screens/challenge_detail_screen.dart';

class _MockBreakdownController extends BreakdownController {
  _MockBreakdownController(this._data);

  final BreakdownResult? _data;

  @override
  Future<BreakdownResult?> build() async => _data;

  @override
  Future<void> silentRefresh() async {}
}

class _MockNodeStatusController extends NodeStatusController {
  @override
  Future<NodeStatusState?> build() async => null;

  @override
  Future<void> silentRefresh() async {}
}

const _challengeId = 42;
const _eventId = 7;

const _produceBlocksChallenge = ChallengeDto(
  id: _challengeId,
  eventId: _eventId,
  eventName: 'June 2026',
  category: 'technical',
  goal: 'Produce Every Block - June 2026',
  task: 'Discover block assignments and stay connected.',
  reward: '6500',
  description: 'Keep your node online and ready during your assigned slots.',
  rewardLogic: 'Score = success rate x assigned-slot points.',
  ctaLabel: 'Check node',
  enabled: true,
  completed: false,
  subCategory: kProduceBlocksSubCategory,
  activitiesTotal: 9050,
  metric: ChallengeMetric(
    kind: ChallengeMetricKind.percentage,
    label: 'success',
  ),
);

const _produceBlocksActivity = BreakdownActivity(
  id: 'activity-42',
  activityType: 'produce_blocks',
  points: 9050,
  description: 'Produce Every Block - June 2026',
  challengeId: _challengeId,
);

BreakdownResult _breakdown() => const BreakdownResult(
      scope: 'season',
      displayName: 'Season 1',
      totalPoints: 10550,
      offchainPoints: 10550,
      seasonBreakdown: SeasonBreakdown(
        seasonId: 1,
        seasonName: 'Season 1',
        totalPoints: 10550,
        offchainPoints: 10550,
        events: [
          EventBreakdown(
            eventId: _eventId,
            eventName: 'June 2026',
            totalPoints: 10550,
            offchainPoints: 10550,
            rank: 2,
            top3Points: 1500,
            successRate: 90,
            challengeProgress: [
              ChallengeProgress(
                challengeId: _challengeId,
                state: ChallengeProgressState.inProgress,
                earnedPoints: 9050,
              ),
            ],
          ),
        ],
      ),
    );

final _blocksSummary = ProducedBlocksSummary(
  totalScore: 0,
  currentEpochSlot: 0,
  currentEpoch: 0,
  slotsInEpoch: 0,
  rewardsPerBlock: BigInt.zero,
  maxEpochWithData: 0,
  epochScores: [],
  hasEpochsWithData: false,
);

Widget _app() {
  return ProviderScope(
    overrides: [
      breakdownProvider
          .overrideWith(() => _MockBreakdownController(_breakdown())),
      producedBlocksSummaryProvider.overrideWith((ref) async => _blocksSummary),
      nodeStatusProvider.overrideWith(_MockNodeStatusController.new),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme:
          ColorIsExpensiveTheme(ThemeData.light().textTheme).light().copyWith(
                extensions: DesignSystemTheme.standardExtensions(
                  semanticColors: AppSemanticColors.light(),
                ),
              ),
      home: const ChallengeDetailScreen(
        challenge: EnrichedChallenge(
          dto: _produceBlocksChallenge,
          activity: _produceBlocksActivity,
        ),
      ),
    ),
  );
}

void main() {
  group('ChallengeDetailScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('produce-blocks renders through the atomic technical hero',
        (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AtomicChallengeDetailPage), findsOneWidget);
      expect(find.byType(ChallengeDetailPage), findsNothing);
      expect(find.text('Produce Every Block - June 2026'), findsOneWidget);
      expect(find.text('Total Earned'), findsOneWidget);
      expect(find.text('10,550'), findsOneWidget);
      expect(find.text('90% success'), findsOneWidget);
      expect(find.text('Earned 9,050 pts'), findsOneWidget);
      expect(find.text('Success rate'), findsOneWidget);
      expect(find.text('Assigned slots'), findsOneWidget);
      expect(find.text('Base reward'), findsOneWidget);
      expect(find.text('5,000'), findsOneWidget);
      expect(find.text('Top 3 rank reward'), findsOneWidget);
      expect(find.text('2nd'), findsOneWidget);
      expect(find.text('+1,500'), findsOneWidget);
      expect(find.text('Live status'), findsOneWidget);
      expect(find.text('Network'), findsOneWidget);
      expect(find.text('Loading'), findsWidgets);
      expect(find.text('Missed Blocks'), findsOneWidget);
    });
  });
}
