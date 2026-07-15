import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/features/terms/providers/terms_provider.dart';
import 'package:crypto_mobile_app/features/terms/screens/terms_screen.dart';

import '../../design_system/helpers/ds_test_helpers.dart';

class _FakeService extends LeaderboardApiService {
  _FakeService({this.terms, this.postError});

  final CurrentTerms? terms;
  final Object? postError;
  final List<String> posted = [];

  @override
  Future<CurrentTerms?> getCurrentTerms({required int participantId}) async =>
      terms;

  @override
  Future<void> postTermsConsent({
    required int participantId,
    required int termsVersionId,
    required String status,
    required String appVersion,
  }) async {
    if (postError != null) throw postError!;
    posted.add(status);
  }

  @override
  void dispose() {}
}

CurrentTerms _terms({String? termsLink}) => CurrentTerms(
      id: 3,
      version: '1.0',
      title: 'Terms of Service',
      bodyMarkdown: '# Heading\n\nBody paragraph text.',
      termsLink: termsLink,
      consent: const TermsConsent(status: null, accepted: false),
    );

Widget _app(_FakeService service, {bool gateMode = false}) {
  return ProviderScope(
    overrides: [
      participantIdProvider.overrideWith((ref) => 19),
      leaderboardApiServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: themeWithExtensions(),
      home: TermsScreen(gateMode: gateMode),
    ),
  );
}

void main() {
  // Consent posts stamp the app version. Without this the plugin's platform
  // channel never answers under the test binding and the post never fires.
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'crypto_mobile_app',
      packageName: 'org.usernodelabs.app',
      version: '3.2.1',
      buildNumber: '1210',
      buildSignature: '',
    );
  });

  group('TermsScreen', () {
    testWidgets('renders the markdown body and both decisions', (tester) async {
      await tester.pumpWidget(_app(_FakeService(terms: _terms())));
      await tester.pumpAndSettle();

      expect(find.text('Heading'), findsOneWidget);
      expect(find.text('Body paragraph text.'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Refuse'), findsOneWidget);
    });

    testWidgets('hides the full-terms link when there is no link',
        (tester) async {
      await tester.pumpWidget(_app(_FakeService(terms: _terms())));
      await tester.pumpAndSettle();

      expect(find.text('View full terms'), findsNothing);
    });

    testWidgets('shows the full-terms link when the backend supplies one',
        (tester) async {
      await tester.pumpWidget(_app(
        _FakeService(terms: _terms(termsLink: 'https://example.com/terms')),
      ));
      await tester.pumpAndSettle();

      expect(find.text('View full terms'), findsOneWidget);
    });

    // A successful submit invalidates the provider, which re-renders the
    // shimmer placeholder — an animation that never settles. So these pump
    // explicitly rather than using pumpAndSettle.
    testWidgets('Accept posts an acceptance', (tester) async {
      final service = _FakeService(terms: _terms());
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accept'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(service.posted, ['accepted']);
    });

    testWidgets('Refuse posts a refusal', (tester) async {
      final service = _FakeService(terms: _terms());
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Refuse'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(service.posted, ['refused']);
    });

    testWidgets('surfaces a failed submission and stays put', (tester) async {
      final service = _FakeService(
        terms: _terms(),
        postError: LeaderboardApiException(422, 'Not published'),
      );
      await tester.pumpWidget(_app(service, gateMode: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accept'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Could not save your response. Please try again.'),
          findsOneWidget);
      // The buttons must come back so the user can retry rather than be stuck
      // behind a gate with no exit.
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Refuse'), findsOneWidget);
    });

    testWidgets('reports when nothing is published', (tester) async {
      await tester.pumpWidget(_app(_FakeService(terms: null)));
      await tester.pumpAndSettle();

      expect(
          find.text('There are no terms to review right now.'), findsOneWidget);
    });

    testWidgets('gate mode offers no back affordance', (tester) async {
      await tester
          .pumpWidget(_app(_FakeService(terms: _terms()), gateMode: true));
      await tester.pumpAndSettle();

      expect(find.byType(BackButton), findsNothing);
      final popScope = tester.widget<PopScope>(find.byType(PopScope).first);
      expect(popScope.canPop, false);
    });
  });
}
