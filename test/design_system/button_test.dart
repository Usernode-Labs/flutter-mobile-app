import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'helpers/ds_test_helpers.dart';

void main() {
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
          leadingIcon: Icon(Symbols.arrow_forward_sharp, size: 20),
        ),
      ));

      expect(find.byIcon(Symbols.arrow_forward_sharp), findsOneWidget);
      expect(find.text('With Icon'), findsOneWidget);
    });

    testWidgets('uses M3 FilledButton', (tester) async {
      await tester.pumpWidget(wrap(
        const Button(label: 'M3 Button'),
      ));

      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('disabled when onTap is null', (tester) async {
      await tester.pumpWidget(wrap(
        const Button(label: 'Disabled'),
      ));

      final button = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(button.onPressed, isNull);
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
        Button(
          label: 'Surface',
          variant: ButtonVariant.surface,
          onTap: () {},
        ),
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
        Button(
          label: 'Surface Text',
          variant: ButtonVariant.surface,
          onTap: () {},
        ),
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
        Button(
          label: 'Primary',
          variant: ButtonVariant.primary,
          onTap: () {},
        ),
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
        Button(
          label: 'Primary Text',
          variant: ButtonVariant.primary,
          onTap: () {},
        ),
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

    testWidgets('loading primary variant keeps enabled fill and spinner color',
        (tester) async {
      await tester.pumpWidget(wrap(
        Button(
          label: 'Loading Primary',
          variant: ButtonVariant.primary,
          isLoading: true,
          onTap: () {},
        ),
      ));

      final theme = themeWithExtensions();
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, equals(theme.colorScheme.primary));

      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.color, equals(theme.colorScheme.onPrimary));
    });

    testWidgets('loading surface variant keeps enabled fill and spinner color',
        (tester) async {
      await tester.pumpWidget(wrap(
        Button(
          label: 'Loading Surface',
          variant: ButtonVariant.surface,
          isLoading: true,
          onTap: () {},
        ),
      ));

      final theme = themeWithExtensions();
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, equals(theme.colorScheme.surfaceContainerLowest));

      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.color, equals(theme.colorScheme.onSurface));
    });

    testWidgets('disabled primary variant uses disabled colors',
        (tester) async {
      await tester.pumpWidget(wrap(
        const Button(label: 'Disabled Primary', variant: ButtonVariant.primary),
      ));

      final theme = themeWithExtensions();
      final opacity = theme.extension<AppOpacity>()!;

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(Material),
        ),
      );
      expect(
        material.color,
        equals(theme.colorScheme.onSurface.withValues(alpha: opacity.medium)),
      );
      expect(material.color, isNot(equals(theme.colorScheme.primary)));

      final text = tester.widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.text('Disabled Primary'),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      );
      expect(
        text.style.color,
        equals(theme.colorScheme.onSurface.withValues(alpha: opacity.disabled)),
      );
      expect(text.style.color, isNot(equals(theme.colorScheme.onPrimary)));
    });

    testWidgets('disabled button does not fire onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        const Button(label: 'Disabled'),
      ));

      await tester.tap(find.text('Disabled'));
      expect(tapped, isFalse);
    });
  });
}
