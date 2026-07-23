import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/auth/data/models/me.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/features/challenges/screens/challenges_gate_screen.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:crypto_mobile_app/features/home/screens/home_screen.dart';
import 'package:crypto_mobile_app/features/challenges/screens/challenges_screen.dart';

import '../../design_system/helpers/ds_test_helpers.dart';

Me _me({bool isInWaitlist = false}) => Me(
      id: 1,
      email: 'a@b.c',
      emailConfirmed: true,
      level: UserLevel.member,
      isInWaitlist: isInWaitlist,
    );

void main() {
  Widget app(UserLevel level, {Me? me}) => ProviderScope(
        overrides: [
          meProvider.overrideWith((ref) async => me),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: themeWithExtensions(),
          home: ChallengesGateScreen(level: level),
        ),
      );

  testWidgets('guest sees a sign-in prompt with a CTA', (tester) async {
    await tester.pumpWidget(app(UserLevel.guest));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to unlock challenges'), findsOneWidget);
    expect(find.text('Sign in or sign up'), findsOneWidget);
  });

  testWidgets('member not on the waiting list is invited to join',
      (tester) async {
    await tester.pumpWidget(app(UserLevel.member, me: _me()));
    await tester.pumpAndSettle();

    expect(find.text('Join the waiting list'), findsOneWidget);
    // No auth CTA — they are already signed in.
    expect(find.text('Sign in or sign up'), findsNothing);
  });

  testWidgets('member already on the waiting list is told so', (tester) async {
    await tester.pumpWidget(app(UserLevel.member, me: _me(isInWaitlist: true)));
    await tester.pumpAndSettle();

    expect(find.text('You are on the waiting list'), findsOneWidget);
  });

  // Until /me resolves we must not claim a place the user may not have.
  testWidgets('member defaults to the join wording before /me resolves',
      (tester) async {
    await tester.pumpWidget(app(UserLevel.member));
    await tester.pump();

    expect(find.text('Join the waiting list'), findsOneWidget);
    expect(find.text('You are on the waiting list'), findsNothing);
  });

  group('page selection', () {
    test('only operators get the real ChallengesScreen', () {
      expect(homePagesFor(UserLevel.operator)[HomeTab.challenges.index],
          isA<ChallengesScreen>());
      for (final level in [UserLevel.guest, UserLevel.member]) {
        expect(homePagesFor(level)[HomeTab.challenges.index],
            isA<ChallengesGateScreen>(),
            reason: level.name);
      }
    });
  });
}
