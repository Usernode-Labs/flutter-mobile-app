import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/design_system/src/zk_identity_flow_page.dart';
import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:crypto_mobile_app/features/zk_identity/models/zk_identity_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';

final zkIdentityChallengeActiveProvider = StateProvider<bool>((ref) => false);

final zkIdentityRegistrationProvider =
    Provider<AsyncValue<ZkPassportLocalRegistration>>((ref) {
  return ref.watch(zkPassportRegistrationProvider);
});

final zkIdentityStepControllerProvider =
    StateNotifierProvider<ZkIdentityStepController, ZkIdentityFlowState>((ref) {
  return ZkIdentityStepController(ref);
});

class ZkIdentityStepController extends StateNotifier<ZkIdentityFlowState> {
  ZkIdentityStepController(this._ref) : super(ZkIdentityFlowState.initial());

  final Ref _ref;
  ProviderSubscription<ZkPassportPipelineState>? _pipelineSubscription;
  Uri? _activeRequestUri;

  /// Starts verification immediately with the passport already stored in the
  /// companion app. No passport scan or readiness confirmation is required.
  Future<bool> startVerificationFromSavedPassport(
    SessionFeatureAccess session,
  ) async {
    late final bool installed;
    try {
      installed =
          await _ref.read(zkPassportLaunchServiceProvider).isInstalled();
    } catch (_) {
      return false;
    }
    if (!installed) return false;

    if (state.currentStep == ZkIdentityStep.verification) {
      if (_activeRequestUri != null) {
        await reopenVerificationRequest();
      }
      return true;
    }
    if (state.currentStep != ZkIdentityStep.checkApp) {
      return true;
    }

    state = state.advanceTo(ZkIdentityStep.verification.index);
    try {
      await triggerVerification(session);
    } catch (_) {
      _failVerification('Unable to start zkPassport verification.');
    }
    return true;
  }

  Future<bool> reopenVerificationRequest() async {
    final launchUri = _activeRequestUri;
    if (launchUri == null) return false;
    return _ref
        .read(zkPassportLaunchServiceProvider)
        .launchOrOpenStore(launchUri);
  }

  Future<void> triggerVerification(SessionFeatureAccess session) async {
    if (state.currentStep != ZkIdentityStep.verification) return;

    _ref.read(zkIdentityChallengeActiveProvider.notifier).state = true;

    // Start observing before the app handoff. On iOS, Usernode can be
    // suspended as soon as ZKPassport opens, and the proof may finish before
    // the URL-launch future resumes.
    _pipelineSubscription?.close();
    _pipelineSubscription = _ref.listen<ZkPassportPipelineState>(
      zkPassportPipelineProvider,
      (previous, next) {
        if (next.status == ZkPassportPipelineStatus.success) {
          _onVerificationComplete(true, next.message);
        } else if (next.status == ZkPassportPipelineStatus.failure) {
          _onVerificationComplete(false, next.message);
        }
      },
    );

    final flowController = _ref.read(zkPassportFlowControllerProvider);
    final result = await flowController.startRegistrationNonceZero(session);
    _activeRequestUri = result.launchUri;

    if (!result.started) {
      _failVerification(result.message);
      return;
    }
  }

  void _onVerificationComplete(bool success, String message) {
    _pipelineSubscription?.close();
    _pipelineSubscription = null;
    _ref.read(zkIdentityChallengeActiveProvider.notifier).state = false;

    if (success) {
      final resultIndex = ZkIdentityStep.result.index;
      final updated = List<ZkIdentityStepState>.from(state.steps);
      updated[state.currentStepIndex] = updated[state.currentStepIndex]
          .copyWith(status: ZkIdentityStepVisualStatus.completed);
      updated[resultIndex] = updated[resultIndex].copyWith(
        status: ZkIdentityStepVisualStatus.active,
      );
      state = ZkIdentityFlowState(
        steps: updated,
        currentStepIndex: resultIndex,
        resultMessage: message,
        isSuccess: true,
      );
    } else {
      _failVerification(message);
    }
  }

  void _failVerification(String message) {
    _pipelineSubscription?.close();
    _pipelineSubscription = null;
    final idx = ZkIdentityStep.verification.index;
    final updated = List<ZkIdentityStepState>.from(state.steps);
    updated[idx] = updated[idx].copyWith(
      status: ZkIdentityStepVisualStatus.failed,
    );
    state = ZkIdentityFlowState(
      steps: updated,
      currentStepIndex: idx,
      resultMessage: message,
      isSuccess: false,
    );
    _ref.read(zkIdentityChallengeActiveProvider.notifier).state = false;
  }

  void reset() {
    _pipelineSubscription?.close();
    _pipelineSubscription = null;
    _activeRequestUri = null;
    _ref.read(zkIdentityChallengeActiveProvider.notifier).state = false;
    state = ZkIdentityFlowState.initial();
  }

  Future<bool> retryVerification(SessionFeatureAccess session) async {
    final discarded = await _ref
        .read(zkPassportPipelineProvider.notifier)
        .discardPendingSession(reason: 'Retrying');
    if (!discarded) return false;

    reset();
    return startVerificationFromSavedPassport(session);
  }

  Future<bool> cancelVerification() async {
    final discarded = await _ref
        .read(zkPassportPipelineProvider.notifier)
        .discardPendingSession(reason: 'Cancelled');
    if (!discarded) return false;

    reset();
    return true;
  }

  @override
  void dispose() {
    _pipelineSubscription?.close();
    super.dispose();
  }
}
