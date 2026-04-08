import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/design_system/src/zk_identity_flow_page.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/zk_identity/models/zk_identity_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';

final zkIdentityChallengeActiveProvider = StateProvider<bool>((ref) => false);

/// Resolves the real challenge ID for the ZK Identity challenge from the
/// already-loaded challenges list by matching subCategory.
final zkIdentityChallengeIdProvider = Provider<int?>((ref) {
  return ref.watch(zkIdentityChallengeDtoProvider)?.id;
});

/// Resolves the full [ChallengeDto] for the ZK Identity challenge.
final zkIdentityChallengeDtoProvider = Provider<ChallengeDto?>((ref) {
  final challenges = ref.watch(challengesProvider.select((s) => s.valueOrNull));
  if (challenges == null) return null;
  for (final c in challenges) {
    if (c.subCategory == zkIdentitySubCategory) return c;
  }
  return null;
});

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
        state = state.advanceTo(ZkIdentityStep.confirmScanned.index);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void confirmPassportScanned() {
    if (state.currentStep == ZkIdentityStep.confirmScanned) {
      state = state.advanceTo(ZkIdentityStep.readyToVerify.index);
    }
  }

  void confirmReady() {
    if (state.currentStep == ZkIdentityStep.readyToVerify) {
      state = state.advanceTo(ZkIdentityStep.verification.index);
    }
  }

  Future<void> triggerVerification() async {
    if (state.currentStep != ZkIdentityStep.verification) return;

    _ref.read(zkIdentityChallengeActiveProvider.notifier).state = true;

    final flowController = _ref.read(zkPassportFlowControllerProvider);
    final result = await flowController.startRegistrationNonceZero();

    if (!result.started) {
      _failVerification(result.message);
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
    _ref.read(zkIdentityChallengeActiveProvider.notifier).state = false;
    state = ZkIdentityFlowState.initial();
  }

  @override
  void dispose() {
    _pipelineSubscription?.close();
    super.dispose();
  }
}
