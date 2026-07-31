import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/categorized_challenges_provider.dart';
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
///
/// Reads from [categorizedChallengesProvider] so the picked row matches what
/// the Challenges tab shows: prefer the active row, then completed, then
/// missed. Falling back to the raw challenges list would risk picking a stale
/// duplicate (e.g. a previous season's disabled row).
final zkIdentityChallengeDtoProvider = Provider<ChallengeDto?>((ref) {
  final categorized = ref.watch(categorizedChallengesProvider);
  if (categorized == null) return null;
  for (final bucket in [
    categorized.active,
    categorized.completed,
    categorized.missed,
  ]) {
    for (final c in bucket) {
      if (c.dto.subCategory == zkIdentitySubCategory) return c.dto;
    }
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
  final controller = ZkIdentityStepController(ref);
  ref.listen(
    zkPassportCurrentIdentityProvider,
    (previous, next) {
      if (previous == null || previous.sameScopeAs(next)) return;
      controller.reset();
    },
  );
  return controller;
});

class ZkIdentityStepController extends StateNotifier<ZkIdentityFlowState> {
  ZkIdentityStepController(this._ref) : super(ZkIdentityFlowState.initial());

  final Ref _ref;
  ProviderSubscription<ZkPassportPipelineState>? _pipelineSubscription;
  int _generation = 0;

  Future<bool> checkAppInstalled() async {
    final generation = _generation;
    try {
      final installed =
          await _ref.read(zkPassportLaunchServiceProvider).isInstalled();
      if (generation != _generation) return false;
      if (installed) {
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
    final generation = _generation;

    _ref.read(zkIdentityChallengeActiveProvider.notifier).state = true;

    final flowController = _ref.read(zkPassportFlowControllerProvider);
    final result = await flowController.startRegistrationNonceZero();
    if (generation != _generation) return;

    if (!result.started) {
      _failVerification(result.message);
      return;
    }

    // Cancel any previous subscription before creating a new one.
    _pipelineSubscription?.close();
    _pipelineSubscription = _ref.listen<ZkPassportPipelineState>(
      zkPassportPipelineProvider,
      (previous, next) {
        if (generation != _generation) return;
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
    _generation++;
    _pipelineSubscription?.close();
    _pipelineSubscription = null;
    _ref.read(zkIdentityChallengeActiveProvider.notifier).state = false;
    state = ZkIdentityFlowState.initial();
  }

  Future<bool> cancelVerification() async {
    final generation = _generation;
    final discarded = await _ref
        .read(zkPassportPipelineProvider.notifier)
        .discardPendingSession(reason: 'Cancelled');
    if (generation != _generation) return false;
    if (!discarded) return false;

    reset();
    return true;
  }

  @override
  void dispose() {
    _generation++;
    _pipelineSubscription?.close();
    super.dispose();
  }
}
