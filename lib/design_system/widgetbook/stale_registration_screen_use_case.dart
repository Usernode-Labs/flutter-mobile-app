import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../design_system.dart';

WidgetbookComponent staleRegistrationScreenComponent() {
  return WidgetbookComponent(
    name: 'StaleRegistrationScreen',
    useCases: [
      _preview(),
    ],
  );
}

WidgetbookUseCase _preview() {
  return WidgetbookUseCase(
    name: 'Preview',
    builder: (context) {
      final title = context.knobs.string(
        label: 'Title',
        initialValue: 'Registration Expired',
      );
      final body = context.knobs.string(
        label: 'Body',
        initialValue:
            "Your registration is from a previous season. Blocks produced "
            "with old credentials won't earn points. Please contact the "
            "team on Discord for assistance.",
      );
      final actionLabel = context.knobs.string(
        label: 'Action Label',
        initialValue: 'Contact us on Discord',
      );

      final theme = Theme.of(context);
      final spacing = theme.extension<AppSpacing>()!;

      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(spacing.space24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                SizedBox(height: spacing.space24),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: spacing.space16),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                Button(
                  label: actionLabel,
                  variant: ButtonVariant.primary,
                  size: ButtonSize.large,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
