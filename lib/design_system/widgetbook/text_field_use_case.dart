import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/text_field.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent textFieldComponent() {
  return WidgetbookComponent(
    name: 'DSTextField',
    useCases: [
      _playground(),
      _states(),
    ],
  );
}

WidgetbookUseCase _playground() {
  return WidgetbookUseCase(
    name: 'Playground',
    builder: (context) {
      final label = context.knobs.string(
        label: 'Label',
        initialValue: 'Amount',
      );
      final hint = context.knobs.string(
        label: 'Hint',
        initialValue: 'Enter amount',
      );
      final showError = context.knobs.boolean(
        label: 'Show Error',
        initialValue: false,
      );

      return Padding(
        padding: const EdgeInsets.all(16),
        child: DSTextField(
          label: label,
          hint: hint,
          errorText: showError ? 'Invalid amount' : null,
          prefixIcon: const Icon(Icons.attach_money),
        ),
      );
    },
  );
}

WidgetbookUseCase _states() {
  return WidgetbookUseCase(
    name: 'States',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DSTextField(
              label: 'Default',
              hint: 'Enter value',
            ),
            SizedBox(height: spacing.space16),
            const DSTextField(
              label: 'With Helper',
              hint: 'Enter address',
              helperText: 'Paste your wallet address',
              prefixIcon: Icon(Icons.account_balance_wallet),
            ),
            SizedBox(height: spacing.space16),
            const DSTextField(
              label: 'Error State',
              errorText: 'Address is invalid',
              prefixIcon: Icon(Icons.error_outline),
            ),
            SizedBox(height: spacing.space16),
            const DSTextField(
              label: 'Disabled',
              hint: 'Cannot edit',
              enabled: false,
            ),
            SizedBox(height: spacing.space16),
            const DSTextField(
              label: 'Password',
              hint: 'Enter password',
              obscureText: true,
              prefixIcon: Icon(Icons.lock),
              suffixIcon: Icon(Icons.visibility_off),
            ),
          ],
        ),
      );
    },
  );
}
