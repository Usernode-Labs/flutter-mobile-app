import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'helpers/ds_test_helpers.dart';

void main() {
  group('StatusBadge', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(wrap(
        const StatusBadge(
          label: 'Active',
          variant: StatusBadgeVariant.success,
        ),
      ));

      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('success variant uses semantic success colors', (tester) async {
      await tester.pumpWidget(wrap(
        const StatusBadge(
          label: 'Active',
          variant: StatusBadgeVariant.success,
        ),
      ));

      final theme = themeWithExtensions();
      final semantic = theme.extension<AppSemanticColors>()!;
      final text = tester.widget<Text>(find.text('Active'));
      expect(text.style?.color, semantic.success.color);
    });

    testWidgets('error variant uses error colors', (tester) async {
      await tester.pumpWidget(wrap(
        const StatusBadge(
          label: 'Failed',
          variant: StatusBadgeVariant.error,
        ),
      ));

      final theme = themeWithExtensions();
      final text = tester.widget<Text>(find.text('Failed'));
      expect(text.style?.color, theme.colorScheme.error);
    });

    testWidgets('warning variant uses flash colors', (tester) async {
      await tester.pumpWidget(wrap(
        const StatusBadge(
          label: 'Syncing',
          variant: StatusBadgeVariant.warning,
        ),
      ));

      final theme = themeWithExtensions();
      final semantic = theme.extension<AppSemanticColors>()!;
      final text = tester.widget<Text>(find.text('Syncing'));
      expect(text.style?.color, semantic.flash.color);
    });

    testWidgets('info variant uses technical colors', (tester) async {
      await tester.pumpWidget(wrap(
        const StatusBadge(
          label: 'Info',
          variant: StatusBadgeVariant.info,
        ),
      ));

      final theme = themeWithExtensions();
      final semantic = theme.extension<AppSemanticColors>()!;
      final text = tester.widget<Text>(find.text('Info'));
      expect(text.style?.color, semantic.technical.color);
    });

    testWidgets('neutral variant uses outline colors', (tester) async {
      await tester.pumpWidget(wrap(
        const StatusBadge(
          label: 'Pending',
          variant: StatusBadgeVariant.neutral,
        ),
      ));

      final theme = themeWithExtensions();
      final text = tester.widget<Text>(find.text('Pending'));
      expect(text.style?.color, theme.colorScheme.outline);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(wrap(
        const StatusBadge(
          label: 'Active',
          variant: StatusBadgeVariant.success,
          icon: Symbols.check_circle_sharp,
        ),
      ));

      expect(find.byIcon(Symbols.check_circle_sharp), findsOneWidget);
    });

    testWidgets('hides icon when not provided', (tester) async {
      await tester.pumpWidget(wrap(
        const StatusBadge(
          label: 'Active',
          variant: StatusBadgeVariant.success,
        ),
      ));

      expect(find.byType(Icon), findsNothing);
    });
  });
}
