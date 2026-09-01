import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/repositories/zkpassport_repositories.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';
import 'package:crypto_mobile_app/features/zkpassport/services/zkpassport_services.dart';

class _PendingSessionServer extends ZkPassportSessionServerRepository {
  _PendingSessionServer()
      : super(baseUrl: 'https://bridge.example.test', writesEnabled: true);

  @override
  Future<ZkPassportSessionStartResponse> startSession({
    required String walletAddress,
    required String chainId,
    required int nonce,
    required bool facematchStrict,
    String? userPublicKey,
  }) async {
    return const ZkPassportSessionStartResponse(
      sessionId: 'session-1',
      status: 'waiting',
      launchUrl: 'https://zkpassport.id/r?t=session-1',
    );
  }

  @override
  Future<ZkPassportSessionResultResponse?> tryGetSessionResult({
    required String sessionId,
    int waitMs = 0,
    String? userPublicKey,
  }) async {
    return null;
  }

  @override
  Future<ZkPassportSessionStatusResponse> getSessionStatus({
    required String sessionId,
    String? userPublicKey,
  }) async {
    return const ZkPassportSessionStatusResponse(
      sessionId: 'session-1',
      status: 'waiting',
      finalAvailable: false,
      updatedAtMs: 1,
    );
  }
}

class _RefusedLaunchService extends ZkPassportLaunchService {
  @override
  Future<bool> launchOrOpenStore(Uri launchUri) async => false;
}

final _session = SessionFeatureAccess(
  identity: SessionIdentityProjection.ready(
    nativeRevision: '1',
    participantId: 1,
    accountId: 'account-1',
    address: 'ut1-test-account',
    publicKey: 'utpk1-test-account',
  ),
  operations: _UnusedSessionRunner(),
);

class _UnusedSessionRunner implements SessionOperationRunner {
  @override
  Future<T> run<T>(
    FutureOr<T> Function(SessionOperation operation) body,
  ) =>
      Future<T>.error(
          StateError('The waiting flow must not run an operation.'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('keeps the bridge session alive when automatic app handoff is refused',
      () async {
    final server = _PendingSessionServer();
    final container = ProviderContainer(overrides: [
      zkPassportSessionServerRepositoryProvider.overrideWithValue(server),
      zkPassportLaunchServiceProvider.overrideWithValue(
        _RefusedLaunchService(),
      ),
    ]);
    addTearDown(() {
      container.dispose();
      server.dispose();
    });

    final result = await container
        .read(zkPassportFlowControllerProvider)
        .startRegistrationNonceZero(_session);

    expect(result.started, isTrue);
    expect(result.requestId, 'session-1');
    expect(
      result.launchUri,
      Uri.parse('https://zkpassport.id/r?t=session-1'),
    );
    expect(result.message, contains('Switch to the app'));

    final pipeline = container.read(zkPassportPipelineProvider);
    expect(pipeline.status, ZkPassportPipelineStatus.processing);
    expect(pipeline.phase, ZkPassportPipelinePhase.waiting);
    expect(pipeline.requestId, 'session-1');
    expect(pipeline.message, contains('Switch to the app'));
  });
}
