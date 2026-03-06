import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/zk_identity_flow_page.dart';

WidgetbookComponent zkIdentityFlowPageComponent() {
  return WidgetbookComponent(
    name: 'ZkIdentityFlowPage',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final stepCount = context.knobs.int.slider(
            label: 'Step Count',
            initialValue: 5,
            min: 2,
            max: 7,
          );

          final currentStepIndex = context.knobs.int.slider(
            label: 'Current Step Index',
            initialValue: 1,
            min: 0,
            max: stepCount - 1,
          );

          final hasFailure = context.knobs.boolean(
            label: 'Show Failed Step',
            initialValue: false,
          );

          final steps = List.generate(stepCount, (i) {
            final ZkIdentityStepVisualStatus status;
            if (i < currentStepIndex) {
              status = ZkIdentityStepVisualStatus.completed;
            } else if (i == currentStepIndex) {
              status = hasFailure
                  ? ZkIdentityStepVisualStatus.failed
                  : ZkIdentityStepVisualStatus.active;
            } else {
              status = ZkIdentityStepVisualStatus.pending;
            }

            return ZkIdentityStepData(
              label: _stepLabels[i % _stepLabels.length],
              description: _stepDescriptions[i % _stepDescriptions.length],
              status: status,
            );
          });

          return ZkIdentityFlowPage(
            title: 'ZK Identity Verification',
            steps: steps,
            currentStepIndex: currentStepIndex,
            activeStepContent: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      hasFailure
                          ? 'Something went wrong'
                          : 'Action area for step ${currentStepIndex + 1}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {},
                      child: Text(hasFailure ? 'Retry' : 'Continue'),
                    ),
                  ],
                ),
              ),
            ),
            onBack: () {},
          );
        },
      ),
    ],
  );
}

const _stepLabels = [
  'Check ZK Passport App',
  'Confirm Passport Scanned',
  'Ready to Verify',
  'Verification',
  'Result',
  'Bonus Step',
  'Final Step',
];

const _stepDescriptions = [
  'Ensure the ZK Passport app is installed on your device.',
  'Confirm you have scanned your passport in the ZK Passport app.',
  'Review and confirm you are ready to start the verification.',
  'Zero-knowledge proof is being generated and verified.',
  'View the outcome of your identity verification.',
  'An optional additional step.',
  'The final step in the flow.',
];
