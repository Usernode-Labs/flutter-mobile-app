import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/profile/widgets/token_allocation_gated_notice.dart';

import '../../design_system/helpers/ds_test_helpers.dart';

Widget _app(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: themeWithExtensions(),
      home: Scaffold(body: child),
    );

void main() {
  group('TokenAllocationGatedNotice', () {
    testWidgets('explains the withholding without showing a zero balance',
        (tester) async {
      await tester.pumpWidget(_app(
        TokenAllocationGatedNotice(onReviewTerms: () {}),
      ));

      expect(find.text('Tokens on hold'), findsOneWidget);
      expect(
        find.text(
          'Your token allocation is withheld until you accept the terms and '
          'conditions.',
        ),
        findsOneWidget,
      );
      // The whole point: a forced 0 must never read as a real balance.
      expect(find.text('0'), findsNothing);
    });

    testWidgets('review action fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(
        TokenAllocationGatedNotice(onReviewTerms: () => taps++),
      ));

      await tester.tap(find.text('Review terms'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('hides the hosted-terms link when there is none',
        (tester) async {
      await tester.pumpWidget(_app(
        TokenAllocationGatedNotice(onReviewTerms: () {}),
      ));

      expect(find.text('View full terms'), findsNothing);
    });

    testWidgets('shows the hosted-terms link when supplied', (tester) async {
      await tester.pumpWidget(_app(
        TokenAllocationGatedNotice(
          onReviewTerms: () {},
          termsLink: 'https://example.com/terms',
        ),
      ));

      expect(find.text('View full terms'), findsOneWidget);
    });
  });
}
