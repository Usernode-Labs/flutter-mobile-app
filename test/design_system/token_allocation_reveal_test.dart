import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/ds_test_helpers.dart';

void main() {
  group('TokenAllocationReveal', () {
    testWidgets('hidden state shows label and reveal button, not the amount',
        (tester) async {
      await tester.pumpWidget(wrap(
        const TokenAllocationReveal(amount: '1,250'),
      ));

      expect(find.text('Token Allocation'), findsOneWidget);
      expect(find.text('Reveal'), findsOneWidget);
      expect(find.text('1,250'), findsNothing);
      expect(find.text('UNODE'), findsNothing);
    });

    testWidgets('pressing reveal fires onReveal and reveals the amount',
        (tester) async {
      var revealCount = 0;
      await tester.pumpWidget(wrap(
        TokenAllocationReveal(
          amount: '1,250',
          onReveal: () => revealCount++,
        ),
      ));

      await tester.tap(find.text('Reveal'));
      await tester.pumpAndSettle();

      expect(revealCount, 1);
      expect(find.text('1,250'), findsOneWidget);
      expect(find.text('UNODE'), findsOneWidget);
      expect(find.text('Reveal'), findsNothing);
    });

    testWidgets('reveal button is gone after reveal so onReveal fires once',
        (tester) async {
      var revealCount = 0;
      await tester.pumpWidget(wrap(
        TokenAllocationReveal(
          amount: '1,250',
          onReveal: () => revealCount++,
        ),
      ));

      await tester.tap(find.text('Reveal'));
      await tester.pumpAndSettle();

      expect(revealCount, 1);
      expect(find.text('Reveal'), findsNothing);
    });

    testWidgets('revealed: true renders the settled state without a tap',
        (tester) async {
      await tester.pumpWidget(wrap(
        const TokenAllocationReveal(amount: '1,250', revealed: true),
      ));

      expect(find.text('1,250'), findsOneWidget);
      expect(find.text('Reveal'), findsNothing);
    });

    testWidgets('custom labels and unit are rendered', (tester) async {
      await tester.pumpWidget(wrap(
        const TokenAllocationReveal(
          amount: '980',
          unitLabel: 'PTS',
          label: 'Season 2 Allocation',
          revealLabel: 'Show reward',
          revealed: true,
        ),
      ));

      expect(find.text('Season 2 Allocation'), findsOneWidget);
      expect(find.text('980'), findsOneWidget);
      expect(find.text('PTS'), findsOneWidget);
    });
  });
}
