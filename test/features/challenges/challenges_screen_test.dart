import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/challenges/screens/challenges_screen.dart';

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
}

class _LoadingChallengesController extends ChallengesController {
  @override
  Future<List<ChallengeDto>?> build() =>
      Completer<List<ChallengeDto>?>().future;

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

class _MockRankingController extends RankingController {
  _MockRankingController(this._data);
  final RankingResult? _data;

  @override
  Future<RankingResult?> build() async => _data;

  @override
  Future<void> silentRefresh() async {}
}

// ---------------------------------------------------------------------------
// Test data — three active challenges that fall into distinct bands.
// ---------------------------------------------------------------------------

ChallengeDto _ch(
  int id,
  String goal,
  Duration endsIn, {
  ChallengeMetric? metric,
  String reward = '500',
}) {
  final now = DateTime.now();
  return ChallengeDto(
    id: id,
    category: 'community',
    goal: goal,
    task: goal,
    reward: reward,
    metric: metric,
    enabled: true,
    completed: false,
    scheduleStart: now.subtract(const Duration(days: 2)).toIso8601String(),
    scheduleEnd: now.add(endsIn).toIso8601String(),
  );
}

List<ChallengeDto> _challenges() => [
      _ch(101, 'Propose an app change', const Duration(days: 10),
          metric: const ChallengeMetric(kind: ChallengeMetricKind.binary)),
      _ch(102, 'Fill in survey', const Duration(hours: 5, minutes: 1),
          metric: const ChallengeMetric(kind: ChallengeMetricKind.binary)),
      _ch(103, 'Give kudos', const Duration(days: 4, hours: 1),
          reward: '1500',
          metric: const ChallengeMetric(
            kind: ChallengeMetricKind.count,
            target: 5,
          )),
    ];

BreakdownResult _breakdown() => const BreakdownResult(
      scope: 'season',
      displayName: 'Season 1',
      totalPoints: 8000,
      offchainPoints: 8000,
      challengeProgress: [
        ChallengeProgress(challengeId: 101, state: ChallengeProgressState.none),
        ChallengeProgress(
          challengeId: 102,
          state: ChallengeProgressState.pending,
          pendingPoints: 500,
          description: 'Submitted',
        ),
        ChallengeProgress(
          challengeId: 103,
          state: ChallengeProgressState.inProgress,
          current: 2,
          target: 5,
          earnedPoints: 400,
        ),
      ],
    );

Widget _app({
  List<ChallengeDto>? challengeData,
  BreakdownResult? breakdownData,
  bool loading = false,
}) {
  return ProviderScope(
    overrides: [
      if (loading)
        challengesProvider.overrideWith(_LoadingChallengesController.new)
      else
        challengesProvider
            .overrideWith(() => _MockChallengesController(challengeData)),
      breakdownProvider
          .overrideWith(() => _MockBreakdownController(breakdownData)),
      rankingProvider.overrideWith(() => _MockRankingController(null)),
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
      home: const ChallengesScreen(),
    ),
  );
}

void main() {
  group('ChallengesScreen (bands)', () {
    testWidgets('renders the top status bar and points label', (tester) async {
      await tester.pumpWidget(
        _app(challengeData: _challenges(), breakdownData: _breakdown()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TopStatusAppBar), findsOneWidget);
      expect(find.text('8,000 pts'), findsOneWidget); // profile label
    });

    testWidgets('groups active challenges into perceived-time bands',
        (tester) async {
      await tester.pumpWidget(
        _app(challengeData: _challenges(), breakdownData: _breakdown()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Featured'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);

      expect(find.text('Propose an app change'), findsOneWidget);
      expect(find.text('Fill in survey'), findsOneWidget);
      expect(find.text('Give kudos'), findsOneWidget);
    });

    testWidgets('shows shimmer while loading', (tester) async {
      await tester.pumpWidget(_app(loading: true));
      await tester.pump();

      expect(find.byType(ShimmerCardSkeleton), findsWidgets);
    });
  });
}
