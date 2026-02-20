import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/core/widgets/app_text_field.dart';

WidgetbookComponent appTextFieldComponent() {
  return WidgetbookComponent(
    name: 'AppTextField',
    useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) {
          final hasError = context.knobs.boolean(
            label: 'Error State',
            initialValue: false,
          );
          final enabled = context.knobs.boolean(
            label: 'Enabled',
            initialValue: true,
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: AppTextField(
              labelText: context.knobs.string(
                label: 'Label',
                initialValue: 'Email',
              ),
              hintText: context.knobs.string(
                label: 'Hint',
                initialValue: 'Enter your email',
              ),
              helperText: context.knobs.boolean(
                label: 'Show Helper',
                initialValue: true,
              )
                  ? 'We will never share your email'
                  : null,
              errorText: hasError ? 'Invalid email address' : null,
              enabled: enabled,
              prefixIcon: context.knobs.boolean(
                label: 'Prefix Icon',
                initialValue: false,
              )
                  ? const Icon(Icons.email_outlined)
                  : null,
            ),
          );
        },
      ),
      WidgetbookUseCase(
        name: 'Password',
        builder: (context) => const Padding(
          padding: EdgeInsets.all(16),
          child: AppTextField(
            labelText: 'Password',
            hintText: 'Enter your password',
            obscureText: true,
            suffixIcon: Icon(Icons.visibility_off),
          ),
        ),
      ),
    ],
  );
}
