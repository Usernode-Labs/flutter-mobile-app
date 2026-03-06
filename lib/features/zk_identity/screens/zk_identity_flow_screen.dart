import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/zk_identity/models/zk_identity_models.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';

class ZkIdentityFlowScreen extends ConsumerWidget {
  const ZkIdentityFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flowState = ref.watch(zkIdentityStepControllerProvider);
    final pipelineState = ref.watch(zkPassportPipelineProvider);

    final steps = flowState.steps.map((s) {
      return ZkIdentityStepData(
        label: _stepLabel(s.step),
        description: _stepDescription(s.step),
        status: s.status,
      );
    }).toList();

    return ZkIdentityFlowPage(
      title: ZkIdentityChallengeConfig.instance.title,
      steps: steps,
      currentStepIndex: flowState.currentStepIndex,
      activeStepContent: _buildActiveContent(
        context,
        ref,
        flowState,
        pipelineState,
      ),
      onBack: () => context.pop(),
    );
  }

  Widget _buildActiveContent(
    BuildContext context,
    WidgetRef ref,
    ZkIdentityFlowState flowState,
    ZkPassportPipelineState pipelineState,
  ) {
    final controller = ref.read(zkIdentityStepControllerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return switch (flowState.currentStep) {
      ZkIdentityStep.checkApp => _CheckAppContent(
          onCheck: controller.checkAppInstalled,
          onOpenStore:
              ref.read(zkPassportLaunchServiceProvider).openStoreListing,
        ),
      ZkIdentityStep.confirmScanned => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Have you already scanned your passport in the ZK Passport app?',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('No, go back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: controller.confirmPassportScanned,
                    child: const Text('Yes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ZkIdentityStep.readyToVerify => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This will open the ZK Passport app and generate a zero-knowledge proof of your passport. The process may take a moment.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                controller.confirmReady();
                controller.triggerVerification();
              },
              child: const Text('Start Verification'),
            ),
          ],
        ),
      ZkIdentityStep.verification => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            Text(
              _pipelinePhaseText(pipelineState),
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (flowState.resultMessage != null && !flowState.isSuccess) ...[
              const SizedBox(height: 12),
              Text(
                flowState.resultMessage!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  controller.reset();
                },
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ZkIdentityStep.result => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              flowState.isSuccess
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              size: 48,
              color:
                  flowState.isSuccess ? colorScheme.primary : colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              flowState.isSuccess
                  ? 'Identity verified successfully!'
                  : 'Verification failed',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (flowState.resultMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                flowState.resultMessage!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Done'),
            ),
          ],
        ),
    };
  }

  String _stepLabel(ZkIdentityStep step) {
    return switch (step) {
      ZkIdentityStep.checkApp => 'Check ZK Passport App',
      ZkIdentityStep.confirmScanned => 'Confirm Passport Scanned',
      ZkIdentityStep.readyToVerify => 'Ready to Verify',
      ZkIdentityStep.verification => 'Verification',
      ZkIdentityStep.result => 'Result',
    };
  }

  String _stepDescription(ZkIdentityStep step) {
    return switch (step) {
      ZkIdentityStep.checkApp => 'Ensure the ZK Passport app is installed.',
      ZkIdentityStep.confirmScanned =>
        'Confirm you have scanned your passport.',
      ZkIdentityStep.readyToVerify =>
        'Review and confirm to start verification.',
      ZkIdentityStep.verification =>
        'Zero-knowledge proof generation and verification.',
      ZkIdentityStep.result => 'View the outcome of your verification.',
    };
  }

  String _pipelinePhaseText(ZkPassportPipelineState state) {
    return switch (state.phase) {
      ZkPassportPipelinePhase.idle => 'Preparing...',
      ZkPassportPipelinePhase.launching => 'Launching ZK Passport...',
      ZkPassportPipelinePhase.waiting =>
        'Waiting for proof from ZK Passport...',
      ZkPassportPipelinePhase.resuming => 'Resuming session...',
      ZkPassportPipelinePhase.proofReceived => 'Proof received, processing...',
      ZkPassportPipelinePhase.verifyingOuter => 'Verifying outer proof...',
      ZkPassportPipelinePhase.wrapping => 'Wrapping proof...',
      ZkPassportPipelinePhase.verifyingWrapped => 'Verifying wrapped proof...',
      ZkPassportPipelinePhase.success => 'Verification complete!',
      ZkPassportPipelinePhase.failed => 'Verification failed.',
      ZkPassportPipelinePhase.timedOut => 'Session timed out.',
    };
  }
}

class _CheckAppContent extends StatefulWidget {
  const _CheckAppContent({
    required this.onCheck,
    required this.onOpenStore,
  });

  final Future<bool> Function() onCheck;
  final VoidCallback onOpenStore;

  @override
  State<_CheckAppContent> createState() => _CheckAppContentState();
}

class _CheckAppContentState extends State<_CheckAppContent> {
  bool _checking = false;
  bool _notInstalled = false;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _notInstalled = false;
    });
    final installed = await widget.onCheck();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _notInstalled = !installed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'First, make sure you have the ZK Passport app installed.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (_checking)
          const Center(child: CircularProgressIndicator())
        else
          FilledButton(
            onPressed: _check,
            child: const Text('Check ZK Passport App'),
          ),
        if (_notInstalled) ...[
          const SizedBox(height: 12),
          Text(
            'ZK Passport app not found. Please install it first.',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: widget.onOpenStore,
            child: const Text('Open App Store'),
          ),
        ],
      ],
    );
  }
}
