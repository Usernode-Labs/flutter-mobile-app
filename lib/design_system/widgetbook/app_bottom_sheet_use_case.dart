import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/core/widgets/app_bottom_sheet.dart';

WidgetbookComponent appBottomSheetComponent() {
  return WidgetbookComponent(
    name: 'AppBottomSheet',
    useCases: [
      WidgetbookUseCase(
        name: 'Content Preview',
        builder: (context) {
          final showSubtitle = context.knobs.boolean(
            label: 'Show Subtitle',
            initialValue: true,
          );

          // Render the bottom sheet content directly (not as a modal)
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: AppBottomSheet(
              title: context.knobs.string(
                label: 'Title',
                initialValue: 'Select Option',
              ),
              subtitle: showSubtitle ? 'Choose from the list below' : null,
              showCloseButton: context.knobs.boolean(
                label: 'Show Close Button',
                initialValue: true,
              ),
              child: ListView(
                shrinkWrap: true,
                children: const [
                  ListTile(
                    leading: Icon(Icons.account_balance_wallet),
                    title: Text('Wallet A'),
                    subtitle: Text('0x1234...5678'),
                  ),
                  ListTile(
                    leading: Icon(Icons.account_balance_wallet),
                    title: Text('Wallet B'),
                    subtitle: Text('0xabcd...efgh'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );
}
