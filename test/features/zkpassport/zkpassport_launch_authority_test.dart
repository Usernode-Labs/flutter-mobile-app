import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/zk_identity/models/zk_identity_models.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/repositories/zkpassport_repositories.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';
import 'package:crypto_mobile_app/features/zkpassport/services/zkpassport_services.dart';

const _identityA = Identity(
  epoch: 3,
  phase: IdentityPhase.ready,
  participantId: 7,
  accountId: 'account-a',
  address: 'ut1-account-a',
);

const _identityB = Identity(
  epoch: 4,
  phase: IdentityPhase.ready,
  participantId: 8,
  accountId: 'account-b',
  address: 'ut1-account-b',
);

ZkIdentityScope _scopeA() => ZkIdentityScope(
      network: NetworkPrefs.currentNetwork,
      bucket: NetworkPrefs.bucketForAddress(_identityA.address!),
      participantId: _identityA.participantId!,
      accountId: _identityA.accountId!,
      address: _identityA.address!,
      challengeId: 42,
    );

class _StartSessionServer extends ZkPassportSessionServerRepository {
  _StartSessionServer({
    required this.firstSessionId,
    this.releaseFirst,
  }) : super(baseUrl: 'https://example.test');

  final String firstSessionId;
  final Completer<void>? releaseFirst;
  final firstCallStarted = Completer<void>();
  int calls = 0;

  @override
  Future<ZkPassportSessionStartResponse> startSession({
    required String walletAddress,
    required String chainId,
    required int nonce,
    required bool facematchStrict,
    String? userPublicKey,
  }) async {
    calls++;
    if (!firstCallStarted.isCompleted) firstCallStarted.complete();
    if (calls == 1 && releaseFirst != null) await releaseFirst!.future;
    return ZkPassportSessionStartResponse(
      sessionId: calls == 1 ? firstSessionId : 'replacement-session',
      status: 'pending',
      launchUrl: 'zkpassport://verify/${calls == 1 ? firstSessionId : 'next'}',
    );
  }
}

class _RecordingLaunchService extends ZkPassportLaunchService {
  _RecordingLaunchService({this.result = true});

  final bool result;
  int calls = 0;

  @override
  Future<bool> launchOrOpenStore(Uri launchUri) async {
    calls++;
    return result;
  }
}

class _BlockingRuntimeSave extends ZkPassportRuntimeSessionRepository {
  final saveStarted = Completer<void>();
  final releaseSave = Completer<void>();

  @override
  Future<void> save(ZkPassportRuntimeSession session) async {
    if (!saveStarted.isCompleted) saveStarted.complete();
    await releaseSave.future;
    await super.save(session);
  }
}

class _BlockingRuntimeLoad extends ZkPassportRuntimeSessionRepository {
  final loadStarted = Completer<void>();
  final releaseLoad = Completer<void>();

  @override
  Future<ZkPassportRuntimeSession?> load({
    required ZkIdentityScope scope,
  }) async {
    if (!loadStarted.isCompleted) loadStarted.complete();
    await releaseLoad.future;
    return super.load(scope: scope);
  }
}

class _BlockingRegistrationClear extends ZkPassportRegistrationRepository {
  final clearStarted = Completer<void>();
  final releaseClear = Completer<void>();
  AccountStorageScope? clearedScope;

  @override
  Future<void> clearRegistrationForAccount({
    required AccountStorageScope scope,
  }) async {
    clearedScope = scope;
    if (!clearStarted.isCompleted) clearStarted.complete();
    await releaseClear.future;
  }
}

class _FailFirstRuntimeSave extends ZkPassportRuntimeSessionRepository {
  int attempts = 0;

  @override
  Future<void> save(ZkPassportRuntimeSession session) async {
    attempts++;
    if (attempts == 1) {
      throw StateError('injected initial runtime write failure');
    }
    await super.save(session);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      NetworkPrefs.networkKey: 'testnet',
      'testnet:accounts:index': jsonEncode([
        {
          'id': _identityA.accountId,
          'name': 'Account A',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'derivationPath': 'imported',
          'hdIndex': 0,
          'address': _identityA.address,
          'publicKey': 'public-key-a',
          'backupConfirmed': true,
          'isDemo': false,
        },
      ]),
      'testnet:accounts:activeId': _identityA.accountId!,
    });
    await NetworkPrefs.init();
    NetworkPrefs.setActiveBucket(_identityA.address, guest: false);
    IdentitySnapshots.publish(_identityA);
  });

  tearDown(IdentitySnapshots.reset);

  ProviderContainer buildContainer({
    required ZkPassportSessionServerRepository server,
    required ZkPassportLaunchService launchService,
    ZkPassportRuntimeSessionRepository? runtimeRepository,
    ZkPassportRegistrationRepository? registrationRepository,
  }) {
    return ProviderContainer(overrides: [
      zkPassportCurrentIdentityProvider.overrideWithValue(_identityA),
      zkIdentityChallengeIdProvider.overrideWithValue(42),
      zkPassportSessionServerRepositoryProvider.overrideWithValue(server),
      zkPassportLaunchServiceProvider.overrideWithValue(launchService),
      if (runtimeRepository != null)
        zkPassportRuntimeSessionRepositoryProvider
            .overrideWithValue(runtimeRepository),
      if (registrationRepository != null)
        zkPassportRegistrationRepositoryProvider
            .overrideWithValue(registrationRepository),
    ]);
  }

  test('identity change suppresses the second same-id session retry', () async {
    final releaseFirst = Completer<void>();
    final server = _StartSessionServer(
      firstSessionId: 'previous-session',
      releaseFirst: releaseFirst,
    );
    final launcher = _RecordingLaunchService();
    final container = buildContainer(server: server, launchService: launcher);
    addTearDown(() {
      container.dispose();
      server.dispose();
    });

    final pipeline = container.read(zkPassportPipelineProvider.notifier);
    final previousKey = await pipeline.markLaunchStarted(
      requestId: 'previous-session',
      facematchStrict: true,
      userPublicKey: 'public-key-a',
      launchScope: _scopeA(),
      launchAuthority: IdentityLease.capture(_identityA),
    );
    await pipeline.markLaunchDispatched(requestKey: previousKey);

    final launch = container
        .read(zkPassportFlowControllerProvider)
        .startRegistrationNonceZero();
    await server.firstCallStarted.future.timeout(const Duration(seconds: 2));
    IdentitySnapshots.publish(_identityB);
    releaseFirst.complete();

    final result = await launch;
    expect(result.started, isFalse);
    expect(result.message, contains('active account changed'));
    expect(server.calls, 1);
    expect(launcher.calls, 0);
  });

  test('launch captures A before startup restore and B cannot join it',
      () async {
    final server = _StartSessionServer(firstSessionId: 'new-session');
    final launcher = _RecordingLaunchService();
    final runtimeRepository = _BlockingRuntimeLoad();
    final container = buildContainer(
      server: server,
      launchService: launcher,
      runtimeRepository: runtimeRepository,
    );
    addTearDown(() {
      container.dispose();
      server.dispose();
    });

    final flow = container.read(zkPassportFlowControllerProvider);
    final launchA = flow.startRegistrationNonceZero();
    await runtimeRepository.loadStarted.future
        .timeout(const Duration(seconds: 2));

    IdentitySnapshots.publish(_identityB);
    final launchB = await flow.startRegistrationNonceZero();
    expect(launchB.started, isFalse);
    expect(launchB.message, contains('active account changed'));

    runtimeRepository.releaseLoad.complete();
    final resultA = await launchA;
    expect(resultA.started, isFalse);
    expect(resultA.message, contains('active account changed'));
    expect(server.calls, 0);
    expect(launcher.calls, 0);
  });

  test('identity change during runtime persistence suppresses app launch',
      () async {
    final server = _StartSessionServer(firstSessionId: 'new-session');
    final launcher = _RecordingLaunchService();
    final runtimeRepository = _BlockingRuntimeSave();
    final container = buildContainer(
      server: server,
      launchService: launcher,
      runtimeRepository: runtimeRepository,
    );
    addTearDown(() {
      container.dispose();
      server.dispose();
    });

    final launch = container
        .read(zkPassportFlowControllerProvider)
        .startRegistrationNonceZero();
    await runtimeRepository.saveStarted.future
        .timeout(const Duration(seconds: 2));
    IdentitySnapshots.publish(_identityB);
    runtimeRepository.releaseSave.complete();

    final result = await launch;
    expect(result.started, isFalse);
    expect(result.message, contains('active account changed'));
    expect(server.calls, 1);
    expect(launcher.calls, 0);
  });

  test('failed initial runtime save does not wedge the next launch', () async {
    final server = _StartSessionServer(firstSessionId: 'first-session');
    final launcher = _RecordingLaunchService(result: false);
    final runtimeRepository = _FailFirstRuntimeSave();
    final container = buildContainer(
      server: server,
      launchService: launcher,
      runtimeRepository: runtimeRepository,
    );
    addTearDown(() {
      container.dispose();
      server.dispose();
    });

    final flow = container.read(zkPassportFlowControllerProvider);
    final first = await flow.startRegistrationNonceZero();

    expect(first.started, isFalse);
    expect(first.message, contains('Unable to save'));
    expect(runtimeRepository.attempts, 1);
    expect(launcher.calls, 0);

    final second = await flow.startRegistrationNonceZero();

    expect(second.started, isFalse);
    expect(second.message, contains('Unable to open'));
    expect(runtimeRepository.attempts, 2);
    expect(launcher.calls, 1);
  });

  test('reset never clears or resets replacement B after an A clear suspends',
      () async {
    final server = _StartSessionServer(firstSessionId: 'unused-session');
    final launcher = _RecordingLaunchService();
    final registrationRepository = _BlockingRegistrationClear();
    final container = buildContainer(
      server: server,
      launchService: launcher,
      registrationRepository: registrationRepository,
    );
    addTearDown(() {
      container.dispose();
      server.dispose();
    });

    final steps = container.read(zkIdentityStepControllerProvider.notifier);
    steps.state = steps.state.advanceTo(ZkIdentityStep.verification.index);

    final reset =
        container.read(zkPassportFlowControllerProvider).resetChallengeData();
    await registrationRepository.clearStarted.future
        .timeout(const Duration(seconds: 2));
    IdentitySnapshots.publish(_identityB);
    registrationRepository.releaseClear.complete();

    expect(await reset, isFalse);
    expect(
      registrationRepository.clearedScope,
      IdentityLease.capture(_identityA).accountScope,
    );
    expect(
      container.read(zkIdentityStepControllerProvider).currentStep,
      ZkIdentityStep.verification,
    );
  });
}
