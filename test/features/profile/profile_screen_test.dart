import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/profile/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _appTheme() {
  final cie = ColorIsExpensiveTheme(ThemeData.light().textTheme);
  return cie.light().copyWith(
        extensions: DesignSystemTheme.standardExtensions(
          semanticColors: AppSemanticColors.light(),
        ),
      );
}

Widget _wrap() {
  return ProviderScope(
    child: MaterialApp(
      theme: _appTheme(),
      home: const ProfileScreen(),
    ),
  );
}

void main() {
  group('ProfileScreen (draft)', () {
    testWidgets('renders the token allocation card hidden by default',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Token Allocation'), findsOneWidget);
      expect(find.text('Reveal'), findsOneWidget);
      expect(find.text('1,250'), findsNothing);
    });

    testWidgets('revealing shows the mocked amount', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reveal'));
      await tester.pumpAndSettle();

      expect(find.text('1,250'), findsOneWidget);
      expect(find.text('UNODE'), findsOneWidget);
      expect(find.text('Reveal'), findsNothing);
    });
  });
}
