import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/block_production_store.dart';
import 'package:crypto_mobile_app/core/identity/identity_namespace_store.dart';
import 'package:crypto_mobile_app/core/identity/session_host.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/account_api_service.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/features/auth/providers/post_sign_in_sync.dart';
import 'package:crypto_mobile_app/features/onboarding/data/node_account_provisioning.dart';
import 'package:crypto_mobile_app/src/rust/account.dart';

import '../../helpers/session_authority_test_helpers.dart';

const _addressA = 'ut1useraaaaaaaa';
const _addressB = 'ut1userbbbbbbbb';
const _namespace = 'aaaaaaaaaaaaaaaa';
const _namespacedActiveId = 'testnet:user:$_namespace:accounts:activeId';

class _NoopAuthRepository extends AuthRepository {
  @override
  Future<void> logout(String sessionToken) async {}
}

AccountApiService _accountService(http.Client client) => AccountApiService(
      baseUrl: 'https://test.example.com/api/v4/mobile',
      tokenProvider: () =>
          AuthTokenStore().readForIdentity(IdentitySnapshots.current),
      httpClient: client,
    );

LeaderboardApiService _leaderboardService(http.Client client) =>
    LeaderboardApiService(
      baseUrl: 'https://test.example.com/api/v4/mobile',
      tokenProvider: () =>
          AuthTokenStore().readForIdentity(IdentitySnapshots.current),
      httpClient: client,
    );

Map<String, dynamic> _accountJson(String id, String address) => {
      'id': id,
      'name': 'Node Account',
      'createdAt': '2026-01-01T00:00:00.000',
      'derivationPath': 'imported',
      'hdIndex': 0,
      'address': address,
      'publicKey': 'utpk1$address',
      'backupConfirmed': true,
      'isDemo': false,
    };

/// A service whose `/wallet/provision` returns [address]. [provisionCalls]
/// counts round-trips so tests can assert coalescing.
LeaderboardApiService _provisionService(
  String address,
  List<int> provisionCalls, {
  int seasonId = 7,
  Completer<void>? firstCallStarted,
  Future<void>? releaseFirstCall,
}) {
  final client = MockClient((request) async {
    expect(request.url.path, endsWith('/wallet/provision'));
    provisionCalls.add(1);
    if (provisionCalls.length == 1) {
      if (firstCallStarted != null && !firstCallStarted.isCompleted) {
        firstCallStarted.complete();
      }
      if (releaseFirstCall != null) await releaseFirstCall;
    }
    return http.Response(
      jsonEncode({
        'success': true,
        'data': {
          'address': address,
          'public_key': 'utpk1$address',
          'secret_key': 'utsk1secret',
          'newly_allocated': false,
          'season_id': seasonId,
        },
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  return _leaderboardService(client);
}

LeaderboardApiService _authorityService({required int activeSeasonId}) {
  return _leaderboardService(MockClient((request) async {
    if (request.url.path.endsWith('/wallet/provision')) {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'address': _addressB,
            'public_key': 'utpk1$_addressB',
            'secret_key': 'utsk1secret',
            'newly_allocated': false,
            'season_id': 7,
            'bp_released': false,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    expect(request.url.path, endsWith('/seasons'));
    return http.Response(
      jsonEncode({
        'success': true,
        'data': [
          {
            'season_id': activeSeasonId,
            'name': 'Season $activeSeasonId',
            'is_active': true,
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  }));
}

AccountApiService _meService({
  Completer<void>? requestStarted,
  Future<void>? releaseRequest,
  int statusCode = 200,
  String? email = 'fresh@example.com',
}) {
  return _accountService(MockClient((request) async {
    expect(request.url.path, endsWith('/me'));
    if (requestStarted != null && !requestStarted.isCompleted) {
      requestStarted.complete();
    }
    if (releaseRequest != null) await releaseRequest;
    if (statusCode != 200) {
      return http.Response(
        jsonEncode({'success': false, 'error': 'temporarily unavailable'}),
        statusCode,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(
      jsonEncode({
        'success': true,
        'data': {
          'id': 99,
          'email': email,
          'email_confirmed': true,
          'display_name': 'Fresh Profile',
          'level': 'operator',
          'bp_released': true,
        },
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  }));
}

AuthSession _session(String token, {int participantId = 99}) => AuthSession(
      token: token,
      participant: Participant(
        id: participantId,
        email: 'a@b.com',
        emailConfirmed: true,
        identityHash: _namespace,
      ),
    );

SessionController _sessionController({
  String accountId = 'acc_1_b',
  String address = _addressB,
  List<Map<String, dynamic>> trailingAuthorityResponses = const [],
  ScriptedSessionAuthority? authority,
  AuthTokenStore? tokenStore,
}) =>
    SessionController(
      tokenStore: tokenStore ?? AuthTokenStore(),
      guestFlag: AuthGuestFlag(),
      repository: _NoopAuthRepository(),
      sessionAuthority: authority ??
          activationSessionAuthority(
            accountId: accountId,
            address: address,
            userNamespace: _namespace,
            trailingResponses: trailingAuthorityResponses,
          ),
      sessionHost: const InlineSessionHostLifecycle(),
      newAuthorityId: (kind) => switch (kind) {
        'session' => 'session-a',
        'transition' => 'login-a',
        'credential' => 'credential-a',
        'rollback' => 'logged-out-b',
        'successor' => 'logged-out-b',
        'retirement' => 'retire-a',
        _ => throw StateError('Unexpected authority id: $kind'),
      },
      retireRuntimeAuthority: ({
        required directory,
        required expectedSequence,
        required sessionId,
        required successorLoggedOutSessionId,
        required successorNetwork,
        required transitionId,
      }) async {},
      clearWebSessionData: () async => true,
      clearSessionNotifications: () async => true,
    );

Override _identityOverride({
  String accountId = 'acc_1_b',
  String address = _addressB,
  List<Map<String, dynamic>> trailingAuthorityResponses = const [],
  ScriptedSessionAuthority? authority,
  AuthTokenStore? tokenStore,
}) =>
    identityProvider.overrideWith(
      (ref) => _sessionController(
        accountId: accountId,
        address: address,
        trailingAuthorityResponses: trailingAuthorityResponses,
        authority: authority,
        tokenStore: tokenStore,
      ),
    );

Future<void> _login(ProviderContainer c, {String token = 'sess-1'}) async {
  await c.read(identityProvider.notifier).restore();
  expect(await c.read(identityProvider.notifier).completeLogin(_session(token)),
      isTrue);
  expect(c.read(identityProvider).phase, IdentityPhase.reconciling);
}

/// Overrides the reconciler with a no-op node binding (the default touches
/// the Rust backend).
Override _reconcilerOverride({
  Future<void> Function()? ensureNodeIdentity,
  Identity Function()? currentIdentity,
}) =>
    nodeAccountReconcilerProvider.overrideWith(
      (ref) => NodeAccountReconciler(
        ref,
        ensureNodeIdentity: ensureNodeIdentity ?? () async {},
        currentIdentity: currentIdentity,
        accountAuthorityIdentity: (identity) => identity.copyWith(
          sessionId: 'session-test',
          credentialRef: 'credential-test',
          credentialGeneration: 1,
        ),
        accountsRepository: () async {
          await saveIdentityNamespace(_namespace);
          final repository = await AccountsRepository.create(
            accountDeriver: ({required secretKey}) => const AccountExport(
              secretKey: 'utsk1secret',
              publicKey: 'utpk1$_addressB',
              address: _addressB,
            ),
          );
          const secure = FlutterSecureStorage();
          final prefs = await SharedPreferences.getInstance();
          final namespaced = prefs.getString(
            'testnet:user:$_namespace:accounts:index',
          );
          final accounts = namespaced == null
              ? <Map<String, dynamic>>[]
              : (jsonDecode(namespaced) as List<dynamic>)
                  .cast<Map<String, dynamic>>();
          final legacy = prefs.getString('testnet:accounts:index');
          if (legacy != null) {
            accounts.addAll(
              (jsonDecode(legacy) as List<dynamic>)
                  .cast<Map<String, dynamic>>(),
            );
          }
          for (final account in accounts) {
            await secure.write(
              key: 'testnet:account:${account['id']}:address',
              value: account['address'] as String,
            );
            await secure.write(
              key: 'testnet:account:${account['id']}:secretKey',
              value: 'utsk1secret',
            );
          }
          return repository;
        },
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const guestPidKey = 'testnet:acct:guest:leaderboard:participant_id';
  const markerKey = 'testnet:account:reconcile_pending';

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await NetworkPrefs.init();
    NetworkPrefs.setActiveBucket(null, guest: true);
    IdentitySnapshots.reset();
  });

  tearDown(() {
    NetworkPrefs.setActiveBucket(null, guest: true);
    IdentitySnapshots.reset();
  });

  test('does nothing when the identity is not reconciling', () async {
    final provisionCalls = <int>[];
    final container = ProviderContainer(overrides: [
      _identityOverride(),
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      _reconcilerOverride(),
    ]);
    addTearDown(container.dispose);

    // Boot as unauthenticated (no token, no guest flag).
    container.read(identityProvider);
    await container.read(identityProvider.notifier).restore();

    final committed =
        await container.read(nodeAccountReconcilerProvider).reconcile();

    expect(committed, isFalse);
    expect(provisionCalls, isEmpty);
  });

  test(
      'activates the existing local account matching the provisioned address '
      'and settles the identity to ready', () async {
    // Legacy/corrupt registry state contains two accounts and points at the
    // wrong one. Reconcile must select the backend-provisioned address;
    // account presence alone is not ownership proof.
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_0_a', _addressA),
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_0_a',
    });
    await NetworkPrefs.init();

    final provisionCalls = <int>[];
    var nodeBinds = 0;
    final container = ProviderContainer(overrides: [
      _identityOverride(),
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      _reconcilerOverride(ensureNodeIdentity: () async => nodeBinds++),
    ]);
    addTearDown(container.dispose);

    await _login(container);

    final committed =
        await container.read(nodeAccountReconcilerProvider).reconcile();

    expect(committed, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_namespacedActiveId), 'acc_1_b');

    // The node runtime was re-bound to the reconciled account before commit.
    expect(nodeBinds, 1);

    // The identity settled to ready under B's account and season.
    final identity = container.read(identityProvider);
    expect(identity.phase, IdentityPhase.ready);
    expect(identity.address, _addressB);
    expect(identity.participantId, 99);
    expect(identity.provisionedSeasonId, 7);

    // The bucket now follows B's account, and B's staged participant id
    // was installed there (and removed from the guest bucket).
    final bucketB = NetworkPrefs.bucketForAddress(_addressB);
    expect(NetworkPrefs.activeBucket, bucketB);
    expect(
        prefs.getInt('testnet:acct:$bucketB:leaderboard:participant_id'), 99);
    expect(prefs.getInt(guestPidKey), isNull);

    // The provisioned season is persisted for rollover detection.
    expect(
        prefs.getInt('testnet:acct:$bucketB:identity:provisioned_season'), 7);

    // Reconcile completed — boot restores no longer need to re-run it.
    expect(prefs.getBool(markerKey), isNull);
  });

  test('activation reuses an exact retained legacy account without deleting it',
      () async {
    final bucketB = NetworkPrefs.bucketForAddress(_addressB);
    final legacyIndex = jsonEncode([
      _accountJson('acc_0_a', _addressA),
      _accountJson('acc_1_b', _addressB),
    ]);
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': legacyIndex,
      'testnet:accounts:activeId': 'acc_0_a',
    });
    await NetworkPrefs.init();

    final provisionCalls = <int>[];
    final provisionService = _provisionService(_addressB, provisionCalls);
    addTearDown(provisionService.dispose);

    final container = ProviderContainer(overrides: [
      _identityOverride(),
      leaderboardApiServiceProvider.overrideWithValue(provisionService),
      _reconcilerOverride(),
    ]);
    addTearDown(container.dispose);

    await _login(container);
    expect(
      await container.read(nodeAccountReconcilerProvider).reconcile(),
      isTrue,
    );
    expect(provisionCalls, hasLength(1));
    expect(container.read(identityProvider).phase, IdentityPhase.ready);
    expect(container.read(identityProvider).address, _addressB);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_namespacedActiveId), 'acc_1_b');
    expect(
      prefs.getInt('testnet:acct:$bucketB:leaderboard:participant_id'),
      99,
    );
    expect(prefs.getString('testnet:accounts:index'), legacyIndex);
    expect(prefs.getString('testnet:accounts:activeId'), 'acc_0_a');
    expect(prefs.getBool(markerKey), isNull);
  });

  test(
      'missing participant id keeps reconcile pending when /me cannot recover '
      'it', () async {
    SharedPreferences.setMockInitialValues({
      markerKey: true,
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_0_a', _addressA),
      ]),
      'testnet:accounts:activeId': 'acc_0_a',
    });
    await NetworkPrefs.init();

    final tokenStore = AuthTokenStore();
    await tokenStore.writeSessionCredential(
      const SessionCredential(
        sessionId: 'session-a',
        transitionId: 'login-a',
        credentialRef: 'credential-a',
        credentialGeneration: 1,
        token: 'sess-1',
        userNamespace: _namespace,
      ),
    );
    final sessionAuthority = ScriptedSessionAuthority([
      sessionAuthorityResponse(
        sequence: 3,
        state: activatingAuthorityState(
          phase: 'reconcile_account',
          credentialRef: 'credential-a',
          credentialGeneration: 1,
          userNamespace: _namespace,
        ),
        outcome: 'record_read',
      ),
    ]);

    final provisionCalls = <int>[];
    var nodeBinds = 0;
    final accountService = _accountService(
      MockClient(
        (_) async => http.Response('{"success":false}', 503),
      ),
    );
    final container = ProviderContainer(overrides: [
      _identityOverride(
        authority: sessionAuthority,
        tokenStore: tokenStore,
      ),
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      accountApiServiceProvider.overrideWithValue(accountService),
      _reconcilerOverride(ensureNodeIdentity: () async => nodeBinds++),
    ]);
    addTearDown(() {
      container.dispose();
      accountService.dispose();
    });

    container.read(identityProvider);
    await container.read(identityProvider.notifier).restore();
    expect(container.read(identityProvider).participantId, isNull);

    await expectLater(
      container.read(nodeAccountReconcilerProvider).reconcile(),
      throwsA(isA<AccountApiException>()),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(container.read(identityProvider).phase, IdentityPhase.reconciling);
    expect(prefs.getBool(markerKey), isTrue);
    expect(nodeBinds, 0);
    expect(provisionCalls, hasLength(1));
    expect(
      jsonDecode(prefs.getString('testnet:accounts:index')!) as List,
      hasLength(1),
    );
  });

  test('concurrent reconcile calls coalesce onto one provision round-trip',
      () async {
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_1_b',
    });
    await NetworkPrefs.init();

    final provisionCalls = <int>[];
    final container = ProviderContainer(overrides: [
      _identityOverride(),
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      _reconcilerOverride(),
    ]);
    addTearDown(container.dispose);

    await _login(container);

    final reconciler = container.read(nodeAccountReconcilerProvider);
    // Identity driver and onboarding tap racing must not double-import.
    final results =
        await Future.wait([reconciler.reconcile(), reconciler.reconcile()]);

    expect(provisionCalls.length, 1);
    expect(results, [true, true]);
  });

  test(
      'a failed node re-bind keeps the identity reconciling and the marker '
      'set so the next boot repairs the runtime identity', () async {
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_0_a', _addressA),
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_0_a',
    });
    await NetworkPrefs.init();

    final provisionCalls = <int>[];
    final container = ProviderContainer(overrides: [
      _identityOverride(),
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      _reconcilerOverride(
        ensureNodeIdentity: () async =>
            throw StateError('node failed to start'),
      ),
    ]);
    addTearDown(container.dispose);

    await _login(container);

    await expectLater(
      container.read(nodeAccountReconcilerProvider).reconcile(),
      throwsA(isA<StateError>()),
    );

    final prefs = await SharedPreferences.getInstance();
    // The registry switch itself happened, but the identity never became
    // ready and the marker survives — the next boot restore re-runs the
    // reconcile (which is idempotent) and re-binds the node.
    expect(prefs.getString(_namespacedActiveId), 'acc_1_b');
    expect(prefs.getBool(markerKey), isTrue);
    expect(container.read(identityProvider).phase, IdentityPhase.reconciling);
  });

  test('propagates provisioning failure so onboarding can surface it',
      () async {
    final client = MockClient((request) async => http.Response(
          jsonEncode({'success': false, 'error': 'No accounts available'}),
          409,
          headers: {'content-type': 'application/json'},
        ));
    final container = ProviderContainer(overrides: [
      _identityOverride(),
      leaderboardApiServiceProvider.overrideWithValue(
        _leaderboardService(client),
      ),
      _reconcilerOverride(),
    ]);
    addTearDown(container.dispose);

    await _login(container);

    await expectLater(
      container.read(nodeAccountReconcilerProvider).reconcile(),
      throwsA(isA<LeaderboardApiException>()
          .having((e) => e.statusCode, 'statusCode', 409)),
    );
    // The identity stays reconciling for the retry path.
    expect(container.read(identityProvider).phase, IdentityPhase.reconciling);
  });

  test(
      'email-less authority refresh updates ready state and permits node start',
      () async {
    final bucketB = NetworkPrefs.bucketForAddress(_addressB);
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_1_b',
    });
    await NetworkPrefs.init();

    final authority = _authorityService(activeSeasonId: 7);
    final me = _meService(email: null);
    final container = ProviderContainer(overrides: [
      _identityOverride(),
      leaderboardApiServiceProvider.overrideWithValue(authority),
      accountApiServiceProvider.overrideWithValue(me),
      _reconcilerOverride(),
    ]);
    addTearDown(() {
      container.dispose();
      authority.dispose();
      me.dispose();
    });

    await _login(container);
    final reconciler = container.read(nodeAccountReconcilerProvider);
    expect(await reconciler.reconcile(), isTrue);
    expect(await loadBlockProductionReleased(), isFalse);

    final driver = IdentityDriver(
      reconcileNodeAccount: () async {},
      retryPendingZkCompletion: () async {},
      refreshAuthoritativeState: reconciler.refreshAuthoritativeState,
    );
    addTearDown(driver.dispose);
    driver.onIdentityChanged(null, container.read(identityProvider));
    await driver.lastRun;
    expect(await driver.ensureFreshBeforeNodeStart(), isTrue);

    final profile = await container.read(meProvider.future);
    final seasons = await container.read(seasonsProvider.future);
    expect(profile?.displayName, 'Fresh Profile');
    expect(profile?.email, isEmpty);
    expect(seasons?.single.id, 7);
    expect(await loadBlockProductionReleased(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool('testnet:acct:$bucketB:bp:released'),
      isTrue,
    );
  });

  test('ready refresh re-enters reconciliation after a season rollover',
      () async {
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_1_b',
    });
    await NetworkPrefs.init();

    final authority = _authorityService(activeSeasonId: 8);
    final me = _meService();
    final container = ProviderContainer(overrides: [
      _identityOverride(),
      leaderboardApiServiceProvider.overrideWithValue(authority),
      accountApiServiceProvider.overrideWithValue(me),
      _reconcilerOverride(),
    ]);
    addTearDown(() {
      container.dispose();
      authority.dispose();
      me.dispose();
    });

    await _login(container);
    final reconciler = container.read(nodeAccountReconcilerProvider);
    expect(await reconciler.reconcile(), isTrue);
    expect(container.read(identityProvider).provisionedSeasonId, 7);

    // A live process sees the new authoritative season and closes the ready
    // gate before the next node start. The identity driver owns the ensuing
    // provision/reconcile attempt.
    expect(await reconciler.refreshAuthoritativeState(), isFalse);
    final identity = container.read(identityProvider);
    expect(identity.phase, IdentityPhase.reconciling);
    expect(identity.provisionedSeasonId, 7);
  });

  test(
      'same-account season rollover updates only the baseline and keeps the '
      'current authority', () async {
    final controller = _sessionController(
      accountId: 'account-a',
      address: _addressA,
    );
    await controller.restore();
    expect(await controller.completeLogin(_session('token-a')), isTrue);
    expect(
      await controller.reconcileSucceeded(
        epoch: controller.state.epoch,
        accountId: 'account-a',
        address: _addressA,
        participantId: 99,
        provisionedSeasonId: 7,
      ),
      isTrue,
    );
    await controller.beginSeasonRollover(activeSeasonId: 8);

    var repositoryOpens = 0;
    var nodeRebinds = 0;
    final provisionCalls = <int>[];
    final service = _provisionService(
      _addressA,
      provisionCalls,
      seasonId: 8,
    );
    final container = ProviderContainer(overrides: [
      identityProvider.overrideWith((ref) => controller),
      leaderboardApiServiceProvider.overrideWithValue(service),
      nodeAccountReconcilerProvider.overrideWith(
        (ref) => NodeAccountReconciler(
          ref,
          ensureNodeIdentity: () async => nodeRebinds++,
          accountsRepository: () async {
            repositoryOpens++;
            throw StateError('same binding must not open the repository');
          },
        ),
      ),
    ]);
    addTearDown(container.dispose);
    addTearDown(service.dispose);

    expect(
      await container.read(nodeAccountReconcilerProvider).reconcile(),
      isTrue,
    );
    expect(repositoryOpens, 0);
    expect(nodeRebinds, 0);
    expect(controller.state.phase, IdentityPhase.ready);
    expect(controller.state.address, _addressA);
    expect(controller.state.provisionedSeasonId, 8);
  });

  test(
      'changed-account season rollover retires before repository or node '
      'mutation', () async {
    final tokenStore = AuthTokenStore();
    final controller = _sessionController(
      accountId: 'account-a',
      address: _addressA,
      tokenStore: tokenStore,
      trailingAuthorityResponses: successfulRetirementResponses(),
    );
    await controller.restore();
    expect(await controller.completeLogin(_session('token-a')), isTrue);
    expect(
      await controller.reconcileSucceeded(
        epoch: controller.state.epoch,
        accountId: 'account-a',
        address: _addressA,
        participantId: 99,
        provisionedSeasonId: 7,
      ),
      isTrue,
    );
    await controller.beginSeasonRollover(activeSeasonId: 8);

    var repositoryOpens = 0;
    var nodeRebinds = 0;
    final provisionCalls = <int>[];
    final service = _provisionService(
      _addressB,
      provisionCalls,
      seasonId: 8,
    );
    final container = ProviderContainer(overrides: [
      identityProvider.overrideWith((ref) => controller),
      leaderboardApiServiceProvider.overrideWithValue(service),
      nodeAccountReconcilerProvider.overrideWith(
        (ref) => NodeAccountReconciler(
          ref,
          ensureNodeIdentity: () async => nodeRebinds++,
          accountsRepository: () async {
            repositoryOpens++;
            throw StateError('changed binding must retire first');
          },
        ),
      ),
    ]);
    addTearDown(container.dispose);
    addTearDown(service.dispose);

    expect(
      await container.read(nodeAccountReconcilerProvider).reconcile(),
      isFalse,
    );
    expect(repositoryOpens, 0);
    expect(nodeRebinds, 0);
    expect(controller.state.phase, IdentityPhase.unauthenticated);
    expect(await tokenStore.read(), isNull);
  });

  test('ready refresh preserves transient API errors for retry handling',
      () async {
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_1_b',
    });
    await NetworkPrefs.init();

    final authority = _authorityService(activeSeasonId: 7);
    final me = _meService(statusCode: 503);
    final container = ProviderContainer(overrides: [
      _identityOverride(),
      leaderboardApiServiceProvider.overrideWithValue(authority),
      accountApiServiceProvider.overrideWithValue(me),
      _reconcilerOverride(),
    ]);
    addTearDown(() {
      container.dispose();
      authority.dispose();
      me.dispose();
    });

    await _login(container);
    final reconciler = container.read(nodeAccountReconcilerProvider);
    expect(await reconciler.reconcile(), isTrue);

    await expectLater(
      reconciler.refreshAuthoritativeState(),
      throwsA(
        isA<AccountApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          503,
        ),
      ),
    );
  });

  test('delayed ready refresh cannot write after its epoch', () async {
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_1_b',
    });
    await NetworkPrefs.init();

    final requestStarted = Completer<void>();
    final releaseRequest = Completer<void>();
    addTearDown(() {
      if (!releaseRequest.isCompleted) releaseRequest.complete();
    });
    final authority = _authorityService(activeSeasonId: 7);
    final me = _meService(
      requestStarted: requestStarted,
      releaseRequest: releaseRequest.future,
    );
    late Identity currentIdentity;
    final container = ProviderContainer(overrides: [
      _identityOverride(),
      leaderboardApiServiceProvider.overrideWithValue(authority),
      accountApiServiceProvider.overrideWithValue(me),
      _reconcilerOverride(currentIdentity: () => currentIdentity),
    ]);
    addTearDown(() {
      container.dispose();
      authority.dispose();
      me.dispose();
    });

    await _login(container);
    currentIdentity = container.read(identityProvider);
    final reconciler = container.read(nodeAccountReconcilerProvider);
    expect(await reconciler.reconcile(), isTrue);
    currentIdentity = container.read(identityProvider);

    final refresh = reconciler.refreshAuthoritativeState();
    await requestStarted.future;
    currentIdentity = currentIdentity.copyWith(
      epoch: currentIdentity.epoch + 1,
      phase: IdentityPhase.transitioning,
    );
    releaseRequest.complete();
    expect(await refresh, isFalse);
    expect(await loadBlockProductionReleased(), isFalse);
  });
}
