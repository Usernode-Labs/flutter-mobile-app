import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../design_system.dart';

WidgetbookComponent zkIdentityStepIllustrationComponent() {
  return WidgetbookComponent(
    name: 'ZkIdentityStepIllustration',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final stepIndex = context.knobs.int.slider(
            label: 'Step (0=Check, 1=Confirm, 2=Ready, 3=Verify, 4=Result)',
            initialValue: 0,
            min: 0,
            max: 4,
          );

          return Center(
            child: ZkIdentityStepIllustration(
              stepIndex: stepIndex,
            ),
          );
        },
      ),
    ],
  );
}
