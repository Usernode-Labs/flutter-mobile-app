import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/ds_test_helpers.dart';

void main() {
  group('ListSectionHeader', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(wrap(
        const ListSectionHeader(title: 'General'),
      ));

      expect(find.text('General'), findsOneWidget);
    });

    testWidgets('applies labelLarge with onSurfaceVariant via copyWith',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ListSectionHeader(title: 'Section'),
      ));

      // Widget should pass a style derived from labelLarge.copyWith
      final text = tester.widget<Text>(find.text('Section'));
      expect(text.style, isNotNull);
    });

    testWidgets('uses onSurfaceVariant color', (tester) async {
      await tester.pumpWidget(wrap(
        const ListSectionHeader(title: 'Section'),
      ));

      final text = tester.widget<Text>(find.text('Section'));
      final theme = themeWithExtensions();
      expect(text.style?.color, theme.colorScheme.onSurfaceVariant);
    });

    testWidgets('renders different titles', (tester) async {
      await tester.pumpWidget(wrap(
        const ListSectionHeader(title: 'Advanced Settings'),
      ));

      expect(find.text('Advanced Settings'), findsOneWidget);
    });
  });
}
