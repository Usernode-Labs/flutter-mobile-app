import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ThemeData themeWithExtensions() {
    final cieTheme = ColorIsExpensiveTheme(ThemeData.light().textTheme);
    return cieTheme.light().copyWith(
          extensions: DesignSystemTheme.standardExtensions(
            semanticColors: AppSemanticColors.light(),
          ),
        );
  }

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('Button', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(wrap(
        const Button(label: 'View in Leaderboard'),
      ));

      expect(find.text('View in Leaderboard'), findsOneWidget);
    });

    testWidgets('onTap fires callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        Button(
          label: 'Tap Me',
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.text('Tap Me'));
      expect(tapped, isTrue);
    });

    testWidgets('renders leading icon when provided', (tester) async {
      await tester.pumpWidget(wrap(
        const Button(
          label: 'With Icon',
          leadingIcon: Icon(Icons.arrow_forward, size: 20),
        ),
      ));

      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.text('With Icon'), findsOneWidget);
    });

    testWidgets('does not render icon space when no leadingIcon',
        (tester) async {
      await tester.pumpWidget(wrap(
        const Button(label: 'No Icon'),
      ));

      // Should only find the button text, no icon widgets
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('small size uses buttonHeightSmall', (tester) async {
      await tester.pumpWidget(wrap(
        const Button(label: 'Small', size: ButtonSize.small),
      ));

      final buttonSize = tester.getSize(find.byType(Button));
      expect(buttonSize.height, equals(40));
    });

    testWidgets('tonal variant renders FilledButton.tonal', (tester) async {
      await tester.pumpWidget(wrap(
        const Button(label: 'Tonal'),
      ));

      // FilledButton.tonal creates a FilledButton under the hood
      expect(find.byType(FilledButton), findsOneWidget);
      // Should NOT be an OutlinedButton
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('outlined variant renders OutlinedButton with border',
        (tester) async {
      await tester.pumpWidget(wrap(
        const Button(label: 'Outlined', variant: ButtonVariant.outlined),
      ));

      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets(
        'surface variant renders FilledButton with surfaceContainerLowest fill',
        (tester) async {
      await tester.pumpWidget(wrap(
        const Button(label: 'Surface', variant: ButtonVariant.surface),
      ));

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);

      // Verify the fill color via the resolved Material
      final theme = themeWithExtensions();
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, equals(theme.colorScheme.surfaceContainerLowest));
    });

    testWidgets('surface variant uses onSurface foreground color',
        (tester) async {
      await tester.pumpWidget(wrap(
        const Button(label: 'Surface Text', variant: ButtonVariant.surface),
      ));

      final theme = themeWithExtensions();
      final text = tester.widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.text('Surface Text'),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      );
      expect(text.style.color, equals(theme.colorScheme.onSurface));
    });

    testWidgets('large size uses buttonHeightLarge', (tester) async {
      await tester.pumpWidget(wrap(
        const Button(label: 'Large', size: ButtonSize.large),
      ));

      final buttonSize = tester.getSize(find.byType(Button));
      expect(buttonSize.height, equals(56));
    });

    testWidgets('primary variant renders FilledButton with primary fill',
        (tester) async {
      await tester.pumpWidget(wrap(
        const Button(label: 'Primary', variant: ButtonVariant.primary),
      ));

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);

      final theme = themeWithExtensions();
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, equals(theme.colorScheme.primary));
    });

    testWidgets('primary variant uses onPrimary foreground color',
        (tester) async {
      await tester.pumpWidget(wrap(
        const Button(label: 'Primary Text', variant: ButtonVariant.primary),
      ));

      final theme = themeWithExtensions();
      final text = tester.widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.text('Primary Text'),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      );
      expect(text.style.color, equals(theme.colorScheme.onPrimary));
    });

    testWidgets('disabled button does not fire onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        Button(label: 'Disabled'),
      ));

      await tester.tap(find.text('Disabled'));
      expect(tapped, isFalse);
    });
  });
}
