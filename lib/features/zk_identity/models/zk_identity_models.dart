import 'package:crypto_mobile_app/design_system/src/zk_identity_flow_page.dart';

enum ZkIdentityStep {
  checkApp,
  confirmScanned,
  readyToVerify,
  verification,
  result,
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

ZkIdentityFlowState resolveZkIdentitySuccessPresentationState(
  ZkIdentityFlowState flowState, {
  required bool pipelineSucceeded,
  required bool registrationCompleted,
  String? successMessage,
}) {
  if (flowState.currentStep == ZkIdentityStep.result) {
    return flowState;
  }
  if (!pipelineSucceeded && !registrationCompleted) {
    return flowState;
  }

  final resultIndex = ZkIdentityStep.result.index;
  final updated = List<ZkIdentityStepState>.from(flowState.steps);
  updated[flowState.currentStepIndex] =
      updated[flowState.currentStepIndex].copyWith(
    status: ZkIdentityStepVisualStatus.completed,
  );
  updated[resultIndex] = updated[resultIndex].copyWith(
    status: ZkIdentityStepVisualStatus.active,
  );

  return ZkIdentityFlowState(
    steps: updated,
    currentStepIndex: resultIndex,
    resultMessage: successMessage?.trim().isNotEmpty == true
        ? successMessage!.trim()
        : 'zkPassport proof accepted and wrapped successfully.',
    isSuccess: true,
  );
}
