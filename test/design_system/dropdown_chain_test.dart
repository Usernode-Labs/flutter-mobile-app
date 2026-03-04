import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'helpers/ds_test_helpers.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 360, child: child),
        ),
      ),
    );
  }

  group('DropdownChain', () {
    testWidgets('renders all labels', (tester) async {
      await tester.pumpWidget(wrap(
        DropdownChain(items: const [
          DropdownChainItem(label: 'Season 2'),
          DropdownChainItem(label: 'DApps Integration'),
        ]),
      ));

      expect(find.text('Season 2'), findsOneWidget);
      expect(find.text('DApps Integration'), findsOneWidget);
    });

    testWidgets('renders chevron separator between items', (tester) async {
      await tester.pumpWidget(wrap(
        DropdownChain(items: const [
          DropdownChainItem(label: 'Season 2'),
          DropdownChainItem(label: 'DApps Integration'),
        ]),
      ));

      expect(find.byIcon(Symbols.chevron_right_sharp), findsOneWidget);
    });

    testWidgets('renders N-1 chevrons for N items', (tester) async {
      await tester.pumpWidget(wrap(
        DropdownChain(items: const [
          DropdownChainItem(label: 'A'),
          DropdownChainItem(label: 'B'),
          DropdownChainItem(label: 'C'),
        ]),
      ));

      expect(find.byIcon(Symbols.chevron_right_sharp), findsNWidgets(2));
    });

    testWidgets('no chevron for single item', (tester) async {
      await tester.pumpWidget(wrap(
        DropdownChain(items: const [
          DropdownChainItem(label: 'Season 2'),
        ]),
      ));

      expect(find.byIcon(Symbols.chevron_right_sharp), findsNothing);
      expect(find.text('Season 2'), findsOneWidget);
    });

    testWidgets('fires onTap for first item', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        DropdownChain(items: [
          DropdownChainItem(label: 'Season 2', onTap: () => tapped = true),
          const DropdownChainItem(label: 'DApps Integration'),
        ]),
      ));

      await tester.tap(find.text('Season 2'));
      expect(tapped, isTrue);
    });

    testWidgets('fires onTap for last item', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        DropdownChain(items: [
          const DropdownChainItem(label: 'Season 2'),
          DropdownChainItem(
              label: 'DApps Integration', onTap: () => tapped = true),
        ]),
      ));

      await tester.tap(find.text('DApps Integration'));
      expect(tapped, isTrue);
    });

    testWidgets('last chip expands to fill remaining width', (tester) async {
      await tester.pumpWidget(wrap(
        DropdownChain(items: const [
          DropdownChainItem(label: 'Season 2'),
          DropdownChainItem(label: 'DApps Integration'),
        ]),
      ));

      // Find the two DropdownChip widgets
      final chips = tester.widgetList<DropdownChip>(find.byType(DropdownChip));
      final chipList = chips.toList();

      // First chip should not be expanded
      expect(chipList[0].expanded, isFalse);
      // Last chip should be expanded
      expect(chipList[1].expanded, isTrue);
    });

    testWidgets('single item is expanded', (tester) async {
      await tester.pumpWidget(wrap(
        DropdownChain(items: const [
          DropdownChainItem(label: 'Season 2'),
        ]),
      ));

      final chip = tester.widget<DropdownChip>(find.byType(DropdownChip).first);
      expect(chip.expanded, isTrue);
    });
  });
}
