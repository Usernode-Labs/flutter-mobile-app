import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/dapp_card.dart';

WidgetbookComponent dappCardComponent() {
  return WidgetbookComponent(
    name: 'DappCard',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final name = context.knobs.string(
            label: 'Name',
            initialValue: 'Swap Protocol',
          );

          final author = context.knobs.string(
            label: 'Author',
            initialValue: 'Usernode Labs',
          );

          final description = context.knobs.string(
            label: 'Description',
            initialValue:
                'A decentralized application on the Usernode network.',
          );

          final users = context.knobs.intOrNull.input(
            label: 'Users',
            initialValue: 1234,
          );

          final txns = context.knobs.intOrNull.input(
            label: 'Transactions',
            initialValue: 5678,
          );

          final enabled = context.knobs.boolean(
            label: 'Enabled',
            initialValue: true,
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: DappCard(
              name: name,
              author: author,
              description: description,
              users: users,
              txns: txns,
              enabled: enabled,
              disabledLabel: enabled ? null : 'Coming',
              onTap: () {},
            ),
          );
        },
      ),
    ],
  );
}
