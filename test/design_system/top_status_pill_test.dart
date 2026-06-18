import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'helpers/ds_test_helpers.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('profile pill renders icon-only and fires onPressed', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(TopStatusPill.profile(onPressed: () => taps++)),
    );

    expect(find.byIcon(Symbols.account_circle_sharp), findsOneWidget);
    await tester.tap(find.byType(TopStatusPill));
    expect(taps, 1);
  });

  testWidgets('node pill resolves canonical status words icons and surfaces', (
    tester,
  ) async {
    Future<void> pumpStatus(TopStatusNodeStatus status) {
      return tester.pumpWidget(
        wrap(
          TopStatusPill.node(
            status: status,
            onPressed: () {},
          ),
        ),
      );
    }

    await pumpStatus(TopStatusNodeStatus.synced);

    final theme = Theme.of(tester.element(find.byType(TopStatusPill)));
    final colors = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;
    final cases = [
      (
        status: TopStatusNodeStatus.synced,
        label: 'Synced',
        icon: Symbols.check_sharp,
        background: semantic.success.colorContainer,
        foreground: semantic.success.onColorContainer,
      ),
      (
        status: TopStatusNodeStatus.connecting,
        label: 'Connecting',
        icon: Symbols.hourglass_empty_sharp,
        background: semantic.warning.colorContainer,
        foreground: semantic.warning.onColorContainer,
      ),
      (
        status: TopStatusNodeStatus.syncing,
        label: 'Syncing',
        icon: Symbols.hourglass_empty_sharp,
        background: semantic.warning.colorContainer,
        foreground: semantic.warning.onColorContainer,
      ),
      (
        status: TopStatusNodeStatus.offline,
        label: 'Offline',
        icon: Symbols.close_sharp,
        background: colors.errorContainer,
        foreground: colors.onErrorContainer,
      ),
    ];

    for (final testCase in cases) {
      await pumpStatus(testCase.status);

      final visual = tester
          .widgetList<Material>(
            find.descendant(
              of: find.byType(TopStatusPill),
              matching: find.byType(Material),
            ),
          )
          .last;
      final icon = tester.widget<Icon>(find.byIcon(testCase.icon));

      expect(find.text(testCase.label), findsOneWidget);
      expect(find.byIcon(testCase.icon), findsOneWidget);
      expect(visual.color, equals(testCase.background));
      expect(icon.color, equals(testCase.foreground));
    }
  });

  testWidgets('node pill honours an explicit empty label (icon-only)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        TopStatusPill.node(
          status: TopStatusNodeStatus.synced,
          onPressed: () {},
          label: '',
        ),
      ),
    );

    expect(find.text('Synced'), findsNothing);
    expect(find.byIcon(Symbols.check_sharp), findsOneWidget);
  });

  testWidgets('keeps a >=48dp tap target', (tester) async {
    await tester.pumpWidget(
      wrap(TopStatusPill.profile(onPressed: () {})),
    );

    final size = tester.getSize(find.byType(TopStatusPill));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
  });
}
