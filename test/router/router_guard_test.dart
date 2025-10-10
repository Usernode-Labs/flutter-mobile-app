import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/routing/app_router.dart';
import 'package:crypto_mobile_app/core/di/providers.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/screens/single_account_onboarding_screen.dart';
import 'package:crypto_mobile_app/app/main_app.dart';
import 'package:crypto_mobile_app/gen_l10n/app_localizations.dart';

void main() {
  testWidgets('router guard sends user without account to onboarding', (tester) async {
    final container = ProviderContainer(overrides: [
      hasAnyAccountProvider.overrideWith((ref) async => false),
    ]);
    addTearDown(container.dispose);

    final router = container.read(appRouterProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(SingleAccountOnboardingScreen), findsOneWidget);
  });

  testWidgets('router guard sends user with account to main', (tester) async {
    final container = ProviderContainer(overrides: [
      hasAnyAccountProvider.overrideWith((ref) async => true),
    ]);
    addTearDown(container.dispose);

    final router = container.read(appRouterProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();

    // MainApp should be present via ShellRoute
    expect(find.byType(MainApp), findsOneWidget);
  });
}
