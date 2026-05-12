import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/zk_identity/models/zk_identity_models.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zk_identity/zk_identity_status_mapper.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';

final _log = LoggingService.instance.withTag('usernode/ZkIdentityFlowScreen');

class ZkIdentityFlowScreen extends ConsumerStatefulWidget {
  const ZkIdentityFlowScreen({super.key});

  @override
  ConsumerState<ZkIdentityFlowScreen> createState() =>
      _ZkIdentityFlowScreenState();
}

class _ZkIdentityFlowScreenState extends ConsumerState<ZkIdentityFlowScreen>
    with WidgetsBindingObserver {
  static const _verificationRenderWatchdogInterval =
      Duration(milliseconds: 250);
  static const _verificationRenderWatchdogTimeout = Duration(seconds: 30);

  bool _checkingApp = false;
  bool _appNotInstalled = false;
  String? _lastPresentationTraceSignature;
  ProviderSubscription<ZkIdentityFlowState>? _flowSubscription;
  ProviderSubscription<ZkPassportPipelineState>? _pipelineSubscription;
  ProviderSubscription<AsyncValue<ZkPassportLocalRegistration>>?
      _registrationSubscription;
  Timer? _verificationRenderWatchdog;
  DateTime? _verificationRenderWatchdogStartedAt;
  ZkIdentityFlowState? _terminalPresentationOverride;
  int _buildCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Reset local checkApp state when navigating away from that step.
    _flowSubscription =
        ref.listenManual(zkIdentityStepControllerProvider, (prev, next) {
      final previous = prev;
      _clearTerminalPresentationOverrideIfNeeded(next);
      _syncVerificationRenderWatchdog();
      if (next.currentStep != ZkIdentityStep.checkApp &&
          (_checkingApp || _appNotInstalled)) {
        setState(() {
          _checkingApp = false;
          _appNotInstalled = false;
        });
      }
      final flowChanged = previous == null ||
          previous.currentStepIndex != next.currentStepIndex ||
          previous.resultMessage != next.resultMessage ||
          previous.isSuccess != next.isSuccess;
      if (flowChanged && mounted) {
        _log.warn('Forcing rebuild after flow-state change', context: {
          'previousStep': previous?.currentStep.name,
          'nextStep': next.currentStep.name,
          'previousMessage': previous?.resultMessage,
          'nextMessage': next.resultMessage,
          'previousIsSuccess': previous?.isSuccess,
          'nextIsSuccess': next.isSuccess,
        });
        setState(() {});
      }
    });
    _pipelineSubscription =
        ref.listenManual(zkPassportPipelineProvider, (previous, next) {
      _syncVerificationRenderWatchdog();
      _log.warn('Pipeline state changed in screen', context: {
        'previousStatus': previous?.status.name,
        'previousPhase': previous?.phase.name,
        'status': next.status.name,
        'phase': next.phase.name,
        'requestId': next.requestId,
        'message': next.message,
      });
      final pipelineChanged = previous == null ||
          previous.status != next.status ||
          previous.phase != next.phase ||
          previous.message != next.message ||
          previous.requestId != next.requestId;
      if (pipelineChanged && mounted) {
        _log.warn('Forcing rebuild after pipeline-state change', context: {
          'status': next.status.name,
          'phase': next.phase.name,
          'requestId': next.requestId,
        });
        setState(() {});
      }
    });
    _registrationSubscription =
        ref.listenManual(zkIdentityRegistrationProvider, (previous, next) {
      _syncVerificationRenderWatchdog();
      final prevReg = previous?.valueOrNull;
      final nextReg = next.valueOrNull;
      _log.warn('Registration state changed in screen', context: {
        'previousRegistered': prevReg?.registered,
        'registered': nextReg?.registered,
        'nullifierHex': nextReg?.nullifierHex,
        'facematchVerified': nextReg?.facematchVerified,
        'registeredAtMs': nextReg?.registeredAtMs,
      });
      final registrationChanged = prevReg?.registered != nextReg?.registered ||
          prevReg?.nullifierHex != nextReg?.nullifierHex ||
          prevReg?.registeredAtMs != nextReg?.registeredAtMs;
      if (registrationChanged && mounted) {
        _log.warn('Forcing rebuild after registration-state change', context: {
          'registered': nextReg?.registered,
          'nullifierHex': nextReg?.nullifierHex,
          'registeredAtMs': nextReg?.registeredAtMs,
        });
        setState(() {});
      }
    });
    _log.warn('Flow screen initialized');
  }

  @override
  void activate() {
    super.activate();
    _log.warn('Flow screen activate');
  }

  @override
  void deactivate() {
    _log.warn('Flow screen deactivate');
    super.deactivate();
  }

  @override
  void didUpdateWidget(covariant ZkIdentityFlowScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _log.warn('Flow screen didUpdateWidget');
  }

  @override
  void dispose() {
    _log.warn('Flow screen dispose');
    WidgetsBinding.instance.removeObserver(this);
    _flowSubscription?.close();
    _pipelineSubscription?.close();
    _registrationSubscription?.close();
    _stopVerificationRenderWatchdog();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _log.warn('Flow screen lifecycle changed', context: {
      'state': state.name,
      'appNotInstalled': _appNotInstalled,
    });
    if (state == AppLifecycleState.resumed) {
      _syncVerificationRenderWatchdog();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopVerificationRenderWatchdog();
    }
    if (state == AppLifecycleState.resumed && _appNotInstalled) {
      _checkApp();
    }
  }

  void _syncVerificationRenderWatchdog() {
    if (!mounted) return;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != AppLifecycleState.resumed) {
      _stopVerificationRenderWatchdog();
      return;
    }

    final flowState = ref.read(zkIdentityStepControllerProvider);
    final pipelineState = ref.read(zkPassportPipelineProvider);
    final registration = ref.read(zkIdentityRegistrationProvider).valueOrNull;
    final recoveredPersistedSuccess = registration?.registered == true &&
        flowState.currentStep == ZkIdentityStep.verification &&
        pipelineState.status != ZkPassportPipelineStatus.failure;
    final effectiveFlowState = resolveZkIdentitySuccessPresentationState(
      flowState,
      pipelineSucceeded:
          pipelineState.status == ZkPassportPipelineStatus.success,
      registrationCompleted: recoveredPersistedSuccess,
      successMessage: pipelineState.message,
    );

    final shouldWatch = flowState.currentStep == ZkIdentityStep.verification &&
        effectiveFlowState.currentStep != ZkIdentityStep.result &&
        pipelineState.status != ZkPassportPipelineStatus.failure;

    if (!shouldWatch) {
      _stopVerificationRenderWatchdog();
      return;
    }

    if (_verificationRenderWatchdog != null) {
      return;
    }

    _log.warn('Starting verification render watchdog', context: {
      'controllerStep': flowState.currentStep.name,
      'pipelineStatus': pipelineState.status.name,
      'pipelinePhase': pipelineState.phase.name,
      'registrationCompleted': registration?.registered,
    });
    _verificationRenderWatchdogStartedAt = DateTime.now();
    _verificationRenderWatchdog = Timer.periodic(
      _verificationRenderWatchdogInterval,
      (_) => _onVerificationRenderWatchdogTick(),
    );
  }

  void _onVerificationRenderWatchdogTick() {
    if (!mounted) {
      _stopVerificationRenderWatchdog();
      return;
    }

    final startedAt = _verificationRenderWatchdogStartedAt;
    if (startedAt != null &&
        DateTime.now().difference(startedAt) >=
            _verificationRenderWatchdogTimeout) {
      _log.warn('Verification render watchdog timed out', context: {
        'controllerStep':
            ref.read(zkIdentityStepControllerProvider).currentStep.name,
        'pipelineStatus': ref.read(zkPassportPipelineProvider).status.name,
        'pipelinePhase': ref.read(zkPassportPipelineProvider).phase.name,
      });
      _stopVerificationRenderWatchdog();
      return;
    }

    final flowState = ref.read(zkIdentityStepControllerProvider);
    final pipelineState = ref.read(zkPassportPipelineProvider);
    final registration = ref.read(zkIdentityRegistrationProvider).valueOrNull;
    final recoveredPersistedSuccess = registration?.registered == true &&
        flowState.currentStep == ZkIdentityStep.verification &&
        pipelineState.status != ZkPassportPipelineStatus.failure;
    final effectiveFlowState = resolveZkIdentitySuccessPresentationState(
      flowState,
      pipelineSucceeded:
          pipelineState.status == ZkPassportPipelineStatus.success,
      registrationCompleted: recoveredPersistedSuccess,
      successMessage: pipelineState.message,
    );

    final shouldForceRepaint =
        effectiveFlowState.currentStep == ZkIdentityStep.result ||
            (flowState.resultMessage != null && !flowState.isSuccess);
    if (shouldForceRepaint) {
      _log.warn(
        'Verification render watchdog forcing terminal presentation',
        context: {
          'controllerStep': flowState.currentStep.name,
          'effectiveStep': effectiveFlowState.currentStep.name,
          'effectiveMessage': effectiveFlowState.resultMessage,
          'effectiveIsSuccess': effectiveFlowState.isSuccess,
          'pipelineStatus': pipelineState.status.name,
          'pipelinePhase': pipelineState.phase.name,
          'registrationCompleted': registration?.registered,
        },
      );
      setState(() {
        _terminalPresentationOverride = effectiveFlowState;
      });
      _stopVerificationRenderWatchdog();
      return;
    }

    if (flowState.currentStep != ZkIdentityStep.verification ||
        pipelineState.status == ZkPassportPipelineStatus.failure) {
      _stopVerificationRenderWatchdog();
    }
  }

  void _stopVerificationRenderWatchdog() {
    if (_verificationRenderWatchdog != null) {
      _log.warn('Stopping verification render watchdog');
    }
    _verificationRenderWatchdog?.cancel();
    _verificationRenderWatchdog = null;
    _verificationRenderWatchdogStartedAt = null;
  }

  void _clearTerminalPresentationOverrideIfNeeded(
    ZkIdentityFlowState flowState,
  ) {
    final override = _terminalPresentationOverride;
    if (override == null) {
      return;
    }
    if (flowState.currentStep == ZkIdentityStep.verification ||
        (flowState.currentStep == ZkIdentityStep.result &&
            flowState.isSuccess == override.isSuccess &&
            flowState.resultMessage == override.resultMessage)) {
      return;
    }
    _log.warn('Clearing terminal presentation override', context: {
      'controllerStep': flowState.currentStep.name,
      'controllerIsSuccess': flowState.isSuccess,
      'controllerMessage': flowState.resultMessage,
    });
    _terminalPresentationOverride = null;
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
    _buildCount += 1;
    final flowState = ref.watch(zkIdentityStepControllerProvider);
    final pipelineState = ref.watch(zkPassportPipelineProvider);
    final registration = ref.watch(zkIdentityRegistrationProvider).valueOrNull;
    final recoveredPersistedSuccess = registration?.registered == true &&
        flowState.currentStep == ZkIdentityStep.verification &&
        pipelineState.status != ZkPassportPipelineStatus.failure;
    final effectiveFlowState = resolveZkIdentitySuccessPresentationState(
      flowState,
      pipelineSucceeded:
          pipelineState.status == ZkPassportPipelineStatus.success,
      registrationCompleted: recoveredPersistedSuccess,
      successMessage: pipelineState.message,
    );
    final presentedFlowState =
        _terminalPresentationOverride ?? effectiveFlowState;
    _tracePresentationState(
      flowState: flowState,
      effectiveFlowState: presentedFlowState,
      pipelineState: pipelineState,
      registration: registration,
      recoveredPersistedSuccess: recoveredPersistedSuccess,
    );
    _log.warn('Flow screen build', context: {
      'buildCount': _buildCount,
      'controllerStep': flowState.currentStep.name,
      'effectiveStep': effectiveFlowState.currentStep.name,
      'presentedStep': presentedFlowState.currentStep.name,
      'overrideActive': _terminalPresentationOverride != null,
      'pipelineStatus': pipelineState.status.name,
      'pipelinePhase': pipelineState.phase.name,
    });

    final steps = presentedFlowState.steps.map((s) {
      return ZkIdentityStepData(
        label: _stepLabel(s.step),
        description: _stepDescription(s.step),
        status: s.status,
      );
    }).toList();

    return ZkIdentityFlowPage(
      steps: steps,
      currentStepIndex: presentedFlowState.currentStepIndex,
      centerActiveContent:
          presentedFlowState.currentStep == ZkIdentityStep.result ||
              (presentedFlowState.currentStep == ZkIdentityStep.checkApp &&
                  _appNotInstalled),
      activeStepContent: _buildBody(context, presentedFlowState, pipelineState),
      bottomAction:
          _buildBottomAction(context, presentedFlowState, pipelineState),
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
            if (flowState.isSuccess) ...[
              Text(
                'Your identity was confirmed with zero-knowledge proof \u2014 '
                'no personal data was shared.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (ref
                      .watch(zkIdentityRegistrationProvider)
                      .valueOrNull
                      ?.registered ==
                  true) ...[
                SizedBox(height: spacing.space16),
                Builder(builder: (ctx) {
                  final reg =
                      ref.watch(zkIdentityRegistrationProvider).valueOrNull!;
                  return ZkIdentityStatusCard(
                    data: buildZkIdentityStatusData(
                      reg,
                      onCopyProofId: reg.nullifierHex != null
                          ? () {
                              Clipboard.setData(
                                ClipboardData(text: reg.nullifierHex!),
                              );
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Copied')),
                              );
                            }
                          : null,
                    ),
                  );
                }),
              ],
            ] else ...[
              Text(
                'Your data is safe \u2014 no information was shared.',
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

  void _tracePresentationState({
    required ZkIdentityFlowState flowState,
    required ZkIdentityFlowState effectiveFlowState,
    required ZkPassportPipelineState pipelineState,
    required ZkPassportLocalRegistration? registration,
    required bool recoveredPersistedSuccess,
  }) {
    final signature = [
      flowState.currentStep.name,
      flowState.currentStepIndex,
      flowState.isSuccess,
      flowState.resultMessage,
      effectiveFlowState.currentStep.name,
      effectiveFlowState.currentStepIndex,
      effectiveFlowState.isSuccess,
      effectiveFlowState.resultMessage,
      pipelineState.status.name,
      pipelineState.phase.name,
      pipelineState.requestId,
      registration?.registered,
      registration?.nullifierHex,
      recoveredPersistedSuccess,
      _checkingApp,
      _appNotInstalled,
    ].join('|');
    if (_lastPresentationTraceSignature == signature) {
      return;
    }
    _lastPresentationTraceSignature = signature;
    _log.warn('Resolved flow presentation state', context: {
      'controllerStep': flowState.currentStep.name,
      'controllerStepIndex': flowState.currentStepIndex,
      'controllerIsSuccess': flowState.isSuccess,
      'controllerMessage': flowState.resultMessage,
      'effectiveStep': effectiveFlowState.currentStep.name,
      'effectiveStepIndex': effectiveFlowState.currentStepIndex,
      'effectiveIsSuccess': effectiveFlowState.isSuccess,
      'effectiveMessage': effectiveFlowState.resultMessage,
      'pipelineStatus': pipelineState.status.name,
      'pipelinePhase': pipelineState.phase.name,
      'pipelineRequestId': pipelineState.requestId,
      'registrationCompleted': registration?.registered,
      'registrationNullifierHex': registration?.nullifierHex,
      'recoveredPersistedSuccess': recoveredPersistedSuccess,
      'checkingApp': _checkingApp,
      'appNotInstalled': _appNotInstalled,
    });
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
            unawaited(controller.triggerVerification());
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
      ZkPassportPipelinePhase.launching,
    },
    doneAfter: {ZkPassportPipelinePhase.launching},
  ),
  _SubTask(
    label: 'Waiting for proof',
    activePhases: {
      ZkPassportPipelinePhase.waiting,
      ZkPassportPipelinePhase.resuming,
    },
    doneAfter: {ZkPassportPipelinePhase.proofReceived},
  ),
  _SubTask(
    label: 'Verifying proof',
    activePhases: {
      ZkPassportPipelinePhase.proofReceived,
      ZkPassportPipelinePhase.verifyingOuter,
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
      ZkPassportPipelinePhase.success,
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
