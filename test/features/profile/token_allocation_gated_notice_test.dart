import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

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

      expect(find.text('Indicative token allocation'), findsOneWidget);
      expect(
        find.text(
          'Your allocation is indicative and based on your Season 1 '
          'contributions. It is not a promise or entitlement. Any future '
          'distribution is conditional on mainnet launch, eligibility '
          'verification, acceptance of the applicable Usernode Testnet '
          'Program Terms, and remains subject to the company’s discretion.',
        ),
        findsOneWidget,
      );
      // The whole point: a forced 0 must never read as a real balance.
      expect(find.text('0'), findsNothing);
      expect(find.byIcon(Symbols.warning_amber_sharp), findsOneWidget);
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
  });
}
