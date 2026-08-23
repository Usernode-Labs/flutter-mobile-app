import 'dart:async';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/identity/session_host.dart';
import 'package:crypto_mobile_app/core/identity/session_retirement_repair.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:crypto_mobile_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/session_authority_test_helpers.dart';

final _probeProvider = Provider<_HostProbe>((ref) {
  throw StateError('A host probe override is required');
});

final _mountedProbeProvider = Provider<_HostProbe>((ref) {
  final probe = ref.watch(_probeProvider)..mount();
  ref.onDispose(probe.dispose);
  return probe;
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await NetworkPrefs.init();
    IdentitySnapshots.reset();
    NetworkPrefs.setActiveBucket(null, guest: true);
  });

  testWidgets('A is disposed before retirement and B mounts only afterward',
      (tester) async {
    final ledger = _HostLedger();
    final oldProbe = _HostProbe('A', ledger);
    final successorProbe = _HostProbe('B', ledger);
    final retirementMayFinish = Completer<void>();
    final host = SessionHostCoordinator(
      createSuccessor: () async => _containerFor(successorProbe),
    )..mountInitial(_containerFor(oldProbe));

    await tester.pumpWidget(AppRuntimeRoot(
      sessionHost: host,
      child: const _HostView(),
    ));
    expect(find.text('A'), findsOneWidget);
    expect(oldProbe.mounted, isTrue);

    final replacement = host.replace(
      retire: () async {
        expect(oldProbe.mounted, isFalse);
        await retirementMayFinish.future;
      },
    );

    expect(oldProbe.mounted, isFalse);
    await tester.pump();
    expect(find.text('Finishing session…'), findsOneWidget);
    expect(find.text('A'), findsNothing);
    expect(successorProbe.mounted, isFalse);

    retirementMayFinish.complete();
    expect(await replacement, isNotNull);
    await tester.pump();

    expect(find.text('B'), findsOneWidget);
    expect(successorProbe.mounted, isTrue);
    expect(ledger.maximumMounted, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('retryable failure stays in-process and replays the same work',
      (tester) async {
    final ledger = _HostLedger();
    final oldProbe = _HostProbe('A', ledger);
    final successorProbe = _HostProbe('B', ledger);
    var attempts = 0;
    final host = SessionHostCoordinator(
      createSuccessor: () async => _containerFor(successorProbe),
    )..mountInitial(_containerFor(oldProbe));

    await tester.pumpWidget(AppRuntimeRoot(
      sessionHost: host,
      child: const _HostView(),
    ));

    final replacement = host.replace(
      retire: () async {
        attempts += 1;
        if (attempts == 1) {
          throw const SessionRetirementRetryableException(
            'injected realm cleanup failure',
          );
        }
      },
    );
    await tester.pump();

    expect(oldProbe.mounted, isFalse);
    expect(find.text('Session recovery needed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(successorProbe.mounted, isFalse);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(await replacement, isNotNull);
    await tester.pump();

    expect(attempts, 2);
    expect(find.text('B'), findsOneWidget);
    expect(successorProbe.mounted, isTrue);
    expect(ledger.maximumMounted, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('logout mounts one clean host that can authenticate again',
      (tester) async {
    final authority = ScriptedSessionAuthority([
      sessionAuthorityResponse(
        sequence: 5,
        state: readyAuthorityState(),
        outcome: 'record_read',
      ),
      ...successfulRetirementResponses(),
      sessionAuthorityResponse(
        sequence: 7,
        state: loggedOutAuthorityState(sessionId: 'logged-out-b'),
        outcome: 'record_read',
      ),
      sessionAuthorityResponse(
        sequence: 8,
        state: activatingAuthorityState(
          phase: 'persist_credential',
          predecessorSessionId: 'logged-out-b',
          sessionId: 'session-b',
          transitionId: 'login-b',
        ),
        outcome: 'activation_started',
      ),
      sessionAuthorityResponse(
        sequence: 9,
        state: activatingAuthorityState(
          phase: 'bind_namespace',
          predecessorSessionId: 'logged-out-b',
          sessionId: 'session-b',
          transitionId: 'login-b',
          credentialRef: 'credential-b',
          credentialGeneration: 1,
        ),
        outcome: 'activation_advanced',
      ),
      sessionAuthorityResponse(
        sequence: 10,
        state: activatingAuthorityState(
          phase: 'reconcile_account',
          predecessorSessionId: 'logged-out-b',
          sessionId: 'session-b',
          transitionId: 'login-b',
          credentialRef: 'credential-b',
          credentialGeneration: 1,
          userNamespace: 'bbbbbbbbbbbbbbbb',
        ),
        outcome: 'activation_advanced',
      ),
      sessionAuthorityResponse(
        sequence: 11,
        state: activatingAuthorityState(
          phase: 'commit_ready',
          predecessorSessionId: 'logged-out-b',
          sessionId: 'session-b',
          transitionId: 'login-b',
          credentialRef: 'credential-b',
          credentialGeneration: 1,
          userNamespace: 'bbbbbbbbbbbbbbbb',
          accountBinding: const {
            'account_id': 'account-b',
            'address': 'address-b',
          },
        ),
        outcome: 'activation_advanced',
      ),
      sessionAuthorityResponse(
        sequence: 12,
        state: {
          ...readyAuthorityState(
            accountId: 'account-b',
            address: 'address-b',
            credentialRef: 'credential-b',
            userNamespace: 'bbbbbbbbbbbbbbbb',
          ),
          'session_id': 'session-b',
        },
        outcome: 'activation_ready',
      ),
    ]);
    final tokenStore = AuthTokenStore();
    expect(
      await tokenStore.writeSessionCredential(const SessionCredential(
        sessionId: 'session-a',
        credentialRef: 'credential-a',
        credentialGeneration: 1,
        token: 'token-a',
        userNamespace: 'aaaaaaaaaaaaaaaa',
      )),
      isTrue,
    );
    final bucketA = NetworkPrefs.bucketForAddress('address-a');
    SharedPreferences.setMockInitialValues({
      NetworkPrefs.prefixAccountKeyFor(
        'leaderboard:participant_id',
        bucketA,
      ): 7,
    });

    final ledger = _HostLedger();
    final probes = <_HostProbe>[];
    final controllers = <SessionController>[];
    late final SessionHostCoordinator host;
    Future<ProviderContainer> createContainer() async {
      final probe = _HostProbe(
        probes.isEmpty ? 'authenticated A' : 'clean successor',
        ledger,
      );
      probes.add(probe);
      final container = ProviderContainer(overrides: [
        _probeProvider.overrideWithValue(probe),
        identityProvider.overrideWith((ref) {
          final controller = SessionController(
            tokenStore: tokenStore,
            guestFlag: AuthGuestFlag(),
            repository: _NoopAuthRepository(),
            sessionAuthority: authority,
            sessionHost: host,
            newAuthorityId: (kind) => switch (kind) {
              'successor' => 'logged-out-b',
              'retirement' => 'retire-a',
              'session' => 'session-b',
              'transition' => 'login-b',
              'credential' => 'credential-b',
              _ => throw StateError('Unexpected authority id: $kind'),
            },
            retireRuntimeAuthority: _retireRuntime,
            clearWebSessionData: () async => true,
            rotateNativeGeneration: () async => true,
            clearSessionNotifications: () async => true,
          );
          controllers.add(controller);
          return controller;
        }),
      ]);
      await container.read(identityProvider.notifier).restore();
      return container;
    }

    host = SessionHostCoordinator(createSuccessor: createContainer);
    final initial = await createContainer();
    host.mountInitial(initial);
    await tester.pumpWidget(AppRuntimeRoot(
      sessionHost: host,
      child: const _HostView(),
    ));
    expect(find.text('authenticated A'), findsOneWidget);

    final first = initial.read(identityProvider.notifier);
    expect(await first.logout(), isTrue);
    await tester.pump();

    final successorContainer = host.container!;
    final successor = successorContainer.read(identityProvider.notifier);
    expect(successor, isNot(same(first)));
    expect(first.mounted, isFalse);
    expect(successor.state.phase, IdentityPhase.unauthenticated);
    expect(successor.state.sessionId, 'logged-out-b');
    expect(find.text('clean successor'), findsOneWidget);

    expect(await successor.completeLogin(_sessionB), isTrue);
    expect(
      await successor.reconcileSucceeded(
        epoch: successor.state.epoch,
        accountId: 'account-b',
        address: 'address-b',
        participantId: 8,
      ),
      isTrue,
    );
    await tester.pump();

    expect(host.container, same(successorContainer));
    expect(successor.state.phase, IdentityPhase.ready);
    expect(successor.state.sessionId, 'session-b');
    expect(probes, hasLength(2));
    expect(ledger.maximumMounted, 1);
    expect(authority.responses, isEmpty);
    expect(controllers, hasLength(2));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

const _sessionB = AuthSession(
  token: 'token-b',
  participant: Participant(
    id: 8,
    email: '8@example.com',
    emailConfirmed: true,
    identityHash: 'bbbbbbbbbbbbbbbb',
  ),
);

class _NoopAuthRepository extends AuthRepository {
  @override
  Future<void> logout(String sessionToken) async {}
}

Future<void> _retireRuntime({
  required String directory,
  required int expectedSequence,
  required String sessionId,
  required String successorLoggedOutSessionId,
  required String? successorNetwork,
  required String transitionId,
}) async {}

ProviderContainer _containerFor(_HostProbe probe) => ProviderContainer(
      overrides: [_probeProvider.overrideWithValue(probe)],
    );

class _HostView extends ConsumerWidget {
  const _HostView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(home: Text(ref.watch(_mountedProbeProvider).name));
  }
}

class _HostLedger {
  int mounted = 0;
  int maximumMounted = 0;
}

class _HostProbe {
  _HostProbe(this.name, this.ledger);

  final String name;
  final _HostLedger ledger;
  bool mounted = false;

  void mount() {
    if (mounted) return;
    mounted = true;
    ledger.mounted += 1;
    if (ledger.mounted > ledger.maximumMounted) {
      ledger.maximumMounted = ledger.mounted;
    }
  }

  void dispose() {
    if (!mounted) return;
    mounted = false;
    ledger.mounted -= 1;
  }
}
