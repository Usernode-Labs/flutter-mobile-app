import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/dapp_avatar.dart';

WidgetbookComponent dappAvatarComponent() {
  return WidgetbookComponent(
    name: 'DappAvatar',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final seed = context.knobs.string(
            label: 'Seed',
            initialValue: 'Swap Protocol',
          );

          return Center(
            child: DappAvatar(seed: seed, size: 48),
          );
        },
      ),
    ],
  );
}
