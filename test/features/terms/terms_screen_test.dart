import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/features/terms/providers/terms_provider.dart';
import 'package:crypto_mobile_app/features/terms/screens/terms_screen.dart';

import '../../design_system/helpers/ds_test_helpers.dart';

class _FakeService extends LeaderboardApiService {
  _FakeService(this.terms);

  CurrentTerms terms;
  final List<String> posted = [];
  int fetches = 0;

  @override
  Future<CurrentTerms?> getCurrentTerms({
    required AuthenticatedUserLease authority,
  }) async {
    fetches++;
    return terms;
  }

  @override
  Future<void> postTermsConsent({
    required int termsVersionId,
    required String appVersion,
    required AuthenticatedUserLease authority,
  }) async {
    posted.add(TermsConsentStatus.accepted);
  }

  @override
  void dispose() {}
}

AuthenticatedUserLease _owner() {
  const identity = Identity(
    epoch: 7,
    phase: IdentityPhase.ready,
    participantId: 1,
    accountId: 'account-1',
    address: 'address-1',
  );
  IdentitySnapshots.publish(identity);
  return AuthenticatedUserLease.capture(identity)!;
}

CurrentTerms _terms({required bool accepted}) => CurrentTerms(
      id: 3,
      version: '1.0',
      title: 'Terms',
      termsLink: 'https://example.com/terms',
      consent: TermsConsent(
        status: accepted ? TermsConsentStatus.accepted : null,
        accepted: accepted,
      ),
    );

ProviderContainer _container(_FakeService service) => ProviderContainer(
      overrides: [
        isAuthenticatedProvider.overrideWithValue(true),
        authenticatedUserLeaseProvider.overrideWithValue(_owner()),
        showSignInGateProvider.overrideWithValue(false),
        leaderboardApiServiceProvider.overrideWithValue(service),
      ],
    );

Widget _app(_FakeService service, {bool signedIn = true}) => ProviderScope(
      overrides: [
        isAuthenticatedProvider.overrideWithValue(signedIn),
        authenticatedUserLeaseProvider.overrideWithValue(
          signedIn ? _owner() : null,
        ),
        showSignInGateProvider.overrideWithValue(!signedIn),
        leaderboardApiServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: themeWithExtensions(),
        home: TermsScreen(
          webViewBuilder: (url) => Center(child: Text(url)),
        ),
      ),
    );

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'app',
      packageName: 'org.example.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('unaccepted user can accept and cannot refuse', (tester) async {
    final service = _FakeService(_terms(accepted: false));
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Refuse'), findsNothing);
    expect(find.text('https://example.com/terms'), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(service.posted, [TermsConsentStatus.accepted]);
  });

  // Regression: the provider deliberately returns null for guests (its
  // watchDeps gate), which used to render as "no terms published" — a
  // misleading empty state. Guests must get the standard sign-in gate.
  testWidgets('guest sees the sign-in gate, not "no terms published"',
      (tester) async {
    await tester.pumpWidget(
        _app(_FakeService(_terms(accepted: false)), signedIn: false));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('There are no terms to review right now.'), findsNothing);
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets('accepted user sees final status without an action',
      (tester) async {
    await tester.pumpWidget(_app(_FakeService(_terms(accepted: true))));
    await tester.pumpAndSettle();

    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Refuse'), findsNothing);
  });

  // Regression: currentTermsProvider is not autoDispose, so a session that
  // cached "accepted" keeps it forever. When a new version is published the
  // ranking endpoint gates the allocation, but this screen — the only way to
  // clear that gate — would render the stale "Accepted" footer and no button,
  // stranding the user until they force-quit.
  testWidgets('refetches on mount so stale consent cannot hide the button',
      (tester) async {
    final service = _FakeService(_terms(accepted: true));
    final container = _container(service);
    addTearDown(container.dispose);

    // A session that already loaded the old, accepted version.
    await container.read(currentTermsProvider.future);
    expect(service.fetches, 1);

    // Backend publishes a new version: consent no longer applies.
    service.terms = _terms(accepted: false);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: themeWithExtensions(),
          home: TermsScreen(
            webViewBuilder: (url) => Center(child: Text(url)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.fetches, 2);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Accepted'), findsNothing);
  });
}
