import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/profile/screens/profile_screen.dart';

class _MockRankingController extends RankingController {
  _MockRankingController(this._data);
  final RankingResult? _data;
  @override
  Future<RankingResult?> build() async => _data;
  @override
  Future<void> silentRefresh() async {}
}

/// Serves [_initial] on build, then swaps to [_refreshed] on the next
/// [silentRefresh] — models the backend catching up after terms acceptance.
class _RefreshableRankingController extends RankingController {
  _RefreshableRankingController(this._initial, this._refreshed);
  final RankingResult _initial;
  final RankingResult _refreshed;
  @override
  Future<RankingResult?> build() async => _initial;
  @override
  Future<void> silentRefresh() async {
    state = AsyncData(_refreshed);
  }
}

/// The real, accepted allocation the backend returns post-consent.
const _acceptedRanking = RankingResult(
  scope: 'season',
  rank: 44,
  totalPoints: 8000,
  totalTokens: 1250,
  offchainPoints: 8000,
  totalParticipants: 100,
  seasonId: 1,
  seasonName: 'Season 1',
  termsAccepted: true,
);

/// Gated (allocation withheld, forced to 0) until a refresh, then the real
/// accepted allocation the backend returns.
RankingController _gatedThenAcceptedRanking() => _RefreshableRankingController(
      const RankingResult(
        scope: 'season',
        rank: 44,
        totalPoints: 8000,
        totalTokens: 0,
        offchainPoints: 8000,
        totalParticipants: 100,
        seasonId: 1,
        seasonName: 'Season 1',
        termsAccepted: false,
      ),
      _acceptedRanking,
    );

class _MockBreakdownController extends BreakdownController {
  _MockBreakdownController(this._data);
  final BreakdownResult? _data;
  @override
  Future<BreakdownResult?> build() async => _data;
  @override
  Future<void> silentRefresh() async {}
}

class _MockLeaderboardController extends LeaderboardController {
  _MockLeaderboardController(this._data);
  final LeaderboardState? _data;
  @override
  Future<LeaderboardState?> build() async => _data;
  @override
  Future<void> silentRefresh() async {}
}

class _MockSeasonsController extends SeasonsController {
  _MockSeasonsController(this._data);
  final List<SeasonDto> _data;
  @override
  Future<List<SeasonDto>?> build() async => _data;
  @override
  Future<void> silentRefresh() async {}
}

class _MockProfileHistoryService extends LeaderboardApiService {
  @override
  Future<List<ChallengeDto>> getChallenges({
    int? seasonId,
    int? eventId,
    bool? activeOnly,
    bool? onlyScheduled,
  }) async =>
      const [_completedChallenge, _completedProduceBlocksChallenge];

  @override
  Future<BreakdownResult> getBreakdown({
    int? seasonId,
    int? eventId,
  }) async =>
      const BreakdownResult(
        scope: 'global',
        displayName: 'Participant 1',
        totalPoints: 3000,
        offchainPoints: 3000,
        globalSeasons: [
          SeasonBreakdown(
            seasonId: 1,
            seasonName: 'Season 1',
            totalPoints: 3000,
            offchainPoints: 3000,
            events: [
              EventBreakdown(
                eventId: 1,
                eventName: 'Phase 1',
                totalPoints: 3000,
                offchainPoints: 3000,
                successRate: 56.56,
                challengeProgress: [
                  ChallengeProgress(
                    challengeId: 201,
                    state: ChallengeProgressState.none,
                    earnedPoints: 3000,
                  ),
                  ChallengeProgress(
                    challengeId: 301,
                    state: ChallengeProgressState.none,
                    earnedPoints: 2828,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

  @override
  void dispose() {}
}

const _completedChallenge = ChallengeDto(
  id: 201,
  eventId: 1,
  eventName: 'Phase 1',
  category: 'community',
  goal: 'Community Sprint',
  task: 'Help other members all season.',
  reward: '3000',
  enabled: true,
  completed: false,
  scheduleStart: '2026-01-01T00:00:00Z',
  scheduleEnd: '2026-12-01T00:00:00Z',
);

const _completedProduceBlocksChallenge = ChallengeDto(
  id: 301,
  eventId: 1,
  eventName: 'Phase 1',
  subCategory: 'PRODUCE_BLOCKS_CHALLENGE',
  category: 'technical',
  goal: 'Produce Every Block - June 2026',
  task: 'Stay connected to produce assigned blocks.',
  reward: 'Up to 6,500 pts',
  enabled: true,
  completed: false,
  scheduleStart: '2026-01-01T00:00:00Z',
  scheduleEnd: '2026-12-01T00:00:00Z',
);

Widget _app({RankingController Function()? rankingController}) {
  return ProviderScope(
    overrides: [
      rankingProvider.overrideWith(
        rankingController ??
            () => _MockRankingController(
                  const RankingResult(
                    scope: 'season',
                    rank: 44,
                    totalPoints: 8000,
                    totalTokens: 1250,
                    offchainPoints: 8000,
                    totalParticipants: 100,
                    seasonId: 1,
                    seasonName: 'Season 1',
                  ),
                ),
      ),
      leaderboardApiServiceProvider.overrideWithValue(
        _MockProfileHistoryService(),
      ),
      breakdownProvider.overrideWith(
        () => _MockBreakdownController(
          const BreakdownResult(
            scope: 'season',
            displayName: 'Season 1',
            totalPoints: 8000,
            offchainPoints: 8000,
            seasonBreakdown: SeasonBreakdown(
              seasonId: 1,
              seasonName: 'Season 1',
              totalPoints: 8000,
              offchainPoints: 8000,
              events: [
                EventBreakdown(
                  eventId: 1,
                  eventName: 'Phase 1',
                  totalPoints: 8000,
                  offchainPoints: 8000,
                  challengeProgress: [
                    ChallengeProgress(
                      challengeId: 201,
                      state: ChallengeProgressState.earned,
                      earnedPoints: 3000,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      leaderboardProvider.overrideWith(
        () => _MockLeaderboardController(
          const LeaderboardState(
            allEntries: [
              LeaderboardEntry(
                rank: 1,
                participantId: 1001,
                displayName: 'node-alpha',
                totalPoints: 18420,
                offchainPoints: 18420,
                totalProducedBlocks: 0,
                vrfTotalWonSlots: 0,
                successRate: 0,
                eventsParticipated: 1,
              ),
            ],
          ),
        ),
      ),
      seasonsProvider.overrideWith(
        () => _MockSeasonsController(
          const [
            SeasonDto(
              id: 1,
              name: 'Season 1',
              isActive: true,
              events: [
                SeasonEventDto(
                  id: 1,
                  name: 'Phase 1',
                  isActive: true,
                ),
              ],
            ),
            SeasonDto(
              id: 2,
              name: 'Season 2',
              endsAt: '2026-01-01T00:00:00Z',
              isActive: false,
            ),
          ],
        ),
      ),
      participantIdProvider.overrideWith((ref) async => 1),
      isAuthenticatedProvider.overrideWithValue(true),
      showSignInGateProvider.overrideWithValue(false),
      leaderboardBootstrapProvider.overrideWith((ref) async {}),
      seasonEventContextProvider.overrideWith(
        (ref) => const SeasonEventContext(seasonId: 1, seasonName: 'Season 1'),
      ),
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
      home: const ProfileScreen(),
    ),
  );
}

/// Sizes the test surface to a typical portrait phone. The default 800x600
/// surface is wide-and-short (unlike any real device); a portrait size gives
/// the header room and matches how the pull-to-refresh gesture is really used.
void _usePortrait(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Profile shows score, tabs and completed challenge',
      (tester) async {
    _usePortrait(tester);
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('8,000'), findsOneWidget); // score
    expect(find.text('Rank 44'), findsOneWidget);
    expect(find.text('Season 1'), findsOneWidget);
    expect(find.text('All Events'), findsNothing);
    expect(find.byType(DropdownChip), findsOneWidget);
    expect(find.byType(NestedScrollView), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(TabBarView), findsOneWidget);
    expect(find.text('Completed Challenges'), findsOneWidget);
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('Community Sprint'), findsOneWidget);
    expect(find.text('completed 3,000 pts'), findsOneWidget);

    // The allocation card scrolls in the header, so the second challenge can
    // sit past the fold; scroll the NestedScrollView to reveal it.
    await tester.scrollUntilVisible(
      find.text('Produce Every Block - June 2026'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Produce Every Block - June 2026'), findsOneWidget);
    expect(find.text('57% success'), findsOneWidget);
    expect(find.text('Earned 2,828 pts'), findsOneWidget);
    expect(find.text('Not done'), findsNothing);
    expect(find.byType(OngoingRailFrame), findsNothing);
  });

  testWidgets('Profile reveals the API-backed token allocation',
      (tester) async {
    _usePortrait(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Indicative token allocation'), findsOneWidget);
    expect(find.text('Reveal'), findsOneWidget);
    expect(find.text('1,250'), findsNothing);

    await tester.tap(find.text('Reveal'));
    await tester.pumpAndSettle();

    expect(find.text('1,250'), findsOneWidget);
    // Profile deliberately omits unitLabel: the allocation is indicative, so it
    // is not presented as a concrete UNODE balance.
    expect(find.text('UNODE'), findsNothing);
    expect(find.text('Reveal'), findsNothing);
  });

  testWidgets(
      'Periodic auto-refresh surfaces the allocation once terms are accepted',
      (tester) async {
    _usePortrait(tester);
    await tester.pumpWidget(
      _app(rankingController: _gatedThenAcceptedRanking),
    );
    await tester.pumpAndSettle();

    // Gated: the withheld-allocation notice, not the reveal card.
    expect(find.text('Review terms'), findsOneWidget);
    expect(find.text('Reveal'), findsNothing);

    // The poll fires, the controller serves the accepted allocation, and the
    // profile re-renders the reveal card without any user action.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Reveal'), findsOneWidget);
    expect(find.text('Review terms'), findsNothing);
  });

  testWidgets('Auto-refresh does not flash the loading skeleton',
      (tester) async {
    _usePortrait(tester);
    // Ranking that re-serves the SAME accepted allocation on every poll.
    await tester.pumpWidget(
      _app(
        rankingController: () => _RefreshableRankingController(
          _acceptedRanking,
          _acceptedRanking,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Reveal card is up; no skeleton.
    expect(find.text('Indicative token allocation'), findsOneWidget);
    expect(find.byType(ShimmerCardSkeleton), findsNothing);

    // Fire the poll, then step frame-by-frame through the reload. The token
    // card must never fall back to the loading skeleton (the blink).
    await tester.pump(const Duration(seconds: 4));
    for (var i = 0; i < 5; i++) {
      expect(
        find.byType(ShimmerCardSkeleton),
        findsNothing,
        reason: 'skeleton flashed on reload frame $i',
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(ShimmerCardSkeleton), findsNothing);
    expect(find.text('Indicative token allocation'), findsOneWidget);
  });

  testWidgets('Pull-to-refresh surfaces the allocation once terms are accepted',
      (tester) async {
    _usePortrait(tester);
    await tester.pumpWidget(
      _app(rankingController: _gatedThenAcceptedRanking),
    );
    await tester.pumpAndSettle();

    // Gated: the withheld-allocation notice, not the reveal card.
    expect(find.text('Review terms'), findsOneWidget);
    expect(find.text('Reveal'), findsNothing);

    // Pull down from the top — over the score/allocation card in the scrolling
    // header, the natural gesture. An incremental drag (not a fling) sustains
    // the overscroll the RefreshIndicator needs to arm.
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(ScoreHeader)));
    for (var i = 0; i < 25; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Reveal'), findsOneWidget);
    expect(find.text('Review terms'), findsNothing);
  });

  testWidgets('Leaderboard tab shows ranked entries', (tester) async {
    _usePortrait(tester);
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.text('Leaderboard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('node-alpha'), findsOneWidget);
    expect(find.text('18,420 pts'), findsOneWidget);
  });

  testWidgets('Profile season chip opens season picker', (tester) async {
    _usePortrait(tester);
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.text('Season 1'));
    await tester.pumpAndSettle();

    expect(find.text('Select Season'), findsOneWidget);
    expect(find.text('Season 1'), findsWidgets);
    expect(find.text('Season 2 (Ended)'), findsOneWidget);
  });
}
