import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import '../design_system.dart';

WidgetbookComponent zkIdentityStatusCardComponent() {
  return WidgetbookComponent(
    name: 'ZkIdentityStatusCard',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final showFaceMatch = context.knobs.boolean(
            label: 'Show Face Match',
            initialValue: true,
          );

          final showDate = context.knobs.boolean(
            label: 'Show Verified Date',
            initialValue: true,
          );

          final showProofId = context.knobs.boolean(
            label: 'Show Proof ID',
            initialValue: true,
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ZkIdentityStatusCard(
              data: ZkIdentityStatusData(
                steps: [
                  const ZkIdentityStatusStep(
                    icon: Symbols.check_circle_sharp,
                    label: 'Uniqueness',
                    value: 'Confirmed',
                  ),
                  if (showFaceMatch)
                    const ZkIdentityStatusStep(
                      icon: Symbols.face_sharp,
                      label: 'Face check',
                      value: 'Verified',
                    ),
                  const ZkIdentityStatusStep(
                    icon: Symbols.shield_sharp,
                    label: 'Privacy',
                    value: 'Nothing shared',
                  ),
                  if (showDate)
                    const ZkIdentityStatusStep(
                      icon: Symbols.calendar_today_sharp,
                      label: 'Verified',
                      value: 'Mar 10, 2026',
                    ),
                  if (showProofId)
                    const ZkIdentityStatusStep(
                      icon: Symbols.fingerprint_sharp,
                      label: 'Proof ID',
                      value: '0x1a2b3c...9f0e',
                      monospace: true,
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
