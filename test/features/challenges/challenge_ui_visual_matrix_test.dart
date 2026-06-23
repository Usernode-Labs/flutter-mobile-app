import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/categorized_challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/services/challenge_api_visual_fixture.dart';
import 'package:crypto_mobile_app/core/services/challenge_ui_visual_fixture.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_presentation.dart';
import 'package:crypto_mobile_app/features/challenges/screens/challenges_screen.dart';
import 'package:crypto_mobile_app/features/profile/screens/profile_screen.dart';

import '../../design_system/helpers/ds_test_helpers.dart';
import '../../helpers/screenshot_artifacts.dart';

class _MockChallengesController extends ChallengesController {
  @override
  Future<List<ChallengeDto>?> build() async =>
      ChallengeUiVisualFixture.challenges();

  @override
  Future<void> silentRefresh() async {}
}

class _MockBreakdownController extends BreakdownController {
  @override
  Future<BreakdownResult?> build() async =>
      ChallengeUiVisualFixture.breakdown();

  @override
  Future<void> silentRefresh() async {}
}

class _MockRankingController extends RankingController {
  @override
  Future<RankingResult?> build() async => ChallengeUiVisualFixture.ranking();

  @override
  Future<void> silentRefresh() async {}
}

class _MockLeaderboardController extends LeaderboardController {
  @override
  Future<LeaderboardState?> build() async => LeaderboardState(
        allEntries: ChallengeUiVisualFixture.leaderboard().entries,
      );

  @override
  Future<void> silentRefresh() async {}
}

CategorizedEnrichedChallenges _matrixCategorized() {
  final enriched = enrichChallenges(
    ChallengeUiVisualFixture.challenges(),
    null,
  );
  return categorizeEnrichedChallenges(enriched);
}

Widget _localizedApp(Widget home) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: themeWithExtensions(),
    builder: (context, child) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(disableAnimations: true),
        child: TickerMode(
          enabled: false,
          child: child ?? const SizedBox.shrink(),
        ),
      );
    },
    home: home,
  );
}

List<Override> _commonOverrides() => [
      challengesProvider.overrideWith(_MockChallengesController.new),
      breakdownProvider.overrideWith(_MockBreakdownController.new),
      rankingProvider.overrideWith(_MockRankingController.new),
      leaderboardBootstrapProvider.overrideWith((ref) async {}),
      seasonEventContextProvider.overrideWith(
        (ref) => const SeasonEventContext(
          seasonId: ChallengeUiVisualFixture.seasonId,
          seasonName: ChallengeUiVisualFixture.seasonName,
        ),
      ),
    ];

Widget _challengesScreenApp(GlobalKey screenshotKey) {
  return ProviderScope(
    overrides: _commonOverrides(),
    child: _localizedApp(
      RepaintBoundary(
        key: screenshotKey,
        child: const ChallengesScreen(),
      ),
    ),
  );
}

Widget _profileScreenApp(GlobalKey screenshotKey) {
  return ProviderScope(
    overrides: [
      ..._commonOverrides(),
      leaderboardProvider.overrideWith(_MockLeaderboardController.new),
      participantIdProvider.overrideWith(
        (ref) async => ChallengeUiVisualFixture.participantId,
      ),
      categorizedChallengesProvider.overrideWithValue(_matrixCategorized()),
    ],
    child: _localizedApp(
      RepaintBoundary(
        key: screenshotKey,
        child: const ProfileScreen(),
      ),
    ),
  );
}

Widget _atomicCardMatrix(GlobalKey screenshotKey) {
  return _localizedApp(
    RepaintBoundary(
      key: screenshotKey,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Builder(
          builder: (context) {
            final spacing = Theme.of(context).extension<AppSpacing>()!;
            final textTheme = Theme.of(context).textTheme;
            final colors = Theme.of(context).colorScheme;

            return SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.all(spacing.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing.space16,
                children: [
                  Text(
                    'Challenge UI State Matrix',
                    style: textTheme.titleLarge,
                  ),
                  for (final phase in ChallengeVisualUiPhase.values) ...[
                    Text(
                      _phaseLabel(phase),
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: spacing.space8,
                      children: [
                        for (final fixtureCase
                            in ChallengeUiVisualFixture.allCases.where(
                          (item) => item.phase == phase,
                        ))
                          AtomicChallengeCard(
                            title: fixtureCase.challenge.goal,
                            leftText: mapToAtomicCard(
                              EnrichedChallenge(dto: fixtureCase.challenge),
                              progress: fixtureCase.progress,
                            ).leftText,
                            rightText: mapToAtomicCard(
                              EnrichedChallenge(dto: fixtureCase.challenge),
                              progress: fixtureCase.progress,
                            ).rightText,
                            phase: mapToAtomicCard(
                              EnrichedChallenge(dto: fixtureCase.challenge),
                              progress: fixtureCase.progress,
                            ).phase,
                            fill: mapToAtomicCard(
                              EnrichedChallenge(dto: fixtureCase.challenge),
                              progress: fixtureCase.progress,
                            ).fill,
                            railTreatment: mapToAtomicCard(
                              EnrichedChallenge(dto: fixtureCase.challenge),
                              progress: fixtureCase.progress,
                            ).railTreatment,
                            onTap: () {},
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

Widget _apiContractMatrix(GlobalKey screenshotKey) {
  return _localizedApp(
    RepaintBoundary(
      key: screenshotKey,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Builder(
          builder: (context) {
            final spacing = Theme.of(context).extension<AppSpacing>()!;
            final textTheme = Theme.of(context).textTheme;
            final colors = Theme.of(context).colorScheme;
            final cases = ChallengeApiVisualFixture.cases;
            final groups = <String>{for (final item in cases) item.group};

            return SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.all(spacing.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing.space16,
                children: [
                  Text(
                    'API Challenge Contract Matrix',
                    style: textTheme.titleLarge,
                  ),
                  for (final group in groups) ...[
                    Text(
                      group,
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: spacing.space8,
                      children: [
                        for (final item
                            in cases.where((item) => item.group == group))
                          _ApiContractCasePreview(item: item),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _ApiContractCasePreview extends StatelessWidget {
  const _ApiContractCasePreview({required this.item});

  final ChallengeApiVisualCase item;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final card = mapToAtomicCard(
      EnrichedChallenge(dto: item.challenge),
      progress: item.progress,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.space4,
      children: [
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        AtomicChallengeCard(
          title: card.title,
          leftText: card.leftText,
          rightText: card.rightText,
          phase: card.phase,
          fill: card.fill,
          railTreatment: card.railTreatment,
          onTap: () {},
        ),
      ],
    );
  }
}

String _phaseLabel(ChallengeVisualUiPhase phase) => switch (phase) {
      ChallengeVisualUiPhase.open => 'Open',
      ChallengeVisualUiPhase.inProgress => 'In progress',
      ChallengeVisualUiPhase.pending => 'Pending finalization',
      ChallengeVisualUiPhase.completed => 'Completed',
    };

Future<void> _pumpStatic(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
}

void main() {
  group('Challenge UI visual matrix artifacts', () {
    testWidgets('AtomicChallengeCard renders every type and UI phase',
        (tester) async {
      final screenshotKey = GlobalKey();
      await setScreenshotSurfaceSize(tester, const Size(440, 4200));

      await _pumpStatic(tester, _atomicCardMatrix(screenshotKey));

      expect(
        find.byType(AtomicChallengeCard),
        findsNWidgets(ChallengeUiVisualFixture.allCases.length),
      );
      for (final fixtureCase in ChallengeUiVisualFixture.allCases) {
        expect(find.text(fixtureCase.challenge.goal), findsOneWidget);
      }
      expect(tester.takeException(), isNull);

      final artifact = await writeWidgetScreenshotArtifact(
        tester,
        screenshotKey,
        'atomic-challenge-card-matrix.png',
      );
      expect(artifact.existsSync(), isTrue);
    });

    testWidgets('API contract matrix renders current response shapes',
        (tester) async {
      final screenshotKey = GlobalKey();
      await setScreenshotSurfaceSize(tester, const Size(440, 5200));

      await _pumpStatic(tester, _apiContractMatrix(screenshotKey));

      expect(
        find.byType(AtomicChallengeCard),
        findsNWidgets(ChallengeApiVisualFixture.cases.length),
      );
      expect(find.text('1 / 3 Actions'), findsOneWidget);
      expect(find.text('Not done'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);

      final artifact = await writeWidgetScreenshotArtifact(
        tester,
        screenshotKey,
        'api-challenge-contract-matrix.png',
      );
      expect(artifact.existsSync(), isTrue);
    });

    testWidgets('ChallengesScreen renders the full matrix including completed',
        (tester) async {
      final screenshotKey = GlobalKey();
      await setScreenshotSurfaceSize(tester, const Size(440, 5200));

      await _pumpStatic(tester, _challengesScreenApp(screenshotKey));

      expect(
        find.byType(AtomicChallengeCard),
        findsNWidgets(ChallengeUiVisualFixture.allCases.length),
      );
      for (final fixtureCase in ChallengeUiVisualFixture.allCases) {
        expect(find.text(fixtureCase.challenge.goal), findsOneWidget);
      }
      expect(tester.takeException(), isNull);

      final artifact = await writeWidgetScreenshotArtifact(
        tester,
        screenshotKey,
        'challenges-active-matrix.png',
      );
      expect(artifact.existsSync(), isTrue);
    });

    testWidgets('ProfileScreen completed tab renders every completed type',
        (tester) async {
      final screenshotKey = GlobalKey();
      await setScreenshotSurfaceSize(tester, const Size(440, 1500));

      await _pumpStatic(tester, _profileScreenApp(screenshotKey));

      for (final fixtureCase in ChallengeUiVisualFixture.completedCases) {
        expect(find.text(fixtureCase.challenge.goal), findsOneWidget);
      }
      for (final fixtureCase in ChallengeUiVisualFixture.activeCases) {
        expect(find.text(fixtureCase.challenge.goal), findsNothing);
      }
      expect(tester.takeException(), isNull);

      final artifact = await writeWidgetScreenshotArtifact(
        tester,
        screenshotKey,
        'profile-completed-matrix.png',
      );
      expect(artifact.existsSync(), isTrue);
    });
  });
}
