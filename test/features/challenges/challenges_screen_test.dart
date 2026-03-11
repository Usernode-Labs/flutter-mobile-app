import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
import 'package:crypto_mobile_app/core/utils/leaderboard_cache.dart';
import 'package:crypto_mobile_app/design_system/src/score_header.dart';
import 'package:crypto_mobile_app/design_system/src/shimmer_block.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/theme/color_is_expensive_theme.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';
import 'package:crypto_mobile_app/features/challenges/screens/challenges_screen.dart';
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

class _LoadingChallengesController extends ChallengesController {
  @override
  Future<CachedData<List<ChallengeDto>>?> build() {
    // Return a future that never completes (no Timer, safe for tests).
    return Completer<CachedData<List<ChallengeDto>>?>().future;
  }

  @override
  Future<void> silentRefresh() async {}

  @override
  Future<void> refresh() async {}
}

class _MockRankingController extends RankingController {
  _MockRankingController(this._data);
  final CachedData<RankingResult>? _data;

  @override
  Future<CachedData<RankingResult>?> build() async => _data;

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

class _MockSeasonsController extends SeasonsController {
  _MockSeasonsController(this._data);
  final CachedData<List<SeasonDto>>? _data;

  @override
  Future<CachedData<List<SeasonDto>>?> build() async => _data;

  @override
  Future<void> silentRefresh() async {}

  @override
  Future<void> refresh() async {}
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const _testChallenges = [
  ChallengeDto(
    id: 1,
    category: 'technical',
    goal: 'Produce Every Block',
    task: 'Successfully produce every block assigned.',
    reward: '8000',
    enabled: true,
    completed: false,
    scheduleStart: '2025-01-15T00:00:00Z',
    scheduleEnd: '2099-12-31T00:00:00Z',
  ),
  ChallengeDto(
    id: 2,
    category: 'community',
    goal: 'Prove Humanity',
    task: 'Complete the humanity verification.',
    reward: '1000',
    enabled: true,
    completed: true,
    scheduleStart: '2025-01-15T00:00:00Z',
    // Future date — without breakdown this stays active; with breakdown
    // the matching activity makes it completed.
    scheduleEnd: '2099-12-31T00:00:00Z',
  ),
  ChallengeDto(
    id: 3,
    category: 'flash',
    goal: 'Quick Challenge',
    task: 'A missed flash challenge.',
    reward: '500',
    enabled: false,
    completed: false,
    scheduleStart: '2025-01-01T00:00:00Z',
    scheduleEnd: '2025-01-14T00:00:00Z',
  ),
];

const _testRanking = RankingResult(
  scope: 'season',
  rank: 44,
  totalPoints: 8000,
  offchainPoints: 0,
  totalParticipants: 100,
  seasonId: 1,
  seasonName: 'Season 2',
);

const _testSeasons = [
  SeasonDto(
    id: 1,
    name: 'Season 2',
    isActive: true,
    events: [
      SeasonEventDto(id: 10, name: 'Event 10', isActive: true),
      SeasonEventDto(id: 11, name: 'Event 11', isActive: false),
    ],
  ),
];

const _testContext = SeasonEventContext(
  seasonId: 1,
  seasonName: 'Season 2',
  eventId: 10,
  eventName: 'Event 10',
);

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _buildTestApp({
  CachedData<List<ChallengeDto>>? challengeData,
  CachedData<RankingResult>? rankingData,
  CachedData<BreakdownResult>? breakdownData,
  CachedData<List<SeasonDto>>? seasonsData,
  SeasonEventContext seasonContext = _testContext,
  bool loading = false,
}) {
  return ProviderScope(
    overrides: [
      if (loading)
        challengesProvider.overrideWith(_LoadingChallengesController.new)
      else
        challengesProvider
            .overrideWith(() => _MockChallengesController(challengeData)),
      rankingProvider.overrideWith(() => _MockRankingController(rankingData)),
      breakdownProvider
          .overrideWith(() => _MockBreakdownController(breakdownData)),
      leaderboardBootstrapProvider.overrideWith((ref) async {}),
      zkIdentityIsCompleteProvider
          .overrideWithValue(const AsyncValue.data(false)),
      seasonEventContextProvider.overrideWith((ref) => seasonContext),
      seasonsProvider.overrideWith(() => _MockSeasonsController(
            seasonsData ??
                const CachedData(data: _testSeasons, isCached: false),
          )),
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
      home: const ChallengesScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ChallengesScreen', () {
    testWidgets('renders ScoreHeader with ranking data', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        challengeData: const CachedData(
          data: _testChallenges,
          isCached: false,
        ),
        rankingData: const CachedData(
          data: _testRanking,
          isCached: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ScoreHeader), findsOneWidget);
      expect(find.text('8,000'), findsOneWidget);
      expect(find.text('Rank 44'), findsOneWidget);
      expect(find.text('points'), findsOneWidget);
    });

    testWidgets('renders active challenges in default tab', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        challengeData: const CachedData(
          data: _testChallenges,
          isCached: false,
        ),
      ));
      await tester.pumpAndSettle();

      // Active tab — ZK Identity challenge is injected first, then api challenges.
      // ListView is lazy so we drag to ensure "Produce Every Block" is built.
      expect(
        find.text('Verify your identity with ZK Passport'),
        findsOneWidget,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('Produce Every Block'), findsOneWidget);
      // Without breakdown, "Prove Humanity" (enabled=true) is also active.
      // Missed challenges should not appear in active tab.
      expect(find.text('Quick Challenge'), findsNothing);
    });

    testWidgets('shows completed challenges when tab tapped', (tester) async {
      // Provide breakdown with activity description matching challenge goal
      await tester.pumpWidget(_buildTestApp(
        challengeData: const CachedData(
          data: _testChallenges,
          isCached: false,
        ),
        breakdownData: const CachedData(
          data: BreakdownResult(
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
          ),
          isCached: false,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      expect(find.text('Prove Humanity'), findsOneWidget);
      expect(find.text('Produce Every Block'), findsNothing);
    });

    testWidgets('shows missed challenges when tab tapped', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        challengeData: const CachedData(
          data: _testChallenges,
          isCached: false,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Missed'));
      await tester.pumpAndSettle();

      expect(find.text('Quick Challenge'), findsOneWidget);
      expect(find.text('Produce Every Block'), findsNothing);
    });

    testWidgets('shows shimmer placeholders when no cached data',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(loading: true));
      await tester.pump();

      expect(find.byType(ShimmerBlock), findsWidgets);
    });

    testWidgets('shows empty state for tab with no challenges', (tester) async {
      // Only the active challenge
      await tester.pumpWidget(_buildTestApp(
        challengeData: CachedData(
          data: [_testChallenges[0]],
          isCached: false,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      expect(find.text('No completed challenges'), findsOneWidget);
    });

    testWidgets('season chip shows season name from context', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        challengeData: const CachedData(
          data: _testChallenges,
          isCached: false,
        ),
        seasonContext: _testContext,
      ));
      await tester.pumpAndSettle();

      // Season name appears in DropdownChain chip
      expect(find.text('Season 2'), findsWidgets);
    });

    testWidgets('shows fallback score when ranking is null', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        challengeData: const CachedData(
          data: _testChallenges,
          isCached: false,
        ),
        rankingData: null,
      ));
      await tester.pumpAndSettle();

      // Two "--" widgets: one for the score, one for the countdown time fallback
      expect(find.text('--'), findsNWidgets(2));
    });

    testWidgets('ScoreHeader shows breakdown totalPoints when available',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(
        challengeData: const CachedData(
          data: _testChallenges,
          isCached: false,
        ),
        rankingData: const CachedData(
          data: _testRanking,
          isCached: false,
        ),
        breakdownData: const CachedData(
          data: BreakdownResult(
            scope: 'event',
            displayName: 'Test',
            totalPoints: 12345,
            offchainPoints: 0,
            eventBreakdown: EventBreakdown(
              eventId: 1,
              eventName: 'E1',
              totalPoints: 12345,
              offchainPoints: 0,
              rank: 10,
              activities: [],
            ),
          ),
          isCached: false,
        ),
      ));
      await tester.pumpAndSettle();

      // Breakdown totalPoints takes precedence over ranking
      expect(find.text('12,345'), findsOneWidget);
      expect(find.text('Rank 10'), findsOneWidget);
    });

    testWidgets('completed tab shows earned points from breakdown',
        (tester) async {
      // Activity description "Prove Humanity" matches challenge goal
      await tester.pumpWidget(_buildTestApp(
        challengeData: const CachedData(
          data: _testChallenges,
          isCached: false,
        ),
        breakdownData: const CachedData(
          data: BreakdownResult(
            scope: 'event',
            displayName: 'Test',
            totalPoints: 9000,
            offchainPoints: 0,
            eventBreakdown: EventBreakdown(
              eventId: 1,
              eventName: 'E1',
              totalPoints: 9000,
              offchainPoints: 0,
              activities: [
                BreakdownActivity(
                  id: 100,
                  activityType: 'COMMUNITY',
                  points: 6491,
                  description: 'Prove Humanity',
                ),
              ],
            ),
          ),
          isCached: false,
        ),
      ));
      await tester.pumpAndSettle();

      // "Prove Humanity" matched by description → completed tab
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      expect(find.text('Prove Humanity'), findsOneWidget);
      expect(find.text('6,491 pts'), findsOneWidget);
    });

    testWidgets('graceful fallback when breakdown is null', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        challengeData: const CachedData(
          data: _testChallenges,
          isCached: false,
        ),
        rankingData: const CachedData(
          data: _testRanking,
          isCached: false,
        ),
        breakdownData: null,
      ));
      await tester.pumpAndSettle();

      // Without breakdown, falls back to ranking totalPoints
      expect(find.text('8,000'), findsOneWidget);
      expect(find.text('Rank 44'), findsOneWidget);

      // Challenges still categorized (v1 fallback: all activity: null).
      // Drag past injected ZK Identity card to find the api challenge.
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('Produce Every Block'), findsOneWidget);
    });
  });
}
