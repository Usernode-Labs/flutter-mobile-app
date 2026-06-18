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

  testWidgets('node pill resolves the status word and icon to match the bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        TopStatusPill.node(
          status: TopStatusNodeStatus.connecting,
          onPressed: () {},
        ),
      ),
    );

    expect(find.text('Connecting'), findsOneWidget);
    expect(find.byIcon(Symbols.sync_sharp), findsOneWidget);
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
    expect(find.byIcon(Symbols.check_circle_sharp), findsOneWidget);
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
