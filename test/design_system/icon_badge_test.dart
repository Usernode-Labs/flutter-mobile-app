import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'helpers/ds_test_helpers.dart';

void main() {
  group('IconBadge', () {
    testWidgets('renders icon', (tester) async {
      await tester.pumpWidget(wrap(
        const IconBadge(icon: Symbols.star_sharp),
      ));

      expect(find.byIcon(Symbols.star_sharp), findsOneWidget);
    });

    testWidgets('defaults to 48px outer container', (tester) async {
      await tester.pumpWidget(wrap(
        const IconBadge(icon: Symbols.star_sharp),
      ));

      final box = tester.getSize(find.byType(IconBadge));
      expect(box.width, 48.0);
      expect(box.height, 48.0);
    });

    testWidgets('custom size overrides outer container', (tester) async {
      await tester.pumpWidget(wrap(
        const IconBadge(icon: Symbols.star_sharp, size: 64),
      ));

      final box = tester.getSize(find.byType(IconBadge));
      expect(box.width, 64.0);
      expect(box.height, 64.0);
    });

    testWidgets('applies custom backgroundColor', (tester) async {
      await tester.pumpWidget(wrap(
        const IconBadge(
          icon: Symbols.star_sharp,
          backgroundColor: Colors.red,
        ),
      ));

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, Colors.red);
    });

    testWidgets('applies custom iconColor', (tester) async {
      await tester.pumpWidget(wrap(
        const IconBadge(
          icon: Symbols.star_sharp,
          iconColor: Colors.blue,
        ),
      ));

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, Colors.blue);
    });

    testWidgets('applies custom borderRadius', (tester) async {
      await tester.pumpWidget(wrap(
        IconBadge(
          icon: Symbols.star_sharp,
          borderRadius: BorderRadius.circular(8),
        ),
      ));

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(8));
    });

    testWidgets('works as ListTile leading', (tester) async {
      await tester.pumpWidget(wrap(
        const ListTile(
          leading: IconBadge(icon: Symbols.wallet_sharp),
          title: Text('Wallet'),
        ),
      ));

      expect(find.byType(IconBadge), findsOneWidget);
      expect(find.text('Wallet'), findsOneWidget);
    });
  });
}
