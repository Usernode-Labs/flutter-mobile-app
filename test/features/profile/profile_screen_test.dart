import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/categorized_challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/design_system/theme/color_is_expensive_theme.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/profile/screens/profile_screen.dart';

class _MockRankingController extends RankingController {
  _MockRankingController(this._data);
  final RankingResult? _data;
  @override
  Future<RankingResult?> build() async => _data;
  @override
  Future<void> silentRefresh() async {}
}

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

const _completedChallenge = ChallengeDto(
  id: 201,
  category: 'community',
  goal: 'Community Sprint',
  task: 'Help other members all season.',
  reward: '3000',
  enabled: true,
  completed: true,
  scheduleStart: '2026-01-01T00:00:00Z',
  scheduleEnd: '2026-02-01T00:00:00Z',
);

Widget _app() {
  return ProviderScope(
    overrides: [
      rankingProvider.overrideWith(
        () => _MockRankingController(
          const RankingResult(
            scope: 'season',
            rank: 44,
            totalPoints: 8000,
            offchainPoints: 8000,
            totalParticipants: 100,
            seasonId: 1,
            seasonName: 'Season 1',
          ),
        ),
      ),
      breakdownProvider.overrideWith(
        () => _MockBreakdownController(
          const BreakdownResult(
            scope: 'season',
            displayName: 'Season 1',
            totalPoints: 8000,
            offchainPoints: 8000,
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
      categorizedChallengesProvider.overrideWithValue(
        const CategorizedEnrichedChallenges(
          active: [],
          completed: [EnrichedChallenge(dto: _completedChallenge)],
          missed: [],
        ),
      ),
      participantIdProvider.overrideWith((ref) async => 1),
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

void main() {
  testWidgets('Profile shows score, tabs and completed challenge',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('8,000'), findsOneWidget); // score
    expect(find.text('Rank 44'), findsOneWidget);
    expect(find.text('Completed Challenges'), findsOneWidget);
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('Community Sprint'), findsOneWidget);
  });

  testWidgets('Leaderboard tab shows ranked entries', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Leaderboard'));
    await tester.pumpAndSettle();

    expect(find.text('node-alpha'), findsOneWidget);
    expect(find.text('18,420 pts'), findsOneWidget);
  });
}
