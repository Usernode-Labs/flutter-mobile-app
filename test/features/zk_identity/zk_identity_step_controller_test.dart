import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/design_system/src/zk_identity_flow_page.dart';
import 'package:crypto_mobile_app/features/zk_identity/models/zk_identity_models.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeFlowController implements ZkPassportFlowController {
  bool startCalled = false;
  ZkPassportLaunchResult nextResult = const ZkPassportLaunchResult(
    started: true,
    requestId: 'req-1',
    message: 'ok',
  );

  @override
  Future<ZkPassportLaunchResult> startRegistrationNonceZero() async {
    startCalled = true;
    return nextResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePipelineController extends StateNotifier<ZkPassportPipelineState>
    implements ZkPassportPipelineController {
  _FakePipelineController() : super(ZkPassportPipelineState.idle());

  void emitSuccess() {
    state = ZkPassportPipelineState(
      status: ZkPassportPipelineStatus.success,
      phase: ZkPassportPipelinePhase.success,
      message: 'Proof verified',
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void emitFailure(String msg) {
    state = ZkPassportPipelineState(
      status: ZkPassportPipelineStatus.failure,
      phase: ZkPassportPipelinePhase.failed,
      message: msg,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [ProviderContainer] wired with fakes and returns the controller.
({
  ProviderContainer container,
  ZkIdentityStepController controller,
  _FakeFlowController flowController,
  _FakePipelineController pipelineController,
}) _setup({
  ZkPassportLaunchResult? launchResult,
}) {
  final fakeFlow = _FakeFlowController();
  if (launchResult != null) fakeFlow.nextResult = launchResult;
  final fakePipeline = _FakePipelineController();

  final container = ProviderContainer(
    overrides: [
      zkPassportFlowControllerProvider.overrideWithValue(fakeFlow),
      zkPassportPipelineProvider.overrideWith((_) => fakePipeline),
    ],
  );

  final controller = container.read(zkIdentityStepControllerProvider.notifier);

  return (
    container: container,
    controller: controller,
    flowController: fakeFlow,
    pipelineController: fakePipeline,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('resolveZkIdentitySuccessPresentationState', () {
    test('promotes verification step to success result from pipeline success',
        () {
      final flowState = ZkIdentityFlowState.initial()
          .advanceTo(ZkIdentityStep.verification.index);

      final resolved = resolveZkIdentitySuccessPresentationState(
        flowState,
        pipelineSucceeded: true,
        registrationCompleted: false,
        successMessage: 'Proof verified',
      );

      expect(resolved.currentStep, ZkIdentityStep.result);
      expect(resolved.isSuccess, true);
      expect(resolved.resultMessage, 'Proof verified');
      expect(resolved.steps[ZkIdentityStep.verification.index].status,
          ZkIdentityStepVisualStatus.completed);
      expect(resolved.steps[ZkIdentityStep.result.index].status,
          ZkIdentityStepVisualStatus.active);
    });

    test(
        'promotes verification step to success result from persisted registration',
        () {
      final flowState = ZkIdentityFlowState.initial()
          .advanceTo(ZkIdentityStep.verification.index);

      final resolved = resolveZkIdentitySuccessPresentationState(
        flowState,
        pipelineSucceeded: false,
        registrationCompleted: true,
        successMessage: '',
      );

      expect(resolved.currentStep, ZkIdentityStep.result);
      expect(resolved.isSuccess, true);
      expect(
        resolved.resultMessage,
        'zkPassport proof accepted and wrapped successfully.',
      );
    });

    test('leaves non-terminal flow unchanged without success signal', () {
      final flowState = ZkIdentityFlowState.initial()
          .advanceTo(ZkIdentityStep.verification.index);

      final resolved = resolveZkIdentitySuccessPresentationState(
        flowState,
        pipelineSucceeded: false,
        registrationCompleted: false,
      );

      expect(resolved.currentStep, ZkIdentityStep.verification);
      expect(resolved.isSuccess, false);
      expect(resolved.resultMessage, isNull);
    });
  });

  group('ZkIdentityStepController', () {
    test('initial state starts at checkApp with active status', () {
      final s = _setup();
      addTearDown(s.container.dispose);

      final state = s.container.read(zkIdentityStepControllerProvider);
      expect(state.currentStepIndex, 0);
      expect(state.currentStep, ZkIdentityStep.checkApp);
      expect(state.steps[0].status, ZkIdentityStepVisualStatus.active);
      expect(state.isSuccess, false);
      expect(state.resultMessage, isNull);
    });

    test('confirmPassportScanned advances from confirmScanned to readyToVerify',
        () {
      final s = _setup();
      addTearDown(s.container.dispose);

      // First advance to confirmScanned.
      final state = s.container.read(zkIdentityStepControllerProvider);
      // Simulate checkApp → confirmScanned via advanceTo.
      s.controller
        ..state = state.advanceTo(ZkIdentityStep.confirmScanned.index)
        ..confirmPassportScanned();

      final updated = s.container.read(zkIdentityStepControllerProvider);
      expect(updated.currentStep, ZkIdentityStep.readyToVerify);
      expect(updated.steps[ZkIdentityStep.confirmScanned.index].status,
          ZkIdentityStepVisualStatus.completed);
      expect(updated.steps[ZkIdentityStep.readyToVerify.index].status,
          ZkIdentityStepVisualStatus.active);
    });

    test('confirmPassportScanned is no-op when not on confirmScanned step', () {
      final s = _setup();
      addTearDown(s.container.dispose);

      // Still on checkApp.
      s.controller.confirmPassportScanned();
      final state = s.container.read(zkIdentityStepControllerProvider);
      expect(state.currentStep, ZkIdentityStep.checkApp);
    });

    test('confirmReady advances from readyToVerify to verification', () {
      final s = _setup();
      addTearDown(s.container.dispose);

      // Walk to readyToVerify.
      final initial = s.container.read(zkIdentityStepControllerProvider);
      s.controller.state =
          initial.advanceTo(ZkIdentityStep.readyToVerify.index);

      s.controller.confirmReady();
      final state = s.container.read(zkIdentityStepControllerProvider);
      expect(state.currentStep, ZkIdentityStep.verification);
    });

    test('triggerVerification calls startRegistrationNonceZero', () async {
      final s = _setup();
      addTearDown(s.container.dispose);

      // Advance to verification step.
      final initial = s.container.read(zkIdentityStepControllerProvider);
      s.controller.state = initial.advanceTo(ZkIdentityStep.verification.index);

      await s.controller.triggerVerification();
      expect(s.flowController.startCalled, true);
    });

    test('triggerVerification is no-op when not on verification step',
        () async {
      final s = _setup();
      addTearDown(s.container.dispose);

      await s.controller.triggerVerification();
      expect(s.flowController.startCalled, false);
    });

    test('triggerVerification fails when launch not started', () async {
      final s = _setup(
        launchResult: const ZkPassportLaunchResult(
          started: false,
          requestId: null,
          message: 'No account',
        ),
      );
      addTearDown(s.container.dispose);

      final initial = s.container.read(zkIdentityStepControllerProvider);
      s.controller.state = initial.advanceTo(ZkIdentityStep.verification.index);

      await s.controller.triggerVerification();

      final state = s.container.read(zkIdentityStepControllerProvider);
      expect(state.currentStep, ZkIdentityStep.verification);
      expect(state.isSuccess, false);
      expect(state.resultMessage, 'No account');
      expect(state.steps[ZkIdentityStep.verification.index].status,
          ZkIdentityStepVisualStatus.failed);
    });

    test('pipeline success advances to result with isSuccess=true', () async {
      final s = _setup();
      addTearDown(s.container.dispose);

      final initial = s.container.read(zkIdentityStepControllerProvider);
      s.controller.state = initial.advanceTo(ZkIdentityStep.verification.index);

      await s.controller.triggerVerification();

      // Simulate pipeline emitting success.
      s.pipelineController.emitSuccess();

      // Allow the listener to fire.
      await Future<void>.delayed(Duration.zero);

      final state = s.container.read(zkIdentityStepControllerProvider);
      expect(state.currentStep, ZkIdentityStep.result);
      expect(state.isSuccess, true);
      expect(state.steps[ZkIdentityStep.verification.index].status,
          ZkIdentityStepVisualStatus.completed);
      expect(state.steps[ZkIdentityStep.result.index].status,
          ZkIdentityStepVisualStatus.active);
    });

    test('pipeline failure sets verification step to failed', () async {
      final s = _setup();
      addTearDown(s.container.dispose);

      final initial = s.container.read(zkIdentityStepControllerProvider);
      s.controller.state = initial.advanceTo(ZkIdentityStep.verification.index);

      await s.controller.triggerVerification();

      s.pipelineController.emitFailure('Timeout');
      await Future<void>.delayed(Duration.zero);

      final state = s.container.read(zkIdentityStepControllerProvider);
      expect(state.currentStep, ZkIdentityStep.verification);
      expect(state.isSuccess, false);
      expect(state.resultMessage, 'Timeout');
      expect(state.steps[ZkIdentityStep.verification.index].status,
          ZkIdentityStepVisualStatus.failed);
    });

    test('reset returns to initial state', () async {
      final s = _setup();
      addTearDown(s.container.dispose);

      // Advance through a few steps.
      final initial = s.container.read(zkIdentityStepControllerProvider);
      s.controller.state = initial.advanceTo(ZkIdentityStep.verification.index);

      s.controller.reset();

      final state = s.container.read(zkIdentityStepControllerProvider);
      expect(state.currentStepIndex, 0);
      expect(state.currentStep, ZkIdentityStep.checkApp);
      expect(state.steps[0].status, ZkIdentityStepVisualStatus.active);
      expect(state.isSuccess, false);
    });

    test('reset clears zkIdentityChallengeActiveProvider', () async {
      final s = _setup();
      addTearDown(s.container.dispose);

      // Set active flag.
      s.container.read(zkIdentityChallengeActiveProvider.notifier).state = true;
      expect(s.container.read(zkIdentityChallengeActiveProvider), true);

      s.controller.reset();
      expect(s.container.read(zkIdentityChallengeActiveProvider), false);
    });

    test('triggerVerification sets zkIdentityChallengeActiveProvider to true',
        () async {
      final s = _setup();
      addTearDown(s.container.dispose);

      final initial = s.container.read(zkIdentityStepControllerProvider);
      s.controller.state = initial.advanceTo(ZkIdentityStep.verification.index);

      expect(s.container.read(zkIdentityChallengeActiveProvider), false);
      await s.controller.triggerVerification();
      expect(s.container.read(zkIdentityChallengeActiveProvider), true);
    });

    test('pipeline completion clears zkIdentityChallengeActiveProvider',
        () async {
      final s = _setup();
      addTearDown(s.container.dispose);

      final initial = s.container.read(zkIdentityStepControllerProvider);
      s.controller.state = initial.advanceTo(ZkIdentityStep.verification.index);

      await s.controller.triggerVerification();
      expect(s.container.read(zkIdentityChallengeActiveProvider), true);

      s.pipelineController.emitSuccess();
      await Future<void>.delayed(Duration.zero);

      expect(s.container.read(zkIdentityChallengeActiveProvider), false);
    });
  });
}
