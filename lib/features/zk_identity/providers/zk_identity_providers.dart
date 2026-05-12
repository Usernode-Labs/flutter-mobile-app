import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/design_system/src/zk_identity_flow_page.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/zk_identity/models/zk_identity_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';

final _log = LoggingService.instance.withTag('usernode/ZkIdentityFlow');

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
  ZkIdentityStepController(this._ref) : super(ZkIdentityFlowState.initial()) {
    _log.warn('Step controller initialized', context: {
      'currentStep': state.currentStep.name,
      'currentStepIndex': state.currentStepIndex,
    });
  }

  final Ref _ref;
  ProviderSubscription<ZkPassportPipelineState>? _pipelineSubscription;

  Future<bool> checkAppInstalled() async {
    try {
      final canLaunch = await canLaunchUrl(Uri.parse('zkpassport://'));
      _log.warn('Checked zkPassport app install', context: {
        'installed': canLaunch,
      });
      if (canLaunch) {
        state = state.advanceTo(ZkIdentityStep.confirmScanned.index);
        _log.warn('Advanced after app check', context: {
          'currentStep': state.currentStep.name,
          'currentStepIndex': state.currentStepIndex,
        });
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
      _log.warn('Confirmed passport scanned', context: {
        'currentStep': state.currentStep.name,
        'currentStepIndex': state.currentStepIndex,
      });
    }
  }

  void confirmReady() {
    if (state.currentStep == ZkIdentityStep.readyToVerify) {
      state = state.advanceTo(ZkIdentityStep.verification.index);
      _log.warn('Confirmed ready for verification', context: {
        'currentStep': state.currentStep.name,
        'currentStepIndex': state.currentStepIndex,
      });
    }
  }

  Future<void> triggerVerification() async {
    if (state.currentStep != ZkIdentityStep.verification) {
      _log.warn('Ignoring triggerVerification outside verification step',
          context: {
            'currentStep': state.currentStep.name,
            'currentStepIndex': state.currentStepIndex,
          });
      return;
    }

    _log.warn('Triggering zk identity verification', context: {
      'currentStep': state.currentStep.name,
      'currentStepIndex': state.currentStepIndex,
    });

    _ref.read(zkIdentityChallengeActiveProvider.notifier).state = true;

    final flowController = _ref.read(zkPassportFlowControllerProvider);
    final result = await flowController.startRegistrationNonceZero();
    _log.warn('Verification launch result', context: {
      'started': result.started,
      'requestId': result.requestId,
      'message': result.message,
    });

    if (!result.started) {
      _failVerification(result.message);
      return;
    }

    _pipelineSubscription?.close();
    _pipelineSubscription = _ref.listen<ZkPassportPipelineState>(
      zkPassportPipelineProvider,
      (previous, next) {
        _log.warn('Observed pipeline state while verifying', context: {
          'previousStatus': previous?.status.name,
          'previousPhase': previous?.phase.name,
          'status': next.status.name,
          'phase': next.phase.name,
          'requestId': next.requestId,
          'message': next.message,
        });
        if (next.status == ZkPassportPipelineStatus.success) {
          _onVerificationComplete(true, next.message);
        } else if (next.status == ZkPassportPipelineStatus.failure) {
          _onVerificationComplete(false, next.message);
        }
      },
    );
  }

  void _onVerificationComplete(bool success, String message) {
    _log.warn('Completing verification flow', context: {
      'success': success,
      'message': message,
      'priorStep': state.currentStep.name,
      'priorStepIndex': state.currentStepIndex,
    });
    _pipelineSubscription?.close();
    _pipelineSubscription = null;
    _ref.read(zkIdentityChallengeActiveProvider.notifier).state = false;

    if (success) {
      final resultIndex = ZkIdentityStep.result.index;
      final updated = List<ZkIdentityStepState>.from(state.steps);
      updated[state.currentStepIndex] =
          updated[state.currentStepIndex].copyWith(
        status: ZkIdentityStepVisualStatus.completed,
      );
      updated[resultIndex] = updated[resultIndex].copyWith(
        status: ZkIdentityStepVisualStatus.active,
      );
      state = ZkIdentityFlowState(
        steps: updated,
        currentStepIndex: resultIndex,
        resultMessage: message,
        isSuccess: true,
      );
      _log.warn('Moved flow to success result', context: {
        'currentStep': state.currentStep.name,
        'currentStepIndex': state.currentStepIndex,
        'message': state.resultMessage,
      });
    } else {
      _failVerification(message);
    }
  }

  void _failVerification(String message) {
    _log.warn('Verification flow failed', context: {
      'message': message,
      'priorStep': state.currentStep.name,
      'priorStepIndex': state.currentStepIndex,
    });
    final verificationIndex = ZkIdentityStep.verification.index;
    final updated = List<ZkIdentityStepState>.from(state.steps);
    updated[verificationIndex] = updated[verificationIndex].copyWith(
      status: ZkIdentityStepVisualStatus.failed,
    );
    state = ZkIdentityFlowState(
      steps: updated,
      currentStepIndex: verificationIndex,
      resultMessage: message,
      isSuccess: false,
    );
    _ref.read(zkIdentityChallengeActiveProvider.notifier).state = false;
    _log.warn('Flow state after failure', context: {
      'currentStep': state.currentStep.name,
      'currentStepIndex': state.currentStepIndex,
      'message': state.resultMessage,
    });
  }

  void reset() {
    _log.warn('Resetting zk identity flow', context: {
      'priorStep': state.currentStep.name,
      'priorStepIndex': state.currentStepIndex,
      'resultMessage': state.resultMessage,
      'isSuccess': state.isSuccess,
    });
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
