import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/identity/session_host.dart';
import 'package:crypto_mobile_app/main.dart';

void main() {
  testWidgets('App smoke test - builds without errors',
      (WidgetTester tester) async {
    // Build the app widget
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionHostLifecycleProvider.overrideWithValue(
            const InlineSessionHostLifecycle(),
          ),
        ],
        child: const CryptoMobileApp(),
      ),
    );

    // Verify the app builds without throwing errors
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test('Simple unit test', () {
    // Basic unit test to ensure test framework works
    expect(1 + 1, equals(2));
  });
}
