import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';

void main() {
  Widget buildApp(ZkIdentityStatusData data) {
    final textTheme = ThemeData.light().textTheme;
    final cieTheme = ColorIsExpensiveTheme(textTheme);
    final themeData = cieTheme.light().copyWith(
          extensions: DesignSystemTheme.standardExtensions(
            semanticColors: AppSemanticColors.light(),
          ),
        );

    return MaterialApp(
      theme: themeData,
      home: Scaffold(
        body: ZkIdentityStatusCard(data: data),
      ),
    );
  }

  group('ZkIdentityStatusCard', () {
    testWidgets('renders all step labels and values', (tester) async {
      const data = ZkIdentityStatusData(
        steps: [
          ZkIdentityStatusStep(
            icon: Symbols.check_circle_sharp,
            label: 'Status',
            value: 'Valid Passport',
          ),
          ZkIdentityStatusStep(
            icon: Symbols.shield_sharp,
            label: 'Privacy',
            value: 'No data shared',
          ),
        ],
      );

      await tester.pumpWidget(buildApp(data));

      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Valid Passport'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('No data shared'), findsOneWidget);
    });

    testWidgets('renders monospace text for proof ID', (tester) async {
      const data = ZkIdentityStatusData(
        steps: [
          ZkIdentityStatusStep(
            icon: Symbols.fingerprint_sharp,
            label: 'Proof ID',
            value: '0x1a2b...9f0e',
            monospace: true,
          ),
        ],
      );

      await tester.pumpWidget(buildApp(data));

      final textWidget = tester.widget<Text>(find.text('0x1a2b...9f0e'));
      expect(textWidget.style?.fontFamily, kMonoFontFamily);
    });

    testWidgets('non-monospace text does not use mono font', (tester) async {
      const data = ZkIdentityStatusData(
        steps: [
          ZkIdentityStatusStep(
            icon: Symbols.check_circle_sharp,
            label: 'Status',
            value: 'Valid Passport',
          ),
        ],
      );

      await tester.pumpWidget(buildApp(data));

      final textWidget = tester.widget<Text>(find.text('Valid Passport'));
      expect(textWidget.style?.fontFamily, isNot(kMonoFontFamily));
    });

    testWidgets('onTap callback fires when tapping a row', (tester) async {
      var tapped = false;

      final data = ZkIdentityStatusData(
        steps: [
          ZkIdentityStatusStep(
            icon: Symbols.fingerprint_sharp,
            label: 'Proof ID',
            value: '0x1a2b...9f0e',
            monospace: true,
            onTap: () => tapped = true,
          ),
        ],
      );

      await tester.pumpWidget(buildApp(data));

      await tester.tap(find.text('Proof ID'));
      await tester.pumpAndSettle();

      expect(tapped, true);
    });

    testWidgets('renders empty card when no steps', (tester) async {
      const data = ZkIdentityStatusData(steps: []);

      await tester.pumpWidget(buildApp(data));

      // Card should render without error.
      expect(find.byType(ZkIdentityStatusCard), findsOneWidget);
    });
  });
}
