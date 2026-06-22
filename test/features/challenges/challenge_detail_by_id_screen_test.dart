import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/challenges/screens/challenge_detail_by_id_screen.dart';
import 'package:crypto_mobile_app/features/challenges/screens/challenges_screen.dart';

class _MockChallengesController extends ChallengesController {
  _MockChallengesController(this._data);

  final List<ChallengeDto>? _data;

  @override
  Future<List<ChallengeDto>?> build() async => _data;

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
  @override
  Future<RankingResult?> build() async => null;

  @override
  Future<void> silentRefresh() async {}
}

void main() {
  testWidgets('resolves challenge detail from id', (tester) async {
    await tester.pumpWidget(
      _app(
        challengeId: 104,
        challenges: [_challenge(id: 104, goal: 'Give Kudos')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Give Kudos'), findsWidgets);
    expect(find.text('Recognize useful contributions.'), findsOneWidget);
  });

  testWidgets('falls back to Challenges root when id is stale', (tester) async {
    await tester.pumpWidget(
      _app(
        challengeId: 999,
        challenges: [_challenge(id: 104, goal: 'Give Kudos')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Give Kudos'), findsWidgets);
    expect(find.text('Recognize useful contributions.'), findsNothing);
  });
}

Widget _app({
  required int challengeId,
  required List<ChallengeDto> challenges,
}) {
  final router = GoRouter(
    initialLocation: AppRoutes.challengeDetailFor(challengeId),
    routes: [
      GoRoute(
        path: AppRoutes.challenges,
        builder: (context, state) => const ChallengesScreen(),
      ),
      GoRoute(
        path: AppRoutes.challengeDetailById,
        builder: (context, state) {
          final raw = state.pathParameters['id'];
          return ChallengeDetailByIdScreen(
            challengeId: int.tryParse(raw ?? ''),
          );
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      challengesProvider.overrideWith(
        () => _MockChallengesController(challenges),
      ),
      breakdownProvider.overrideWith(() => _MockBreakdownController(null)),
      rankingProvider.overrideWith(_MockRankingController.new),
      leaderboardBootstrapProvider.overrideWith((ref) async {}),
      seasonEventContextProvider.overrideWith(
        (ref) => const SeasonEventContext(seasonId: 1, seasonName: 'Season 1'),
      ),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ColorIsExpensiveTheme(ThemeData.light().textTheme)
          .light()
          .copyWith(
            extensions: DesignSystemTheme.standardExtensions(
              semanticColors: AppSemanticColors.light(),
            ),
          ),
      routerConfig: router,
    ),
  );
}

ChallengeDto _challenge({required int id, required String goal}) {
  return ChallengeDto(
    id: id,
    category: 'community',
    goal: goal,
    task: 'Give kudos to another participant.',
    reward: '1500',
    description: 'Recognize useful contributions.',
    scheduleEnd: DateTime(2026, 6, 23).toIso8601String(),
    enabled: true,
    completed: false,
  );
}
