import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:crypto_mobile_app/design_system/src/zk_identity_flow_page.dart';
import 'package:crypto_mobile_app/features/zk_identity/models/zk_identity_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';

final zkIdentityChallengeActiveProvider = StateProvider<bool>((ref) => false);

final zkIdentityIsCompleteProvider = Provider<AsyncValue<bool>>((ref) {
  return ref.watch(zkPassportIsRegisteredProvider);
});

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

  Future<bool> checkAppInstalled() async {
    try {
      final canLaunch = await canLaunchUrl(Uri.parse('zkpassport://'));
      if (canLaunch) {
        state = state
            .advanceTo(ZkIdentityStep.indexOf(ZkIdentityStep.confirmScanned));
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void confirmPassportScanned() {
    if (state.currentStep == ZkIdentityStep.confirmScanned) {
      state =
          state.advanceTo(ZkIdentityStep.indexOf(ZkIdentityStep.readyToVerify));
    }
  }

  void confirmReady() {
    if (state.currentStep == ZkIdentityStep.readyToVerify) {
      state =
          state.advanceTo(ZkIdentityStep.indexOf(ZkIdentityStep.verification));
    }
  }

  Future<void> triggerVerification() async {
    if (state.currentStep != ZkIdentityStep.verification) return;

    _ref.read(zkIdentityChallengeActiveProvider.notifier).state = true;

    final flowController = _ref.read(zkPassportFlowControllerProvider);
    final result = await flowController.startRegistrationNonceZero();

    if (!result.started) {
      final verificationIndex =
          ZkIdentityStep.indexOf(ZkIdentityStep.verification);
      final failedSteps = List<ZkIdentityStepState>.from(state.steps);
      failedSteps[verificationIndex] = failedSteps[verificationIndex]
          .copyWith(status: ZkIdentityStepVisualStatus.failed);
      state = ZkIdentityFlowState(
        steps: failedSteps,
        currentStepIndex: verificationIndex,
        resultMessage: result.message,
        isSuccess: false,
      );
      _ref.read(zkIdentityChallengeActiveProvider.notifier).state = false;
      return;
    }

    // Cancel any previous subscription before creating a new one.
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
  }

  void _onVerificationComplete(bool success, String message) {
    _pipelineSubscription?.close();
    _pipelineSubscription = null;
    _ref.read(zkIdentityChallengeActiveProvider.notifier).state = false;

    if (success) {
      final resultIndex = ZkIdentityStep.indexOf(ZkIdentityStep.result);
      final updated = List<ZkIdentityStepState>.from(state.steps);
      updated[state.currentStepIndex] = updated[state.currentStepIndex]
          .copyWith(status: ZkIdentityStepVisualStatus.completed);
      updated[resultIndex] = updated[resultIndex]
          .copyWith(status: ZkIdentityStepVisualStatus.active);
      state = ZkIdentityFlowState(
        steps: updated,
        currentStepIndex: resultIndex,
        resultMessage: message,
        isSuccess: true,
      );
    } else {
      final verificationIndex =
          ZkIdentityStep.indexOf(ZkIdentityStep.verification);
      final failedSteps = List<ZkIdentityStepState>.from(state.steps);
      failedSteps[verificationIndex] = failedSteps[verificationIndex]
          .copyWith(status: ZkIdentityStepVisualStatus.failed);
      state = ZkIdentityFlowState(
        steps: failedSteps,
        currentStepIndex: verificationIndex,
        resultMessage: message,
        isSuccess: false,
      );
    }
  }

  void reset() {
    _pipelineSubscription?.close();
    _pipelineSubscription = null;
    _ref.read(zkIdentityChallengeActiveProvider.notifier).state = false;
    state = ZkIdentityFlowState.initial();
  }

  @override
  void dispose() {
    _pipelineSubscription?.close();
    super.dispose();
  }
}
