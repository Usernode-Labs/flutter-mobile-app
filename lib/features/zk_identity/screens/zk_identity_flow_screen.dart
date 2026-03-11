import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/zk_identity/models/zk_identity_models.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';

class ZkIdentityFlowScreen extends ConsumerStatefulWidget {
  const ZkIdentityFlowScreen({super.key});

  @override
  ConsumerState<ZkIdentityFlowScreen> createState() =>
      _ZkIdentityFlowScreenState();
}

class _ZkIdentityFlowScreenState extends ConsumerState<ZkIdentityFlowScreen>
    with WidgetsBindingObserver {
  bool _checkingApp = false;
  bool _appNotInstalled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _appNotInstalled) {
      _checkApp();
    }
  }

  Future<void> _checkApp() async {
    setState(() {
      _checkingApp = true;
      _appNotInstalled = false;
    });
    final controller = ref.read(zkIdentityStepControllerProvider.notifier);
    final installed = await controller.checkAppInstalled();
    if (!mounted) return;
    setState(() {
      _checkingApp = false;
      _appNotInstalled = !installed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final flowState = ref.watch(zkIdentityStepControllerProvider);
    final pipelineState = ref.watch(zkPassportPipelineProvider);

    // Reset local state when navigating away from checkApp step.
    if (flowState.currentStep != ZkIdentityStep.checkApp) {
      _checkingApp = false;
      _appNotInstalled = false;
    }

    final steps = flowState.steps.map((s) {
      return ZkIdentityStepData(
        label: _stepLabel(s.step),
        description: _stepDescription(s.step),
        status: s.status,
      );
    }).toList();

    return ZkIdentityFlowPage(
      steps: steps,
      currentStepIndex: flowState.currentStepIndex,
      centerActiveContent: flowState.currentStep == ZkIdentityStep.result ||
          (flowState.currentStep == ZkIdentityStep.checkApp &&
              _appNotInstalled),
      activeStepContent: _buildBody(context, flowState, pipelineState),
      bottomAction: _buildBottomAction(context, flowState, pipelineState),
      onBack: () => context.pop(),
    );
  }

  Widget? _buildBody(
    BuildContext context,
    ZkIdentityFlowState flowState,
    ZkPassportPipelineState pipelineState,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final semantic = theme.extension<AppSemanticColors>()!;

    return switch (flowState.currentStep) {
      ZkIdentityStep.checkApp => _appNotInstalled
          ? const FullPageErrorState(
              message: 'ZK Passport app not found',
              detail: 'Please install the ZK Passport app first to continue.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'First, make sure you have the ZK Passport app installed.',
                  style: textTheme.bodyMedium,
                ),
                if (_checkingApp) ...[
                  SizedBox(height: spacing.space12),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
      ZkIdentityStep.confirmScanned => Text(
          'Have you already scanned your passport in the ZK Passport app?',
          style: textTheme.bodyMedium,
        ),
      ZkIdentityStep.readyToVerify => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This will open the ZK Passport app and generate a zero-knowledge proof of your passport. The process may take a moment.',
              style: textTheme.bodyMedium,
            ),
            SizedBox(height: spacing.space16),
            for (final bullet in [
              'Your passport data never leaves your device',
              'Only proof of validity is shared',
              'No personal information stored on-chain',
            ])
              Padding(
                padding: EdgeInsets.only(bottom: spacing.space12),
                child: Row(
                  children: [
                    Icon(
                      Symbols.check_circle_sharp,
                      size: sizing.iconRegular,
                      color: semantic.success.color,
                    ),
                    SizedBox(width: spacing.space12),
                    Expanded(
                      child: Text(bullet, style: textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ZkIdentityStep.verification => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (flowState.resultMessage != null && !flowState.isSuccess) ...[
              Text(
                'Your data is safe — no information was shared.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: spacing.space8),
              Text(
                flowState.resultMessage!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ] else
              for (final task in _subTasks) ...[
                _SubTaskRow(
                  label: task.label,
                  state: task.stateFor(pipelineState.phase),
                ),
                SizedBox(height: spacing.space8),
              ],
          ],
        ),
      ZkIdentityStep.result => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              flowState.isSuccess
                  ? 'Identity Verified!'
                  : 'Verification Failed',
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.space8),
            if (flowState.isSuccess)
              Text(
                'Your identity was confirmed with zero-knowledge proof — '
                'no personal data was shared.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              )
            else ...[
              Text(
                'Your data is safe — no information was shared.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (flowState.resultMessage != null) ...[
                SizedBox(height: spacing.space8),
                Text(
                  flowState.resultMessage!,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ],
        ),
    };
  }

  Widget? _buildBottomAction(
    BuildContext context,
    ZkIdentityFlowState flowState,
    ZkPassportPipelineState pipelineState,
  ) {
    final controller = ref.read(zkIdentityStepControllerProvider.notifier);
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return switch (flowState.currentStep) {
      ZkIdentityStep.checkApp => _appNotInstalled
          ? Button(
              variant: ButtonVariant.primary,
              size: ButtonSize.large,
              label: 'Open App Store',
              onTap: ref.read(zkPassportLaunchServiceProvider).openStoreListing,
            )
          : _checkingApp
              ? null
              : Button(
                  variant: ButtonVariant.primary,
                  size: ButtonSize.large,
                  label: 'Check ZK Passport App',
                  onTap: _checkApp,
                ),
      ZkIdentityStep.confirmScanned => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Button(
              variant: ButtonVariant.primary,
              size: ButtonSize.large,
              label: 'Yes',
              onTap: controller.confirmPassportScanned,
            ),
            SizedBox(height: spacing.space8),
            Button(
              variant: ButtonVariant.outlined,
              size: ButtonSize.large,
              label: 'No, go back',
              onTap: () => context.pop(),
            ),
          ],
        ),
      ZkIdentityStep.readyToVerify => Button(
          variant: ButtonVariant.primary,
          size: ButtonSize.large,
          label: 'Start Verification',
          onTap: () {
            controller.confirmReady();
            controller.triggerVerification();
          },
        ),
      ZkIdentityStep.verification =>
        flowState.resultMessage != null && !flowState.isSuccess
            ? Button(
                variant: ButtonVariant.primary,
                size: ButtonSize.large,
                label: 'Try Again',
                onTap: controller.reset,
              )
            : (pipelineState.phase == ZkPassportPipelinePhase.waiting ||
                    pipelineState.phase == ZkPassportPipelinePhase.resuming)
                ? Button(
                    variant: ButtonVariant.tonal,
                    size: ButtonSize.large,
                    label: 'Go To ZK Passport',
                    onTap: () => launchUrl(
                      Uri.parse('zkpassport://'),
                      mode: LaunchMode.externalApplication,
                    ),
                  )
                : null,
      ZkIdentityStep.result => Button(
          variant: ButtonVariant.primary,
          size: ButtonSize.large,
          label: flowState.isSuccess ? 'Done' : 'Try Again',
          onTap: flowState.isSuccess ? () => context.pop() : controller.reset,
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
}

// ---------------------------------------------------------------------------
// Sub-task progress model for verification step
// ---------------------------------------------------------------------------

enum _SubTaskState { pending, active, done }

class _SubTask {
  const _SubTask({
    required this.label,
    required this.activePhases,
    required this.doneAfter,
  });

  final String label;
  final Set<ZkPassportPipelinePhase> activePhases;
  final Set<ZkPassportPipelinePhase> doneAfter;

  _SubTaskState stateFor(ZkPassportPipelinePhase current) {
    if (doneAfter.contains(current) || _isPastAll(current)) {
      return _SubTaskState.done;
    }
    if (activePhases.contains(current)) return _SubTaskState.active;
    return _SubTaskState.pending;
  }

  /// A phase is "past" all done-after phases when its index exceeds the max.
  bool _isPastAll(ZkPassportPipelinePhase current) {
    final idx = current.index;
    return doneAfter.every((p) => idx > p.index);
  }
}

const _subTasks = [
  _SubTask(
    label: 'Opening ZK Passport',
    activePhases: {
      ZkPassportPipelinePhase.idle,
      ZkPassportPipelinePhase.launching
    },
    doneAfter: {ZkPassportPipelinePhase.launching},
  ),
  _SubTask(
    label: 'Waiting for proof',
    activePhases: {
      ZkPassportPipelinePhase.waiting,
      ZkPassportPipelinePhase.resuming
    },
    doneAfter: {ZkPassportPipelinePhase.proofReceived},
  ),
  _SubTask(
    label: 'Verifying proof',
    activePhases: {
      ZkPassportPipelinePhase.proofReceived,
      ZkPassportPipelinePhase.verifyingOuter
    },
    doneAfter: {ZkPassportPipelinePhase.verifyingOuter},
  ),
  _SubTask(
    label: 'Wrapping proof',
    activePhases: {ZkPassportPipelinePhase.wrapping},
    doneAfter: {ZkPassportPipelinePhase.wrapping},
  ),
  _SubTask(
    label: 'Final verification',
    activePhases: {ZkPassportPipelinePhase.verifyingWrapped},
    doneAfter: {
      ZkPassportPipelinePhase.verifyingWrapped,
      ZkPassportPipelinePhase.success
    },
  ),
];

class _SubTaskRow extends StatelessWidget {
  const _SubTaskRow({required this.label, required this.state});

  final String label;
  final _SubTaskState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final sizing = theme.extension<AppSizing>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final semantic = theme.extension<AppSemanticColors>()!;

    final iconSize = sizing.iconSmall;
    final (Widget indicator, Color textColor) = switch (state) {
      _SubTaskState.pending => (
          Icon(Symbols.circle_sharp,
              size: iconSize, color: colorScheme.outlineVariant),
          colorScheme.onSurfaceVariant,
        ),
      _SubTaskState.active => (
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: colorScheme.primary),
          ),
          colorScheme.onSurface,
        ),
      _SubTaskState.done => (
          Icon(Symbols.check_circle_sharp,
              size: iconSize, color: semantic.success.color),
          colorScheme.onSurface,
        ),
    };

    return Row(
      children: [
        indicator,
        SizedBox(width: spacing.space12),
        Expanded(
          child: Text(label,
              style: textTheme.bodyMedium?.copyWith(color: textColor)),
        ),
      ],
    );
  }
}
