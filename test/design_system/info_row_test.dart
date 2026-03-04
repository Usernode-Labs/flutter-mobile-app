import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/ds_test_helpers.dart';

void main() {
  group('InfoRow', () {
    testWidgets('renders label and value', (tester) async {
      await tester.pumpWidget(wrap(
        const InfoRow(label: 'Epoch', value: '176'),
      ));

      expect(find.text('Epoch'), findsOneWidget);
      expect(find.text('176'), findsOneWidget);
    });

    testWidgets('shows divider by default', (tester) async {
      await tester.pumpWidget(wrap(
        const InfoRow(label: 'Key', value: 'Value'),
      ));

      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('hides divider when showDivider is false', (tester) async {
      await tester.pumpWidget(wrap(
        const InfoRow(label: 'Key', value: 'Value', showDivider: false),
      ));

      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('renders trailing widget when provided', (tester) async {
      await tester.pumpWidget(wrap(
        const InfoRow(
          label: 'Hash',
          value: '0xabc...',
          trailing: Icon(Icons.copy),
        ),
      ));

      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('wraps in InkWell when onTap is provided', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        InfoRow(
          label: 'Key',
          value: 'Value',
          onTap: () => tapped = true,
        ),
      ));

      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });

    testWidgets('no InkWell when onTap is null', (tester) async {
      await tester.pumpWidget(wrap(
        const InfoRow(label: 'Key', value: 'Value'),
      ));

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('applies custom valueStyle', (tester) async {
      const style = TextStyle(fontFamily: 'monospace', fontSize: 14);
      await tester.pumpWidget(wrap(
        const InfoRow(label: 'Hash', value: '0xabc', valueStyle: style),
      ));

      final text = tester.widget<Text>(find.text('0xabc'));
      expect(text.style?.fontFamily, 'monospace');
    });

    testWidgets('applies custom contentPadding', (tester) async {
      await tester.pumpWidget(wrap(
        const InfoRow(
          label: 'Key',
          value: 'Value',
          contentPadding: EdgeInsets.all(24),
        ),
      ));

      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(padding.padding, const EdgeInsets.all(24));
    });
  });
}
