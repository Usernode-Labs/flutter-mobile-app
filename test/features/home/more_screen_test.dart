import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:crypto_mobile_app/features/home/screens/more_screen.dart';

import '../../design_system/helpers/ds_test_helpers.dart';

void main() {
  late String? pushed;

  Widget app() {
    pushed = null;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const MoreScreen()),
        GoRoute(
          path: AppRoutes.profile,
          builder: (_, __) {
            pushed = AppRoutes.profile;
            return const SizedBox();
          },
        ),
        GoRoute(
          path: AppRoutes.restoreRegistration,
          builder: (_, __) {
            pushed = AppRoutes.restoreRegistration;
            return const SizedBox();
          },
        ),
      ],
    );
    return ProviderScope(
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: themeWithExtensions(),
        routerConfig: router,
      ),
    );
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MoreScreen)));

  testWidgets('lists Profile, Node Status, Restore registration and Settings',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    for (final label in [
      'Profile',
      'Node Status',
      'Restore registration',
      'Settings',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  // Node Status and Settings are sibling IndexedStack pages, so they switch
  // tabs rather than push — that keeps their "am I active?" listeners working.
  testWidgets('Node Status and Settings switch tabs', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Node Status'));
    await tester.pump();
    expect(
        containerOf(tester).read(currentHomeTabProvider), HomeTab.nodeStatus);

    await tester.tap(find.text('Settings'));
    await tester.pump();
    expect(containerOf(tester).read(currentHomeTabProvider), HomeTab.settings);
  });

  testWidgets('Profile pushes its route', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(pushed, AppRoutes.profile);
  });

  // The replacement for the removed "Onboarding has evolved" dialog. It must
  // live outside /onboarding/*, which the router bounces to /home once an
  // account exists and onboarding is complete.
  testWidgets('Restore registration pushes a non-onboarding route',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restore registration'));
    await tester.pumpAndSettle();

    expect(pushed, AppRoutes.restoreRegistration);
    expect(AppRoutes.restoreRegistration, isNot(startsWith('/onboarding/')));
  });
}
