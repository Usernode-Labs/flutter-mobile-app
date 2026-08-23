import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/session_authority_test_helpers.dart';

class _NoopAuthRepository extends AuthRepository {
  @override
  Future<void> logout(String sessionToken) async {}
}

const _session = AuthSession(
  token: 'token-a',
  participant: Participant(
    id: 7,
    email: 'seven@example.com',
    emailConfirmed: true,
    identityHash: 'aaaaaaaaaaaaaaaa',
  ),
);

SessionController _controller(ScriptedSessionAuthority authority) =>
    SessionController(
      tokenStore: AuthTokenStore(),
      guestFlag: AuthGuestFlag(),
      repository: _NoopAuthRepository(),
      sessionAuthority: authority,
      newAuthorityId: (kind) => switch (kind) {
        'session' => 'session-a',
        'transition' => 'login-a',
        'credential' => 'credential-a',
        _ => throw StateError('Unexpected authority id: $kind'),
      },
      clearWebSessionData: () async => true,
      rotateNativeGeneration: () async => true,
      clearSessionNotifications: () async => true,
    );

ProviderContainer _container(SessionController controller) =>
    ProviderContainer(overrides: [
      identityProvider.overrideWith((ref) => controller),
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await NetworkPrefs.init();
    NetworkPrefs.setActiveBucket(null, guest: true);
    IdentitySnapshots.reset();
  });

  test('unknown settles to unauthenticated from logged-out authority',
      () async {
    final controller = _controller(ScriptedSessionAuthority([
      sessionAuthorityResponse(
        sequence: 0,
        state: loggedOutAuthorityState(),
        outcome: 'record_read',
      ),
    ]));
    final container = _container(controller);
    addTearDown(container.dispose);

    expect(container.read(authStatusProvider), AuthStatus.unknown);
    await controller.restore();
    expect(container.read(authStatusProvider), AuthStatus.unauthenticated);
  });

  test('guest authority maps to guest without signing authority', () async {
    final controller = _controller(ScriptedSessionAuthority([
      sessionAuthorityResponse(
        sequence: 0,
        state: loggedOutAuthorityState(mode: 'guest'),
        outcome: 'record_read',
      ),
    ]));
    final container = _container(controller);
    addTearDown(container.dispose);

    await controller.restore();
    expect(container.read(authStatusProvider), AuthStatus.guest);
    expect(controller.state.allowsSigning, isFalse);
  });

  test('reconciling is authenticated but account effects remain closed',
      () async {
    final controller = _controller(activationSessionAuthority(
      accountId: 'account-a',
      address: 'address-a',
    ));
    final container = _container(controller);
    addTearDown(container.dispose);

    await controller.restore();
    expect(await controller.completeLogin(_session), isTrue);
    expect(container.read(authStatusProvider), AuthStatus.authenticated);
    expect(controller.state.phase, IdentityPhase.reconciling);
    expect(controller.state.allowsSigning, isFalse);
    expect(controller.state.allowsNodeStart, isFalse);
  });

  test('ready is authenticated and opens account effects', () async {
    final controller = _controller(activationSessionAuthority(
      accountId: 'account-a',
      address: 'address-a',
    ));
    final container = _container(controller);
    addTearDown(container.dispose);

    await controller.restore();
    expect(await controller.completeLogin(_session), isTrue);
    expect(
      await controller.reconcileSucceeded(
        epoch: controller.state.epoch,
        accountId: 'account-a',
        address: 'address-a',
        participantId: 7,
        provisionedSeasonId: 1,
      ),
      isTrue,
    );

    expect(container.read(authStatusProvider), AuthStatus.authenticated);
    expect(controller.state.phase, IdentityPhase.ready);
    expect(controller.state.allowsSigning, isTrue);
    expect(controller.state.allowsNodeStart, isTrue);
  });

  test('logged-out identities never gain signing from retained account fields',
      () {
    const identity = Identity(
      epoch: 1,
      phase: IdentityPhase.unauthenticated,
      accountId: 'retained-account',
      address: 'retained-address',
    );
    expect(identity.allowsSigning, isFalse);
    expect(identity.allowsNodeStart, isFalse);
  });
}
