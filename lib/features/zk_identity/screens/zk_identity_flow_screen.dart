import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:crypto_mobile_app/features/auth/providers/post_sign_in_sync.dart';
import 'package:crypto_mobile_app/features/zk_identity/models/zk_identity_models.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zk_identity/zk_identity_status_mapper.dart';
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
  static const _accountSessionHandoffTimeout = Duration(seconds: 30);
  static const _walletPoolExhaustedCode = 'wallet_pool_exhausted';

  final _claimEmailController = TextEditingController();
  final _claimCodeController = TextEditingController();
  final _claimEmailFocus = FocusNode();
  final _claimCodeFocus = FocusNode();

  bool _checkingApp = true;
  bool _appNotInstalled = false;
  bool _claimFlowActive = false;
  bool _claimCodeSent = false;
  bool _walletClaimed = false;
  bool _claimBusy = false;
  bool _accountRetryBusy = false;
  bool _accountPreparationFailureShown = false;
  bool _verificationStartInFlight = false;
  bool _waitingForAccount = false;
  String? _claimError;
  Timer? _accountSessionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Reset local checkApp state when navigating away from that step.
    ref.listenManual(zkIdentityStepControllerProvider, (prev, next) {
      if (next.currentStep != ZkIdentityStep.checkApp &&
          (_checkingApp || _appNotInstalled)) {
        setState(() {
          _checkingApp = false;
          _appNotInstalled = false;
        });
      }
    });
    ref.listenManual<Identity>(identityProvider, (previous, next) {
      if (next.allowsSigning || _waitingForAccount) {
        unawaited(_startVerification());
      }
    });
    ref.listenManual<AccountReconciliationFailure?>(
      accountReconciliationFailureProvider,
      (previous, next) {
        if (next != null || _waitingForAccount) {
          unawaited(_startVerification());
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startVerification());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accountSessionTimer?.cancel();
    _claimEmailController.dispose();
    _claimCodeController.dispose();
    _claimEmailFocus.dispose();
    _claimCodeFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _appNotInstalled) {
      unawaited(_startVerification());
    }
  }

  Future<void> _startVerification() async {
    if (!mounted ||
        _verificationStartInFlight ||
        _claimBusy ||
        _accountRetryBusy) {
      return;
    }
    final flowState = ref.read(zkIdentityStepControllerProvider);
    if (flowState.currentStep != ZkIdentityStep.checkApp) return;

    _verificationStartInFlight = true;
    setState(() {
      _checkingApp = true;
      _appNotInstalled = false;
    });
    try {
      late final bool appInstalled;
      try {
        appInstalled =
            await ref.read(zkPassportLaunchServiceProvider).isInstalled();
      } catch (_) {
        appInstalled = false;
      }
      if (!mounted) return;
      if (!appInstalled) {
        _accountSessionTimer?.cancel();
        _accountSessionTimer = null;
        setState(() {
          _checkingApp = false;
          _appNotInstalled = true;
          _waitingForAccount = false;
          _accountPreparationFailureShown = false;
        });
        return;
      }

      final identity = ref.read(identityProvider);
      final reconciliationFailure =
          ref.read(accountReconciliationFailureProvider);
      final controller = ref.read(zkIdentityStepControllerProvider.notifier);

      if (identity.allowsSigning) {
        _accountSessionTimer?.cancel();
        _accountSessionTimer = null;
        _waitingForAccount = false;
        _accountPreparationFailureShown = false;
        final launched = await controller.startVerificationFromSavedPassport();
        if (!mounted) return;
        setState(() {
          _checkingApp = false;
          _appNotInstalled = !launched;
        });
        return;
      }

      if (reconciliationFailure != null) {
        _accountSessionTimer?.cancel();
        _accountSessionTimer = null;
        if (reconciliationFailure.code == _walletPoolExhaustedCode) {
          _accountPreparationFailureShown = false;
          controller.prepareForAccountRecovery();
        } else {
          _accountPreparationFailureShown = true;
          controller.showAccountPreparationFailure(
            reconciliationFailure.message,
          );
        }
        if (!mounted) return;
        setState(() {
          _checkingApp = false;
          _waitingForAccount = false;
        });
        return;
      }

      setState(() {
        _checkingApp = true;
        _waitingForAccount = true;
        _accountPreparationFailureShown = false;
      });
      _scheduleAccountSessionTimeout();
    } finally {
      _verificationStartInFlight = false;
    }
  }

  void _scheduleAccountSessionTimeout() {
    if (_accountSessionTimer != null) return;
    _accountSessionTimer = Timer(_accountSessionHandoffTimeout, () {
      _accountSessionTimer = null;
      if (!mounted) return;
      final identity = ref.read(identityProvider);
      if (identity.allowsSigning ||
          identity.phase == IdentityPhase.reconciling ||
          ref.read(accountReconciliationFailureProvider) != null) {
        unawaited(_startVerification());
        return;
      }
      ref
          .read(zkIdentityStepControllerProvider.notifier)
          .showAccountPreparationFailure(
            AppLocalizations.of(context).zkIdentityAccountUnavailable,
          );
      setState(() {
        _checkingApp = false;
        _waitingForAccount = false;
        _accountPreparationFailureShown = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final flowState = ref.watch(zkIdentityStepControllerProvider);
    final pipelineState = ref.watch(zkPassportPipelineProvider);
    final reconciliationFailure =
        ref.watch(accountReconciliationFailureProvider);
    final walletRecoveryRequired = _claimFlowActive ||
        reconciliationFailure?.code == _walletPoolExhaustedCode;

    final l10n = AppLocalizations.of(context);
    final steps = flowState.steps.map((s) {
      final isRecoveryStep =
          walletRecoveryRequired && s.step == ZkIdentityStep.verification;
      final isAccountPreparationStep =
          (_waitingForAccount && s.step == ZkIdentityStep.checkApp) ||
              (_accountPreparationFailureShown &&
                  s.step == ZkIdentityStep.verification);
      return ZkIdentityStepData(
        label: isRecoveryStep
            ? l10n.zkIdentityWalletClaimTitle
            : isAccountPreparationStep
                ? l10n.zkIdentityAccountPreparingTitle
                : _stepLabel(s.step, l10n),
        description: isRecoveryStep
            ? l10n.zkIdentityWalletClaimDescription
            : isAccountPreparationStep
                ? l10n.zkIdentityAccountPreparingDescription
                : _stepDescription(s.step, l10n),
        status: isRecoveryStep ? ZkIdentityStepVisualStatus.active : s.status,
      );
    }).toList();

    return ZkIdentityFlowPage(
      steps: steps,
      currentStepIndex: flowState.currentStepIndex,
      centerActiveContent: flowState.currentStep == ZkIdentityStep.result ||
          (flowState.currentStep == ZkIdentityStep.checkApp &&
              _appNotInstalled),
      activeStepContent: _buildBody(
        context,
        flowState,
        pipelineState,
        walletRecoveryRequired: walletRecoveryRequired,
      ),
      bottomAction: _buildBottomAction(
        context,
        flowState,
        pipelineState,
        walletRecoveryRequired: walletRecoveryRequired,
      ),
      onBack: () => context.pop(),
    );
  }

  Widget? _buildBody(
    BuildContext context,
    ZkIdentityFlowState flowState,
    ZkPassportPipelineState pipelineState, {
    required bool walletRecoveryRequired,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final spacing = theme.extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);

    return switch (flowState.currentStep) {
      ZkIdentityStep.checkApp => _appNotInstalled
          ? FullPageErrorState(
              message: l10n.zkIdentityAppNotFoundTitle,
              detail: l10n.zkIdentityAppNotFoundDetail,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_checkingApp)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
      // These compatibility states are skipped by the saved-passport flow.
      ZkIdentityStep.confirmScanned || ZkIdentityStep.readyToVerify => null,
      ZkIdentityStep.verification => walletRecoveryRequired
          ? _buildWalletClaimBody(context)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (flowState.resultMessage != null && !flowState.isSuccess)
                  Text(
                    flowState.resultMessage!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  )
                else
                  for (final task in _subTasks) ...[
                    _SubTaskRow(
                      label: task.labelOf(l10n),
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
                  ? l10n.zkIdentityResultSuccessTitle
                  : l10n.zkIdentityResultFailureTitle,
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.space8),
            if (flowState.isSuccess) ...[
              Text(
                l10n.zkIdentityResultSuccessSubtitle,
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
                      l10n,
                      onCopyProofId: reg.nullifierHex != null
                          ? () {
                              Clipboard.setData(
                                ClipboardData(text: reg.nullifierHex!),
                              );
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(l10n.commonCopied)),
                              );
                            }
                          : null,
                    ),
                  );
                }),
              ],
            ] else ...[
              Text(
                l10n.zkIdentityResultFailureSubtitle,
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
    ZkPassportPipelineState pipelineState, {
    required bool walletRecoveryRequired,
  }) {
    final controller = ref.read(zkIdentityStepControllerProvider.notifier);
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);

    return switch (flowState.currentStep) {
      ZkIdentityStep.checkApp => _appNotInstalled
          ? Button(
              variant: ButtonVariant.primary,
              size: ButtonSize.large,
              label: l10n.zkIdentityInstallCta,
              onTap: ref.read(zkPassportLaunchServiceProvider).openStoreListing,
            )
          : null,
      ZkIdentityStep.confirmScanned || ZkIdentityStep.readyToVerify => null,
      ZkIdentityStep.verification => walletRecoveryRequired
          ? _buildWalletClaimActions(spacing: spacing, l10n: l10n)
          : _buildVerificationActions(
              flowState: flowState,
              pipelineState: pipelineState,
              controller: controller,
              spacing: spacing,
              l10n: l10n,
            ),
      ZkIdentityStep.result => Button(
          variant: ButtonVariant.primary,
          size: ButtonSize.large,
          label: l10n.zkIdentityDone,
          onTap: () => context.pop(),
        ),
    };
  }

  Widget _buildWalletClaimBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_claimCodeSent)
          TextField(
            controller: _claimEmailController,
            focusNode: _claimEmailFocus,
            enabled: !_claimBusy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.zkIdentityWalletClaimEmailLabel,
              helperText: l10n.zkIdentityWalletClaimEmailHelper,
            ),
            onSubmitted: (_) {
              if (!_claimBusy) unawaited(_sendWalletClaimCode());
            },
          )
        else ...[
          Text(
            l10n.zkIdentityWalletClaimCodeSent,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: spacing.space16),
          TextField(
            controller: _claimCodeController,
            focusNode: _claimCodeFocus,
            enabled: !_claimBusy,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            decoration: InputDecoration(
              labelText: l10n.zkIdentityWalletClaimCodeLabel,
            ),
            onSubmitted: (_) {
              if (!_claimBusy) unawaited(_claimWalletAndContinue());
            },
          ),
        ],
        if (_claimError != null) ...[
          SizedBox(height: spacing.space12),
          Text(
            _claimError!,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildWalletClaimActions({
    required AppSpacing spacing,
    required AppLocalizations l10n,
  }) {
    if (!_claimCodeSent) {
      return Button(
        variant: ButtonVariant.primary,
        size: ButtonSize.large,
        label: _claimBusy
            ? l10n.zkIdentityWalletClaimSendingCode
            : l10n.zkIdentityWalletClaimSendCode,
        onTap: _claimBusy ? null : () => unawaited(_sendWalletClaimCode()),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Button(
          variant: ButtonVariant.primary,
          size: ButtonSize.large,
          label: _claimBusy
              ? l10n.zkIdentityWalletClaimConnecting
              : _walletClaimed
                  ? l10n.zkIdentityTryAgain
                  : l10n.zkIdentityWalletClaimConnect,
          onTap: _claimBusy ? null : () => unawaited(_claimWalletAndContinue()),
        ),
        if (!_walletClaimed) ...[
          SizedBox(height: spacing.space8),
          Button(
            variant: ButtonVariant.outlined,
            size: ButtonSize.large,
            label: l10n.zkIdentityWalletClaimChangeEmail,
            onTap: _claimBusy ? null : _changeWalletClaimEmail,
          ),
        ],
      ],
    );
  }

  Future<void> _sendWalletClaimCode() async {
    final l10n = AppLocalizations.of(context);
    final email = _claimEmailController.text.trim().toLowerCase();
    if (!_looksLikeEmail(email)) {
      setState(() => _claimError = l10n.zkIdentityWalletClaimEmailRequired);
      _claimEmailFocus.requestFocus();
      return;
    }

    setState(() {
      _claimFlowActive = true;
      _claimBusy = true;
      _claimError = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestOtp(email);
      if (!mounted) return;
      setState(() {
        _claimBusy = false;
        _claimCodeSent = true;
      });
      _claimCodeFocus.requestFocus();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _claimBusy = false;
        _claimError = _claimErrorMessage(error);
      });
    }
  }

  Future<void> _claimWalletAndContinue() async {
    final l10n = AppLocalizations.of(context);
    final code = _claimCodeController.text.trim();
    if (!_walletClaimed && !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _claimError = l10n.zkIdentityWalletClaimCodeRequired);
      _claimCodeFocus.requestFocus();
      return;
    }

    setState(() {
      _claimFlowActive = true;
      _claimBusy = true;
      _claimError = null;
    });
    try {
      if (!_walletClaimed) {
        await ref.read(leaderboardApiServiceProvider).claimExistingWallet(
              email: _claimEmailController.text.trim().toLowerCase(),
              code: code,
            );
        _walletClaimed = true;
      }

      final ready =
          await ref.read(identityDriverProvider).retryReconciliation();
      if (!mounted) return;
      if (!ready) {
        setState(() {
          _claimBusy = false;
          _claimError =
              ref.read(accountReconciliationFailureProvider)?.message ??
                  l10n.zkIdentityWalletClaimRetryFailed;
        });
        return;
      }

      final launched = await ref
          .read(zkIdentityStepControllerProvider.notifier)
          .retryVerification();
      if (!mounted) return;
      setState(() {
        _checkingApp = false;
        _appNotInstalled = !launched;
        _claimBusy = false;
        _claimFlowActive = !launched;
        if (!launched) {
          _claimError = l10n.zkIdentityWalletClaimRetryFailed;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _claimBusy = false;
        _claimError = _claimErrorMessage(error);
      });
    }
  }

  void _changeWalletClaimEmail() {
    setState(() {
      _claimCodeSent = false;
      _claimCodeController.clear();
      _claimError = null;
    });
    _claimEmailFocus.requestFocus();
  }

  bool _looksLikeEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);

  String _claimErrorMessage(Object error) {
    if (error is AuthException) return error.message;
    if (error is LeaderboardApiException) return error.message;
    return AppLocalizations.of(context).zkIdentityWalletClaimRetryFailed;
  }

  Widget? _buildVerificationActions({
    required ZkIdentityFlowState flowState,
    required ZkPassportPipelineState pipelineState,
    required ZkIdentityStepController controller,
    required AppSpacing spacing,
    required AppLocalizations l10n,
  }) {
    final hasFailure = flowState.resultMessage != null && !flowState.isSuccess;
    if (hasFailure) {
      return Button(
        variant: ButtonVariant.primary,
        size: ButtonSize.large,
        label: l10n.zkIdentityTryAgain,
        onTap: _accountRetryBusy
            ? null
            : () => unawaited(
                  _accountPreparationFailureShown
                      ? _retryAccountPreparation()
                      : controller.retryVerification(),
                ),
      );
    }

    final isWaitingOnCompanion =
        pipelineState.phase == ZkPassportPipelinePhase.waiting ||
            pipelineState.phase == ZkPassportPipelinePhase.resuming;
    if (!isWaitingOnCompanion) return null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Button(
          variant: ButtonVariant.tonal,
          size: ButtonSize.large,
          label: l10n.zkIdentityGoToZkPassport,
          onTap: () => unawaited(controller.reopenVerificationRequest()),
        ),
        SizedBox(height: spacing.space8),
        Button(
          variant: ButtonVariant.outlined,
          size: ButtonSize.large,
          label: l10n.zkIdentityCancelVerification,
          onTap: () => unawaited(controller.cancelVerification()),
        ),
      ],
    );
  }

  Future<void> _retryAccountPreparation() async {
    setState(() => _accountRetryBusy = true);
    if (ref.read(identityProvider).phase != IdentityPhase.reconciling) {
      ref.read(zkIdentityStepControllerProvider.notifier).reset();
      setState(() {
        _accountRetryBusy = false;
        _accountPreparationFailureShown = false;
        _waitingForAccount = true;
      });
      await _startVerification();
      return;
    }

    final ready = await ref.read(identityDriverProvider).retryReconciliation();
    if (!mounted) return;
    if (!ready) {
      final failure = ref.read(accountReconciliationFailureProvider);
      if (failure != null && failure.code != _walletPoolExhaustedCode) {
        _accountPreparationFailureShown = true;
        ref
            .read(zkIdentityStepControllerProvider.notifier)
            .showAccountPreparationFailure(failure.message);
      }
      setState(() => _accountRetryBusy = false);
      return;
    }

    setState(() {
      _accountRetryBusy = false;
      _accountPreparationFailureShown = false;
    });
    await ref
        .read(zkIdentityStepControllerProvider.notifier)
        .retryVerification();
  }

  String _stepLabel(ZkIdentityStep step, AppLocalizations l10n) {
    return switch (step) {
      ZkIdentityStep.checkApp => l10n.zkIdentityStepLabelOpenApp,
      ZkIdentityStep.confirmScanned => l10n.zkIdentityStepLabelScan,
      ZkIdentityStep.readyToVerify => l10n.zkIdentityStepLabelReady,
      ZkIdentityStep.verification => l10n.zkIdentityStepLabelVerifying,
      ZkIdentityStep.result => l10n.zkIdentityStepLabelResult,
    };
  }

  String _stepDescription(ZkIdentityStep step, AppLocalizations l10n) {
    return switch (step) {
      ZkIdentityStep.checkApp => l10n.zkIdentityStepDescOpenApp,
      ZkIdentityStep.confirmScanned => l10n.zkIdentityStepDescScan,
      ZkIdentityStep.readyToVerify => l10n.zkIdentityStepDescReady,
      ZkIdentityStep.verification => l10n.zkIdentityStepDescVerifying,
      ZkIdentityStep.result => l10n.zkIdentityStepDescResult,
    };
  }
}

// ---------------------------------------------------------------------------
// Sub-task progress model for verification step
// ---------------------------------------------------------------------------

enum _SubTaskState { pending, active, done }

enum _SubTaskKind { opening, waiting, checking, wrapping, finalCheck }

class _SubTask {
  const _SubTask({
    required this.kind,
    required this.activePhases,
    required this.doneAfter,
  });

  final _SubTaskKind kind;
  final Set<ZkPassportPipelinePhase> activePhases;
  final Set<ZkPassportPipelinePhase> doneAfter;

  String labelOf(AppLocalizations l10n) => switch (kind) {
        _SubTaskKind.opening => l10n.zkIdentitySubTaskOpening,
        _SubTaskKind.waiting => l10n.zkIdentitySubTaskWaiting,
        _SubTaskKind.checking => l10n.zkIdentitySubTaskChecking,
        _SubTaskKind.wrapping => l10n.zkIdentitySubTaskWrapping,
        _SubTaskKind.finalCheck => l10n.zkIdentitySubTaskFinal,
      };

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
    kind: _SubTaskKind.opening,
    activePhases: {
      ZkPassportPipelinePhase.idle,
      ZkPassportPipelinePhase.launching,
    },
    doneAfter: {ZkPassportPipelinePhase.launching},
  ),
  _SubTask(
    kind: _SubTaskKind.waiting,
    activePhases: {
      ZkPassportPipelinePhase.waiting,
      ZkPassportPipelinePhase.resuming,
    },
    doneAfter: {ZkPassportPipelinePhase.proofReceived},
  ),
  _SubTask(
    kind: _SubTaskKind.checking,
    activePhases: {
      ZkPassportPipelinePhase.proofReceived,
      ZkPassportPipelinePhase.verifyingOuter,
    },
    doneAfter: {ZkPassportPipelinePhase.verifyingOuter},
  ),
  _SubTask(
    kind: _SubTaskKind.wrapping,
    activePhases: {ZkPassportPipelinePhase.wrapping},
    doneAfter: {ZkPassportPipelinePhase.wrapping},
  ),
  _SubTask(
    kind: _SubTaskKind.finalCheck,
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
