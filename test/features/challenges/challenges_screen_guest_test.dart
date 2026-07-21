import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/features/auth/widgets/sign_in_to_view_card.dart';
import 'package:crypto_mobile_app/features/challenges/screens/challenges_screen.dart';

import '../../design_system/helpers/ds_test_helpers.dart';

void main() {
  testWidgets('challenges screen shows the sign-in gate for a guest',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // A guest session: the gate short-circuits build() before any data
          // provider is read.
          showSignInGateProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: themeWithExtensions(),
          home: const ChallengesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SignInToViewCard), findsOneWidget);
    expect(find.text('Sign in to view your progress'), findsOneWidget);
  });
}
