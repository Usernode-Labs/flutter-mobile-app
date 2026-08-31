import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/wallet/models/account.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final account = AccountMeta(
      id: 'account-1',
      name: 'Test account',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1),
      derivationPath: "m/44'/60'/0'/0/0",
      hdIndex: 0,
      address: 'ut1-test-account',
      publicKey: 'utpk1-test-account',
      backupConfirmed: true,
    );
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([account.toJson()]),
      'testnet:accounts:activeId': account.id,
    });
    NetworkPrefs.resetForApplicationReset();
    await NetworkPrefs.init();
    NetworkPrefs.setActiveBucket(account.address, guest: false);
    IdentitySnapshots.reset();
    IdentitySnapshots.publish(const Identity(
      epoch: 1,
      phase: IdentityPhase.unauthenticated,
      accountId: 'account-1',
      address: 'ut1-test-account',
    ));
  });

  tearDown(IdentitySnapshots.reset);

  test('keeps the bridge session alive when automatic app handoff is refused',
      () async {
    final server = _PendingSessionServer();
    final container = ProviderContainer(overrides: [
      zkIdentityChallengeIdProvider.overrideWithValue(null),
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
        .startRegistrationNonceZero();

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
