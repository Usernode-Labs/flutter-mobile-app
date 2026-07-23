import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/features/onboarding/screens/import_api_account_screen.dart';

import '../../design_system/helpers/ds_test_helpers.dart';

void main() {
  Widget wrap(Widget child) => ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: themeWithExtensions(),
          home: child,
        ),
      );

  // Onboarding reaches this screen via a route replacement inside a linear
  // flow, so it intentionally has no back affordance.
  testWidgets('onboarding entry has no app bar', (tester) async {
    await tester.pumpWidget(wrap(const OnboardingImportApiAccountScreen()));
    await tester.pump();
    expect(find.byType(AppBar), findsNothing);
  });

  // Restore is pushed from More and must be escapable.
  testWidgets('restore entry shows an escapable app bar', (tester) async {
    await tester.pumpWidget(wrap(
      const OnboardingImportApiAccountScreen(onCompleteRoute: AppRoutes.home),
    ));
    await tester.pump();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  // Close must actually leave the screen: pop when it can, else fall back home.
  testWidgets('close pops the restore screen when pushed', (tester) async {
    String? location;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => context.push('/restore'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/restore',
          builder: (_, __) => const OnboardingImportApiAccountScreen(
            onCompleteRoute: AppRoutes.home,
          ),
        ),
      ],
    );
    router.routerDelegate.addListener(() {
      location = router.routerDelegate.currentConfiguration.uri.path;
    });

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: themeWithExtensions(),
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingImportApiAccountScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingImportApiAccountScreen), findsNothing);
    expect(location, '/');
  });
}
