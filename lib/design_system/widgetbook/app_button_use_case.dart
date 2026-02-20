import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/core/widgets/app_button.dart';

WidgetbookComponent appButtonComponent() {
  return WidgetbookComponent(
    name: 'AppButton',
    useCases: [
      WidgetbookUseCase(
        name: 'Filled',
        builder: (context) => Center(
          child: AppButton.filled(
            label: context.knobs.string(
              label: 'Label',
              initialValue: 'Continue',
            ),
            onPressed: context.knobs.boolean(
              label: 'Enabled',
              initialValue: true,
            )
                ? () {}
                : null,
            isLoading: context.knobs.boolean(
              label: 'Loading',
              initialValue: false,
            ),
            icon: context.knobs.boolean(
              label: 'Show Icon',
              initialValue: false,
            )
                ? Icons.arrow_forward
                : null,
            size: context.knobs.object.dropdown<AppButtonSize>(
              label: 'Size',
              options: AppButtonSize.values,
              initialOption: AppButtonSize.regular,
              labelBuilder: (size) => size.name,
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Outlined',
        builder: (context) => Center(
          child: AppButton.outlined(
            label: context.knobs.string(
              label: 'Label',
              initialValue: 'Cancel',
            ),
            onPressed: context.knobs.boolean(
              label: 'Enabled',
              initialValue: true,
            )
                ? () {}
                : null,
            size: context.knobs.object.dropdown<AppButtonSize>(
              label: 'Size',
              options: AppButtonSize.values,
              initialOption: AppButtonSize.regular,
              labelBuilder: (size) => size.name,
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Text',
        builder: (context) => Center(
          child: AppButton.text(
            label: context.knobs.string(
              label: 'Label',
              initialValue: 'Learn More',
            ),
            onPressed: () {},
          ),
        ),
      ),
    ],
  );
}
