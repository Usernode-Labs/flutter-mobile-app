import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/core/widgets/app_action_button.dart';

WidgetbookComponent appActionButtonComponent() {
  return WidgetbookComponent(
    name: 'AppActionButton',
    useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) {
          final showBadge = context.knobs.boolean(
            label: 'Show Badge',
            initialValue: false,
          );
          final size = context.knobs.object.dropdown<AppActionButtonSize>(
            label: 'Size',
            options: AppActionButtonSize.values,
            initialOption: AppActionButtonSize.regular,
            labelBuilder: (s) => s.name,
          );

          return Center(
            child: AppActionButton(
              icon: Icons.send,
              label: context.knobs.string(
                label: 'Label',
                initialValue: 'Send',
              ),
              onTap: () {},
              badge: showBadge ? '3' : null,
              size: size,
            ),
          );
        },
      ),
      WidgetbookUseCase(
        name: 'Action Row',
        builder: (context) => Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              AppActionButton(
                icon: Icons.send,
                label: 'Send',
                onTap: () {},
              ),
              AppActionButton(
                icon: Icons.call_received,
                label: 'Receive',
                onTap: () {},
              ),
              AppActionButton(
                icon: Icons.swap_horiz,
                label: 'Swap',
                onTap: () {},
                badge: '2',
              ),
              AppActionButton(
                icon: Icons.history,
                label: 'History',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
