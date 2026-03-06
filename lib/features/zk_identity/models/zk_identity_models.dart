import 'package:crypto_mobile_app/design_system/src/zk_identity_flow_page.dart';

enum ZkIdentityStep {
  checkApp,
  confirmScanned,
  readyToVerify,
  verification,
  result;

  static int indexOf(ZkIdentityStep step) => step.index;
}

class ZkIdentityStepState {
  const ZkIdentityStepState({
    required this.step,
    required this.status,
  });

  final ZkIdentityStep step;
  final ZkIdentityStepVisualStatus status;

  ZkIdentityStepState copyWith({ZkIdentityStepVisualStatus? status}) {
    return ZkIdentityStepState(
      step: step,
      status: status ?? this.status,
    );
  }
}

class ZkIdentityFlowState {
  const ZkIdentityFlowState({
    required this.steps,
    required this.currentStepIndex,
    this.resultMessage,
    this.isSuccess = false,
  });

  final List<ZkIdentityStepState> steps;
  final int currentStepIndex;
  final String? resultMessage;
  final bool isSuccess;

  ZkIdentityStep get currentStep => steps[currentStepIndex].step;

  factory ZkIdentityFlowState.initial() {
    return const ZkIdentityFlowState(
      steps: [
        ZkIdentityStepState(
          step: ZkIdentityStep.checkApp,
          status: ZkIdentityStepVisualStatus.active,
        ),
        ZkIdentityStepState(
          step: ZkIdentityStep.confirmScanned,
          status: ZkIdentityStepVisualStatus.pending,
        ),
        ZkIdentityStepState(
          step: ZkIdentityStep.readyToVerify,
          status: ZkIdentityStepVisualStatus.pending,
        ),
        ZkIdentityStepState(
          step: ZkIdentityStep.verification,
          status: ZkIdentityStepVisualStatus.pending,
        ),
        ZkIdentityStepState(
          step: ZkIdentityStep.result,
          status: ZkIdentityStepVisualStatus.pending,
        ),
      ],
      currentStepIndex: 0,
    );
  }

  ZkIdentityFlowState advanceTo(int nextIndex) {
    final updated = List<ZkIdentityStepState>.from(steps);
    updated[currentStepIndex] = updated[currentStepIndex]
        .copyWith(status: ZkIdentityStepVisualStatus.completed);
    updated[nextIndex] =
        updated[nextIndex].copyWith(status: ZkIdentityStepVisualStatus.active);
    return ZkIdentityFlowState(
      steps: updated,
      currentStepIndex: nextIndex,
      resultMessage: resultMessage,
      isSuccess: isSuccess,
    );
  }
}

class ZkIdentityChallengeConfig {
  const ZkIdentityChallengeConfig({
    this.title = 'ZK Identity Verification',
    this.goal = 'Verify your identity with ZK Passport',
    this.task =
        'Use the ZK Passport app to create a zero-knowledge proof of your passport.',
    this.reward = '500',
    this.category = 'community',
    this.subCategory = 'ZK_IDENTITY_VERIFICATION',
  });

  final String title;
  final String goal;
  final String task;
  final String reward;
  final String category;
  final String subCategory;

  static const instance = ZkIdentityChallengeConfig();
  static const syntheticId = -1;
}
