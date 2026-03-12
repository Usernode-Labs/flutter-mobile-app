import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'helpers/ds_test_helpers.dart';

void main() {
  Widget wrap(Widget child) {
    final theme = themeWithExtensions();
    final semantic = AppSemanticColors.light();
    final catColors = semantic.community;

    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: DecoratedBox(
              decoration: BoxDecoration(color: catColors.color),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  const onColor = Colors.white;
  final dimOnColor = Colors.white.withValues(alpha: 0.8);

  group('ZkProofDetailSection', () {
    testWidgets('renders heading and description', (tester) async {
      await tester.pumpWidget(wrap(
        ZkProofDetailSection(
          heading: 'Your Proof',
          description: 'Your passport was verified.',
          onColor: onColor,
          dimOnColor: dimOnColor,
        ),
      ));

      expect(find.text('Your Proof'), findsOneWidget);
      expect(find.text('Your passport was verified.'), findsOneWidget);
    });

    testWidgets('renders rows with labels and values', (tester) async {
      await tester.pumpWidget(wrap(
        ZkProofDetailSection(
          heading: 'Your Proof',
          description: 'Description text.',
          onColor: onColor,
          dimOnColor: dimOnColor,
          rows: const [
            (
              icon: Symbols.check_circle_sharp,
              label: 'Status',
              value: 'Valid Passport',
              monospace: false,
              onTap: null,
            ),
            (
              icon: Symbols.fingerprint_sharp,
              label: 'Proof ID',
              value: '0x1234...abcd',
              monospace: true,
              onTap: null,
            ),
          ],
        ),
      ));

      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Valid Passport'), findsOneWidget);
      expect(find.text('Proof ID'), findsOneWidget);
      expect(find.text('0x1234...abcd'), findsOneWidget);
    });

    testWidgets('renders no rows section when rows is empty', (tester) async {
      await tester.pumpWidget(wrap(
        ZkProofDetailSection(
          heading: 'Heading',
          description: 'Desc',
          onColor: onColor,
          dimOnColor: dimOnColor,
        ),
      ));

      // Only heading + description, no Row widgets for data
      expect(find.text('Heading'), findsOneWidget);
      expect(find.text('Desc'), findsOneWidget);
    });

    testWidgets('monospace row uses mono font family', (tester) async {
      await tester.pumpWidget(wrap(
        ZkProofDetailSection(
          heading: 'Proof',
          description: 'Desc',
          onColor: onColor,
          dimOnColor: dimOnColor,
          rows: const [
            (
              icon: Symbols.fingerprint_sharp,
              label: 'ID',
              value: '0xABCD',
              monospace: true,
              onTap: null,
            ),
          ],
        ),
      ));

      final valueWidget = tester.widget<Text>(find.text('0xABCD'));
      expect(valueWidget.style?.fontFamily, equals(kMonoFontFamily));
    });

    testWidgets('non-monospace row does not use mono font family',
        (tester) async {
      await tester.pumpWidget(wrap(
        ZkProofDetailSection(
          heading: 'Proof',
          description: 'Desc',
          onColor: onColor,
          dimOnColor: dimOnColor,
          rows: const [
            (
              icon: Symbols.check_circle_sharp,
              label: 'Status',
              value: 'Valid',
              monospace: false,
              onTap: null,
            ),
          ],
        ),
      ));

      final valueWidget = tester.widget<Text>(find.text('Valid'));
      expect(valueWidget.style?.fontFamily, isNot(equals(kMonoFontFamily)));
    });

    testWidgets('tappable row shows copy icon and invokes callback',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        ZkProofDetailSection(
          heading: 'Proof',
          description: 'Desc',
          onColor: onColor,
          dimOnColor: dimOnColor,
          rows: [
            (
              icon: Symbols.fingerprint_sharp,
              label: 'Proof ID',
              value: '0xABCD',
              monospace: true,
              onTap: () => tapped = true,
            ),
          ],
        ),
      ));

      // Copy icon should be visible
      expect(find.byIcon(Icons.content_copy), findsOneWidget);

      // Tap the row
      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });

    testWidgets('golden', (tester) async {
      await tester.pumpWidget(wrap(
        ZkProofDetailSection(
          heading: 'Your Proof',
          description:
              'Your passport was verified using a zero-knowledge proof. '
              'No personal data was shared or stored.',
          onColor: onColor,
          dimOnColor: dimOnColor,
          rows: const [
            (
              icon: Symbols.check_circle_sharp,
              label: 'Status',
              value: 'Valid Passport',
              monospace: false,
              onTap: null,
            ),
            (
              icon: Symbols.shield_sharp,
              label: 'Privacy',
              value: 'No data shared',
              monospace: false,
              onTap: null,
            ),
            (
              icon: Symbols.calendar_today_sharp,
              label: 'Verified',
              value: 'Mar 9, 2026',
              monospace: false,
              onTap: null,
            ),
            (
              icon: Symbols.fingerprint_sharp,
              label: 'Proof ID',
              value: '0x1a2b3c4d...ef01',
              monospace: true,
              onTap: null,
            ),
          ],
        ),
      ));

      await expectLater(
        find.byType(ZkProofDetailSection),
        matchesGoldenFile('goldens/zk_proof_detail_section.png'),
      );
    });
  });
}
