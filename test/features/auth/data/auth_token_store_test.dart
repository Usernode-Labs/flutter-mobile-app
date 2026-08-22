import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';

class _FailingSecureStorage extends FlutterSecureStorage {
  const _FailingSecureStorage();

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw StateError('secure write failed');
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw StateError('secure delete failed');
  }
}

class _StickySecureStorage extends FlutterSecureStorage {
  _StickySecureStorage(this.value);

  String? value;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      value;

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('token store write/read/clear', () async {
    final store = AuthTokenStore();
    expect(await store.read(), isNull);
    await store.write('sess-1');
    expect(await store.read(), 'sess-1');
    expect(await store.clear(), isTrue);
    expect(await store.read(), isNull);
  });

  test('successful token writes and clears each emit one change', () async {
    var changes = 0;
    final subscription = AuthTokenStore.changes.listen((_) => changes += 1);
    addTearDown(subscription.cancel);
    final store = AuthTokenStore();

    await store.write('sess-1');
    expect(changes, 1);

    await store.clear();
    expect(changes, 2);
  });

  test('failed secure-storage mutations emit no token changes', () async {
    var changes = 0;
    final subscription = AuthTokenStore.changes.listen((_) => changes += 1);
    addTearDown(subscription.cancel);
    final store = AuthTokenStore(storage: const _FailingSecureStorage());

    await expectLater(store.write('sess-1'), throwsStateError);
    await expectLater(store.clear(), throwsStateError);

    expect(changes, 0);
  });

  test('silent secure-storage deletion is not reported as cleared', () async {
    var changes = 0;
    final subscription = AuthTokenStore.changes.listen((_) => changes += 1);
    addTearDown(subscription.cancel);
    final store = AuthTokenStore(storage: _StickySecureStorage('sess-1'));

    expect(await store.clear(), isFalse);
    expect(await store.read(), 'sess-1');
    expect(changes, 0);
  });

  test('session credentials are read only through their exact durable owner',
      () async {
    final store = AuthTokenStore();
    const credential = SessionCredential(
      sessionId: 'session-a',
      transitionId: 'login-a',
      credentialRef: 'credential-a',
      credentialGeneration: 1,
      token: 'sess-a',
      userNamespace: 'aaaaaaaaaaaaaaaa',
    );

    expect(await store.writeSessionCredential(credential), isTrue);
    expect(
      await store.readSessionCredential(
        sessionId: 'session-a',
        credentialRef: 'credential-a',
        credentialGeneration: 1,
      ),
      credential,
    );
    expect(
      await store.readSessionCredential(
        sessionId: 'session-b',
        credentialRef: 'credential-a',
        credentialGeneration: 1,
      ),
      isNull,
    );
    expect(
      await store.readSessionCredential(
        sessionId: 'session-a',
        credentialRef: 'credential-a',
        credentialGeneration: 2,
      ),
      isNull,
    );
  });

  test('cold activation adopts only one credential from its transition',
      () async {
    final store = AuthTokenStore();
    const credential = SessionCredential(
      sessionId: 'session-a',
      transitionId: 'login-a',
      credentialRef: 'credential-a',
      credentialGeneration: 1,
      token: 'sess-a',
      userNamespace: 'aaaaaaaaaaaaaaaa',
    );
    expect(
        await store.readActivationCredential('session-a', 'login-a'), isNull);
    expect(await store.writeSessionCredential(credential), isTrue);
    expect(
      await store.readActivationCredential('session-a', 'login-a'),
      credential,
    );
    expect(
      () => store.readActivationCredential('session-a', 'login-b'),
      throwsStateError,
    );
  });

  test('authenticated reads resolve only the credential named by identity',
      () async {
    final store = AuthTokenStore();
    const credential = SessionCredential(
      sessionId: 'session-a',
      transitionId: 'login-a',
      credentialRef: 'credential-a',
      credentialGeneration: 1,
      token: 'sess-a',
      userNamespace: 'aaaaaaaaaaaaaaaa',
    );
    await store.writeSessionCredential(credential);
    const identity = Identity(
      epoch: 1,
      phase: IdentityPhase.reconciling,
      sessionId: 'session-a',
      credentialRef: 'credential-a',
      credentialGeneration: 1,
    );

    expect(await store.readForIdentity(identity), 'sess-a');
    expect(
      await store.readForIdentity(
        identity.copyWith(credentialGeneration: 2),
      ),
      isNull,
    );
    expect(
      await store.readForIdentity(
        const Identity(epoch: 1, phase: IdentityPhase.unauthenticated),
      ),
      isNull,
    );
  });

  test('renewal can stage a successor without overwriting the current bearer',
      () async {
    final store = AuthTokenStore();
    const current = SessionCredential(
      sessionId: 'session-a',
      transitionId: 'login-a',
      credentialRef: 'credential-a',
      credentialGeneration: 1,
      token: 'sess-a',
      userNamespace: 'aaaaaaaaaaaaaaaa',
    );
    const renewed = SessionCredential(
      sessionId: 'session-a',
      credentialRef: 'credential-b',
      credentialGeneration: 2,
      token: 'sess-b',
      userNamespace: 'aaaaaaaaaaaaaaaa',
    );

    expect(await store.writeSessionCredential(current), isTrue);
    expect(await store.writeSessionCredential(renewed), isTrue);
    expect(
      (await store.readSessionCredential(
        sessionId: 'session-a',
        credentialRef: 'credential-a',
        credentialGeneration: 1,
      ))
          ?.token,
      'sess-a',
    );
    expect(
      (await store.readSessionCredential(
        sessionId: 'session-a',
        credentialRef: 'credential-b',
        credentialGeneration: 2,
      ))
          ?.token,
      'sess-b',
    );

    expect(await store.clearSessionCredential(current), isTrue);
    expect(
      await store.readSessionCredential(
        sessionId: 'session-a',
        credentialRef: 'credential-b',
        credentialGeneration: 2,
      ),
      renewed,
    );
  });

  test('stale clear and another session cannot remove the successor bearer',
      () async {
    final store = AuthTokenStore();
    const successor = SessionCredential(
      sessionId: 'session-b',
      transitionId: 'login-b',
      credentialRef: 'credential-b',
      credentialGeneration: 1,
      token: 'sess-b',
      userNamespace: 'bbbbbbbbbbbbbbbb',
    );
    expect(await store.writeSessionCredential(successor), isTrue);

    expect(
      await store.clearSessionCredential(
        const SessionCredential(
          sessionId: 'session-b',
          transitionId: 'login-a',
          credentialRef: 'credential-b',
          credentialGeneration: 1,
          token: 'ignored',
          userNamespace: 'bbbbbbbbbbbbbbbb',
        ),
      ),
      isFalse,
    );
    expect(await store.clearSessionCredentials('session-a'), isTrue);
    expect(
      await store.readSessionCredential(
        sessionId: 'session-b',
        credentialRef: 'credential-b',
        credentialGeneration: 1,
      ),
      successor,
    );
  });

  test('guest flag set/read/clear', () async {
    final flag = AuthGuestFlag();
    expect(await flag.isGuest(), false);
    await flag.setGuest();
    expect(await flag.isGuest(), true);
    expect(await flag.clear(), isTrue);
    expect(await flag.isGuest(), false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('auth:v3:guest'), isFalse);
  });
}
