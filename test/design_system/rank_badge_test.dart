import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/ds_test_helpers.dart';

void main() {
  group('RankBadge', () {
    testWidgets('renders rank text', (tester) async {
      await tester.pumpWidget(wrap(const RankBadge(rank: '#1')));

      expect(find.text('#1'), findsOneWidget);
    });

    testWidgets('renders different rank values', (tester) async {
      await tester.pumpWidget(wrap(const RankBadge(rank: '999')));

      expect(find.text('999'), findsOneWidget);
    });

    testWidgets('has 40px dimensions from AppSizing.iconContainerSmall',
        (tester) async {
      await tester.pumpWidget(wrap(const RankBadge(rank: '#1')));

      final renderBox = tester.renderObject<RenderBox>(find.byType(RankBadge));
      expect(renderBox.size.width, 40.0);
      expect(renderBox.size.height, 40.0);
    });

    testWidgets('uses circular shape', (tester) async {
      await tester.pumpWidget(wrap(const RankBadge(rank: '#1')));

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('has outlineVariant border', (tester) async {
      await tester.pumpWidget(wrap(const RankBadge(rank: '#1')));

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull);
    });

    testWidgets('works as ListTile leading', (tester) async {
      await tester.pumpWidget(wrap(
        const ListTile(
          leading: RankBadge(rank: '#1'),
          title: Text('username'),
          trailing: Text('10,000 pts'),
        ),
      ));

      expect(find.byType(RankBadge), findsOneWidget);
      expect(find.text('username'), findsOneWidget);
      expect(find.text('10,000 pts'), findsOneWidget);
    });
  });
}
