import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/design_system/src/zk_identity_flow_page.dart';
import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
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
  Future<void> Function()? whileStarting;
  ZkPassportLaunchResult nextResult = ZkPassportLaunchResult(
    started: true,
    requestId: 'req-1',
    message: 'ok',
    launchUri: Uri.parse('https://zkpassport.id/r?t=req-1'),
  );

  @override
  Future<ZkPassportLaunchResult> startRegistrationNonceZero(
    SessionFeatureAccess session,
  ) async {
    startCalled = true;
    await whileStarting?.call();
    return nextResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLaunchService implements ZkPassportLaunchService {
  _FakeLaunchService({required this.installed});

  bool installed;
  int launchCalls = 0;
  Uri? lastLaunchUri;

  @override
  Future<bool> isInstalled() async => installed;

  @override
  Future<bool> launchOrOpenStore(Uri launchUri) async {
    launchCalls++;
    lastLaunchUri = launchUri;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _session = SessionFeatureAccess(
  identity: SessionIdentityProjection.ready(
    nativeRevision: '1',
    participantId: 1,
    accountId: 'account-1',
    address: 'address-1',
    publicKey: 'public-key-1',
  ),
  operations: _UnusedSessionRunner(),
);

class _UnusedSessionRunner implements SessionOperationRunner {
  @override
  Future<T> run<T>(
    FutureOr<T> Function(SessionOperation operation) body,
  ) =>
      Future<T>.error(StateError('The fake flow must not run an operation.'));
}

class _FakePipelineController extends StateNotifier<ZkPassportPipelineState>
    implements ZkPassportPipelineController {
  _FakePipelineController() : super(ZkPassportPipelineState.idle());

  bool discardResult = true;
  int discardCalls = 0;

  @override
  Future<bool> discardPendingSession({
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
  _FakeLaunchService launchService,
}) _setup({
  ZkPassportLaunchResult? launchResult,
  bool appInstalled = true,
}) {
  final fakeFlow = _FakeFlowController();
  if (launchResult != null) fakeFlow.nextResult = launchResult;
  final fakePipeline = _FakePipelineController();
  final fakeLaunch = _FakeLaunchService(installed: appInstalled);

  final container = ProviderContainer(
    overrides: [
      zkPassportFlowControllerProvider.overrideWithValue(fakeFlow),
      zkPassportPipelineProvider.overrideWith((_) => fakePipeline),
      zkPassportLaunchServiceProvider.overrideWithValue(fakeLaunch),
    ],
  );

  final controller = container.read(zkIdentityStepControllerProvider.notifier);

  return (
    container: container,
    controller: controller,
    flowController: fakeFlow,
    pipelineController: fakePipeline,
    launchService: fakeLaunch,
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

    test('saved-passport flow skips setup and starts verification immediately',
        () async {
      final s = _setup();
      addTearDown(s.container.dispose);

      expect(
        await s.controller.startVerificationFromSavedPassport(_session),
        isTrue,
      );

      final updated = s.container.read(zkIdentityStepControllerProvider);
      expect(updated.currentStep, ZkIdentityStep.verification);
      expect(s.flowController.startCalled, isTrue);
      expect(updated.steps[ZkIdentityStep.checkApp.index].status,
          ZkIdentityStepVisualStatus.completed);
      expect(updated.steps[ZkIdentityStep.confirmScanned.index].status,
          ZkIdentityStepVisualStatus.completed);
      expect(updated.steps[ZkIdentityStep.readyToVerify.index].status,
          ZkIdentityStepVisualStatus.completed);
      expect(updated.steps[ZkIdentityStep.verification.index].status,
          ZkIdentityStepVisualStatus.active);
    });

    test('saved-passport flow stays put when ZK Passport is not installed',
        () async {
      final s = _setup(appInstalled: false);
      addTearDown(s.container.dispose);

      expect(
        await s.controller.startVerificationFromSavedPassport(_session),
        isFalse,
      );

      final state = s.container.read(zkIdentityStepControllerProvider);
      expect(state.currentStep, ZkIdentityStep.checkApp);
      expect(s.flowController.startCalled, isFalse);
    });

    test('reopen sends the complete active proof request back to ZK Passport',
        () async {
      final s = _setup();
      addTearDown(s.container.dispose);

      await s.controller.startVerificationFromSavedPassport(_session);
      expect(await s.controller.reopenVerificationRequest(), isTrue);

      expect(s.launchService.launchCalls, 1);
      expect(
        s.launchService.lastLaunchUri,
        Uri.parse('https://zkpassport.id/r?t=req-1'),
      );
    });

    test('triggerVerification calls startRegistrationNonceZero', () async {
      final s = _setup();
      addTearDown(s.container.dispose);

      // Advance to verification step.
      final initial = s.container.read(zkIdentityStepControllerProvider);
      s.controller.state = initial.advanceTo(ZkIdentityStep.verification.index);

      await s.controller.triggerVerification(_session);
      expect(s.flowController.startCalled, true);
    });

    test('triggerVerification is no-op when not on verification step',
        () async {
      final s = _setup();
      addTearDown(s.container.dispose);

      await s.controller.triggerVerification(_session);
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

      await s.controller.triggerVerification(_session);

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

      await s.controller.triggerVerification(_session);

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

    test('observes proof completion that arrives during the app handoff',
        () async {
      final s = _setup();
      addTearDown(s.container.dispose);
      final initial = s.container.read(zkIdentityStepControllerProvider);
      s.controller.state = initial.advanceTo(ZkIdentityStep.verification.index);
      s.flowController.whileStarting = () async {
        s.pipelineController.emitSuccess();
        await Future<void>.delayed(Duration.zero);
      };

      await s.controller.triggerVerification(_session);

      final state = s.container.read(zkIdentityStepControllerProvider);
      expect(state.currentStep, ZkIdentityStep.result);
      expect(state.isSuccess, isTrue);
    });

    test('pipeline failure sets verification step to failed', () async {
      final s = _setup();
      addTearDown(s.container.dispose);

      final initial = s.container.read(zkIdentityStepControllerProvider);
      s.controller.state = initial.advanceTo(ZkIdentityStep.verification.index);

      await s.controller.triggerVerification(_session);

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
      await s.controller.triggerVerification(_session);
      expect(s.container.read(zkIdentityChallengeActiveProvider), true);
    });

    test('pipeline completion clears zkIdentityChallengeActiveProvider',
        () async {
      final s = _setup();
      addTearDown(s.container.dispose);

      final initial = s.container.read(zkIdentityStepControllerProvider);
      s.controller.state = initial.advanceTo(ZkIdentityStep.verification.index);

      await s.controller.triggerVerification(_session);
      expect(s.container.read(zkIdentityChallengeActiveProvider), true);

      s.pipelineController.emitSuccess();
      await Future<void>.delayed(Duration.zero);

      expect(s.container.read(zkIdentityChallengeActiveProvider), false);
    });
  });
}
