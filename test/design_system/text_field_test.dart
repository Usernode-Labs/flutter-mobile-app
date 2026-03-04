import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'helpers/ds_test_helpers.dart';

void main() {
  group('DSTextField', () {
    testWidgets('renders with label', (tester) async {
      await tester.pumpWidget(wrap(
        const DSTextField(label: 'Email'),
      ));

      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('renders hint text', (tester) async {
      await tester.pumpWidget(wrap(
        const DSTextField(hint: 'Enter email'),
      ));

      expect(find.text('Enter email'), findsOneWidget);
    });

    testWidgets('renders helper text', (tester) async {
      await tester.pumpWidget(wrap(
        const DSTextField(helperText: 'We will never share your email'),
      ));

      expect(find.text('We will never share your email'), findsOneWidget);
    });

    testWidgets('renders error text', (tester) async {
      await tester.pumpWidget(wrap(
        const DSTextField(errorText: 'Invalid email'),
      ));

      expect(find.text('Invalid email'), findsOneWidget);
    });

    testWidgets('renders prefix icon', (tester) async {
      await tester.pumpWidget(wrap(
        const DSTextField(
          prefixIcon: Icon(Symbols.email_sharp),
        ),
      ));

      expect(find.byIcon(Symbols.email_sharp), findsOneWidget);
    });

    testWidgets('renders suffix icon', (tester) async {
      await tester.pumpWidget(wrap(
        const DSTextField(
          suffixIcon: Icon(Symbols.visibility_sharp),
        ),
      ));

      expect(find.byIcon(Symbols.visibility_sharp), findsOneWidget);
    });

    testWidgets('fires onChanged callback', (tester) async {
      String? changedValue;
      await tester.pumpWidget(wrap(
        DSTextField(onChanged: (v) => changedValue = v),
      ));

      await tester.enterText(find.byType(TextFormField), 'hello');
      expect(changedValue, 'hello');
    });

    testWidgets('disabled field does not accept input', (tester) async {
      await tester.pumpWidget(wrap(
        const DSTextField(enabled: false, label: 'Disabled'),
      ));

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.enabled, isFalse);
    });

    testWidgets('uses TextFormField underneath', (tester) async {
      await tester.pumpWidget(wrap(
        const DSTextField(),
      ));

      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('obscureText hides input', (tester) async {
      await tester.pumpWidget(wrap(
        const DSTextField(obscureText: true),
      ));

      // Verify the EditableText within has obscureText set
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.obscureText, isTrue);
    });
  });
}
