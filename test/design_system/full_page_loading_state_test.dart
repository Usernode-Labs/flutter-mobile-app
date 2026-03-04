import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/ds_test_helpers.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: Scaffold(body: child),
    );
  }

  group('FullPageLoadingState', () {
    testWidgets('renders centered CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(wrap(const FullPageLoadingState()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Center), findsWidgets);
    });
  });
}
