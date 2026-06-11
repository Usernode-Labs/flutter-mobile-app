import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/zk_identity_flow_page.dart';

part 'zk_identity_flow_page.stories.g.dart';

const meta = Meta<ZkIdentityFlowPage>(path: 'pages/zk-identity');

final $StepOne = _Story(
  name: 'Step 1 \u2013 Active',
  args: _Args(
    steps: Arg.fixed([
      const ZkIdentityStepData(
        label: 'Generate Key',
        description:
            'A cryptographic key pair is generated on your device. This never leaves your phone.',
        status: ZkIdentityStepVisualStatus.active,
      ),
      const ZkIdentityStepData(
        label: 'Create Proof',
        description: 'Generate a zero-knowledge proof of your identity.',
        status: ZkIdentityStepVisualStatus.pending,
      ),
      const ZkIdentityStepData(
        label: 'Submit',
        description: 'Submit your proof to the network for verification.',
        status: ZkIdentityStepVisualStatus.pending,
      ),
    ]),
    currentStepIndex: Arg.fixed(0),
    centerActiveContent: BoolArg(false),
    activeStepContent: Arg.fixed(null),
    bottomAction: Arg.fixed(
      FilledButton(onPressed: () {}, child: const Text('Generate Key')),
    ),
    onBack: Arg.fixed(() {}),
  ),
  scenarios: [
    _Scenario(
      name: 'First Step Active',
      args: _Args(
        steps: Arg.fixed([
          const ZkIdentityStepData(
            label: 'Generate Key',
            description:
                'A cryptographic key pair is generated on your device.',
            status: ZkIdentityStepVisualStatus.active,
          ),
          const ZkIdentityStepData(
            label: 'Create Proof',
            description: 'Generate a zero-knowledge proof of your identity.',
            status: ZkIdentityStepVisualStatus.pending,
          ),
          const ZkIdentityStepData(
            label: 'Submit',
            description: 'Submit your proof to the network for verification.',
            status: ZkIdentityStepVisualStatus.pending,
          ),
        ]),
        currentStepIndex: Arg.fixed(0),
      ),
    ),
    _Scenario(
      name: 'Middle Step In Progress',
      args: _Args(
        steps: Arg.fixed([
          const ZkIdentityStepData(
            label: 'Generate Key',
            description: 'Key pair generated successfully.',
            status: ZkIdentityStepVisualStatus.completed,
          ),
          const ZkIdentityStepData(
            label: 'Create Proof',
            description: 'Generate a zero-knowledge proof of your identity.',
            status: ZkIdentityStepVisualStatus.active,
          ),
          const ZkIdentityStepData(
            label: 'Submit',
            description: 'Submit your proof to the network for verification.',
            status: ZkIdentityStepVisualStatus.pending,
          ),
        ]),
        currentStepIndex: Arg.fixed(1),
      ),
    ),
    _Scenario(
      name: 'All Completed',
      args: _Args(
        steps: Arg.fixed([
          const ZkIdentityStepData(
            label: 'Generate Key',
            description: 'Key pair generated successfully.',
            status: ZkIdentityStepVisualStatus.completed,
          ),
          const ZkIdentityStepData(
            label: 'Create Proof',
            description: 'Proof generated successfully.',
            status: ZkIdentityStepVisualStatus.completed,
          ),
          const ZkIdentityStepData(
            label: 'Submit',
            description: 'Proof submitted and verified.',
            status: ZkIdentityStepVisualStatus.completed,
          ),
        ]),
        currentStepIndex: Arg.fixed(2),
      ),
    ),
    _Scenario(
      name: 'Step Failed',
      args: _Args(
        steps: Arg.fixed([
          const ZkIdentityStepData(
            label: 'Generate Key',
            description: 'Key pair generated successfully.',
            status: ZkIdentityStepVisualStatus.completed,
          ),
          const ZkIdentityStepData(
            label: 'Create Proof',
            description: 'Proof generation failed. Please try again.',
            status: ZkIdentityStepVisualStatus.failed,
          ),
          const ZkIdentityStepData(
            label: 'Submit',
            description: 'Submit your proof to the network for verification.',
            status: ZkIdentityStepVisualStatus.pending,
          ),
        ]),
        currentStepIndex: Arg.fixed(1),
      ),
    ),
  ],
);

final $StepTwoInProgress = _Story(
  name: 'Step 2 \u2013 In Progress',
  args: _Args(
    steps: Arg.fixed([
      const ZkIdentityStepData(
        label: 'Generate Key',
        description: 'Key pair generated successfully.',
        status: ZkIdentityStepVisualStatus.completed,
      ),
      const ZkIdentityStepData(
        label: 'Create Proof',
        description: 'Generate a zero-knowledge proof of your identity.',
        status: ZkIdentityStepVisualStatus.active,
      ),
      const ZkIdentityStepData(
        label: 'Submit',
        description: 'Submit your proof to the network for verification.',
        status: ZkIdentityStepVisualStatus.pending,
      ),
    ]),
    currentStepIndex: Arg.fixed(1),
    centerActiveContent: BoolArg(false),
    activeStepContent: Arg.fixed(
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(),
          SizedBox(height: 12),
          Text('Generating proof... this may take a moment.'),
        ],
      ),
    ),
    bottomAction: Arg.fixed(null),
    onBack: Arg.fixed(() {}),
  ),
);

final $Completed = _Story(
  name: 'All Completed',
  args: _Args(
    steps: Arg.fixed([
      const ZkIdentityStepData(
        label: 'Generate Key',
        description: 'Key pair generated successfully.',
        status: ZkIdentityStepVisualStatus.completed,
      ),
      const ZkIdentityStepData(
        label: 'Create Proof',
        description: 'Proof generated successfully.',
        status: ZkIdentityStepVisualStatus.completed,
      ),
      const ZkIdentityStepData(
        label: 'Submit',
        description: 'Proof submitted and verified.',
        status: ZkIdentityStepVisualStatus.completed,
      ),
    ]),
    currentStepIndex: Arg.fixed(2),
    centerActiveContent: BoolArg(true),
    activeStepContent: Arg.fixed(
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 64, color: Colors.green),
          SizedBox(height: 16),
          Text(
            'Identity Verified',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Your zero-knowledge identity has been confirmed on-chain.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
    bottomAction: Arg.fixed(
      FilledButton(onPressed: () {}, child: const Text('Done')),
    ),
    onBack: Arg.fixed(() {}),
  ),
);

final $Failed = _Story(
  name: 'Step Failed',
  args: _Args(
    steps: Arg.fixed([
      const ZkIdentityStepData(
        label: 'Generate Key',
        description: 'Key pair generated successfully.',
        status: ZkIdentityStepVisualStatus.completed,
      ),
      const ZkIdentityStepData(
        label: 'Create Proof',
        description: 'Proof generation failed. Please try again.',
        status: ZkIdentityStepVisualStatus.failed,
      ),
      const ZkIdentityStepData(
        label: 'Submit',
        description: 'Submit your proof to the network for verification.',
        status: ZkIdentityStepVisualStatus.pending,
      ),
    ]),
    currentStepIndex: Arg.fixed(1),
    centerActiveContent: BoolArg(false),
    activeStepContent: Arg.fixed(null),
    bottomAction: Arg.fixed(
      FilledButton(onPressed: () {}, child: const Text('Retry')),
    ),
    onBack: Arg.fixed(() {}),
  ),
);
