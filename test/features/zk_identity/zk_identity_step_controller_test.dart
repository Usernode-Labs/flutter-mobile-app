import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/design_system/src/zk_identity_flow_page.dart';
import 'package:crypto_mobile_app/features/zk_identity/models/zk_identity_models.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';
import 'package:crypto_mobile_app/features/zkpassport/services/zkpassport_services.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeFlowController implements ZkPassportFlowController {
  bool startCalled = false;
  Completer<ZkPassportLaunchResult>? pendingResult;
  ZkPassportLaunchResult nextResult = const ZkPassportLaunchResult(
    started: true,
    requestId: 'req-1',
    message: 'ok',
  );

  @override
  Future<ZkPassportLaunchResult> startRegistrationNonceZero() {
    startCalled = true;
    return pendingResult?.future ?? Future.value(nextResult);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BlockingLaunchService extends ZkPassportLaunchService {
  final installed = Completer<bool>();

  @override
  Future<bool> isInstalled() => installed.future;
}

class _FakePipelineController extends StateNotifier<ZkPassportPipelineState>
    implements ZkPassportPipelineController {
  _FakePipelineController() : super(ZkPassportPipelineState.idle());

  bool discardResult = true;
  int discardCalls = 0;

  @override
  Future<bool> discardPendingSession({
    ZkRequestKey? requestKey,
    String? requestId,
    String? reason,
  }) async {
    discardCalls++;
    return discardResult;
  }

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
}) _setup({ZkPassportLaunchResult? launchResult}) {
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

    test('cancel leaves the active flow intact when proof discard is refused',
        () async {
      final s = _setup();
      addTearDown(s.container.dispose);
      final initial = s.container.read(zkIdentityStepControllerProvider);
      s.controller.state = initial.advanceTo(ZkIdentityStep.verification.index);
      s.container.read(zkIdentityChallengeActiveProvider.notifier).state = true;
      s.pipelineController.discardResult = false;

      expect(await s.controller.cancelVerification(), isFalse);

      expect(s.pipelineController.discardCalls, 1);
      expect(
        s.container.read(zkIdentityStepControllerProvider).currentStep,
        ZkIdentityStep.verification,
      );
      expect(s.container.read(zkIdentityChallengeActiveProvider), isTrue);
    });

    test('cancel resets the flow only after proof discard succeeds', () async {
      final s = _setup();
      addTearDown(s.container.dispose);
      final initial = s.container.read(zkIdentityStepControllerProvider);
      s.controller.state = initial.advanceTo(ZkIdentityStep.verification.index);
      s.container.read(zkIdentityChallengeActiveProvider.notifier).state = true;

      expect(await s.controller.cancelVerification(), isTrue);

      expect(s.pipelineController.discardCalls, 1);
      expect(
        s.container.read(zkIdentityStepControllerProvider).currentStep,
        ZkIdentityStep.checkApp,
      );
      expect(s.container.read(zkIdentityChallengeActiveProvider), isFalse);
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

    test('identity replacement resets flow and challenge-active state',
        () async {
      const identityA = Identity(
        epoch: 3,
        phase: IdentityPhase.ready,
        participantId: 7,
        accountId: 'account-a',
        address: 'ut1-account-a',
      );
      const identityB = Identity(
        epoch: 4,
        phase: IdentityPhase.ready,
        participantId: 8,
        accountId: 'account-b',
        address: 'ut1-account-b',
      );
      final currentIdentity = StateProvider<Identity>((_) => identityA);
      final fakeFlow = _FakeFlowController();
      final fakePipeline = _FakePipelineController();
      final container = ProviderContainer(overrides: [
        zkPassportCurrentIdentityProvider.overrideWith(
          (ref) => ref.watch(currentIdentity),
        ),
        zkPassportFlowControllerProvider.overrideWithValue(fakeFlow),
        zkPassportPipelineProvider.overrideWith((_) => fakePipeline),
      ]);
      addTearDown(container.dispose);
      final controller =
          container.read(zkIdentityStepControllerProvider.notifier);
      controller.state = ZkIdentityFlowState.initial()
          .advanceTo(ZkIdentityStep.verification.index);
      container.read(zkIdentityChallengeActiveProvider.notifier).state = true;

      container.read(currentIdentity.notifier).state = identityB;
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(zkIdentityStepControllerProvider).currentStep,
        ZkIdentityStep.checkApp,
      );
      expect(container.read(zkIdentityChallengeActiveProvider), isFalse);
    });

    test('late launch result cannot overwrite a replacement identity flow',
        () async {
      const identityA = Identity(
        epoch: 3,
        phase: IdentityPhase.ready,
        participantId: 7,
        accountId: 'account-a',
        address: 'ut1-account-a',
      );
      const identityB = Identity(
        epoch: 4,
        phase: IdentityPhase.ready,
        participantId: 8,
        accountId: 'account-b',
        address: 'ut1-account-b',
      );
      final currentIdentity = StateProvider<Identity>((_) => identityA);
      final fakeFlow = _FakeFlowController()
        ..pendingResult = Completer<ZkPassportLaunchResult>();
      final fakePipeline = _FakePipelineController();
      final container = ProviderContainer(overrides: [
        zkPassportCurrentIdentityProvider.overrideWith(
          (ref) => ref.watch(currentIdentity),
        ),
        zkPassportFlowControllerProvider.overrideWithValue(fakeFlow),
        zkPassportPipelineProvider.overrideWith((_) => fakePipeline),
      ]);
      addTearDown(container.dispose);
      final controller =
          container.read(zkIdentityStepControllerProvider.notifier);
      controller.state = ZkIdentityFlowState.initial()
          .advanceTo(ZkIdentityStep.verification.index);

      final launch = controller.triggerVerification();
      container.read(currentIdentity.notifier).state = identityB;
      await Future<void>.delayed(Duration.zero);
      fakeFlow.pendingResult!.complete(const ZkPassportLaunchResult(
        started: false,
        requestId: null,
        message: 'A launch failed late',
      ));
      await launch;

      final state = container.read(zkIdentityStepControllerProvider);
      expect(state.currentStep, ZkIdentityStep.checkApp);
      expect(state.resultMessage, isNull);
      expect(container.read(zkIdentityChallengeActiveProvider), isFalse);
    });

    test('late app-install result cannot advance a replacement identity flow',
        () async {
      const identityA = Identity(
        epoch: 3,
        phase: IdentityPhase.ready,
        participantId: 7,
        accountId: 'account-a',
        address: 'ut1-account-a',
      );
      const identityB = Identity(
        epoch: 4,
        phase: IdentityPhase.ready,
        participantId: 8,
        accountId: 'account-b',
        address: 'ut1-account-b',
      );
      final currentIdentity = StateProvider<Identity>((_) => identityA);
      final launchService = _BlockingLaunchService();
      final container = ProviderContainer(overrides: [
        zkPassportCurrentIdentityProvider.overrideWith(
          (ref) => ref.watch(currentIdentity),
        ),
        zkPassportLaunchServiceProvider.overrideWithValue(launchService),
      ]);
      addTearDown(container.dispose);
      final controller =
          container.read(zkIdentityStepControllerProvider.notifier);

      final check = controller.checkAppInstalled();
      container.read(currentIdentity.notifier).state = identityB;
      await Future<void>.delayed(Duration.zero);
      launchService.installed.complete(true);

      expect(await check, isFalse);
      expect(
        container.read(zkIdentityStepControllerProvider).currentStep,
        ZkIdentityStep.checkApp,
      );
    });
  });
}
