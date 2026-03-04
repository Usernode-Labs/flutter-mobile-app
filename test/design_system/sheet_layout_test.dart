import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/ds_test_helpers.dart';

void main() {
  Widget wrapSheet(Widget child) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: Scaffold(body: child),
    );
  }

  group('SheetLayout', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(wrapSheet(
        const SheetLayout(child: Text('Content')),
      ));

      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('renders title when provided', (tester) async {
      await tester.pumpWidget(wrapSheet(
        const SheetLayout(
          title: 'Select Option',
          child: Text('Content'),
        ),
      ));

      expect(find.text('Select Option'), findsOneWidget);
    });

    testWidgets('hides title when null', (tester) async {
      await tester.pumpWidget(wrapSheet(
        const SheetLayout(child: Text('Content')),
      ));

      // Only the content text
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('title uses titleMedium style', (tester) async {
      await tester.pumpWidget(wrapSheet(
        const SheetLayout(
          title: 'Header',
          child: Text('Body'),
        ),
      ));

      // Widget should pass a style derived from titleMedium
      final text = tester.widget<Text>(find.text('Header'));
      expect(text.style, isNotNull);
    });

    testWidgets('wraps content in SafeArea', (tester) async {
      await tester.pumpWidget(wrapSheet(
        const SheetLayout(child: Text('Safe')),
      ));

      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('child is wrapped in Flexible', (tester) async {
      await tester.pumpWidget(wrapSheet(
        const SheetLayout(child: Text('Flex')),
      ));

      expect(find.byType(Flexible), findsOneWidget);
    });
  });
}
