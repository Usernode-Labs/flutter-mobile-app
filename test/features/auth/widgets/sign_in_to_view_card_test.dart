import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/auth/widgets/sign_in_to_view_card.dart';

import '../../../design_system/helpers/ds_test_helpers.dart';

void main() {
  testWidgets('renders the sign-in prompt and routes to the auth landing',
      (tester) async {
    String? visited;
    final router = GoRouter(
      initialLocation: '/x',
      routes: [
        GoRoute(
          path: '/x',
          builder: (context, state) => const Scaffold(body: SignInToViewCard()),
        ),
        GoRoute(
          path: AppRoutes.authLanding,
          builder: (context, state) {
            visited = AppRoutes.authLanding;
            return const Scaffold(body: Text('landing'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: themeWithExtensions(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in to view your progress'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(visited, AppRoutes.authLanding);
  });
}
