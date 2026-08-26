import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class _LockableSecureStorage extends FlutterSecureStorage {
  _LockableSecureStorage(Map<String, String> values) : values = Map.of(values);

  final Map<String, String> values;
  bool locked = false;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (locked && values.containsKey(key)) return null;
    return values[key];
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (locked && values.containsKey(key)) {
      throw PlatformException(
        code: 'Unexpected security result code',
        message: 'User interaction is not allowed.',
        details: -25308,
      );
    }
    return values.containsKey(key);
  }

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
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
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
    values.remove(key);
  }
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
    await store.clear();
    expect(await store.read(), isNull);
  });

  test('legacy token migrates only after the new copy is readable', () async {
    FlutterSecureStorage.setMockInitialValues({
      'auth:v3:session_token': 'sess-legacy',
    });
    final store = AuthTokenStore();

    expect(await store.read(), 'sess-legacy');
    expect(await const FlutterSecureStorage().readAll(), {
      'auth:v4:session_token': 'sess-legacy',
    });
  });

  test('a swallowed Keychain access error is unavailable, not missing',
      () async {
    final storage = _LockableSecureStorage({
      'auth:v3:session_token': 'sess-locked',
    })
      ..locked = true;
    final store = AuthTokenStore(storage: storage);

    await expectLater(
      store.read(),
      throwsA(isA<AuthTokenUnavailableException>()),
    );
    expect(storage.values['auth:v3:session_token'], 'sess-locked');

    storage.locked = false;
    expect(await store.read(), 'sess-locked');
    expect(storage.values, {
      'auth:v4:session_token': 'sess-locked',
    });
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

  test('guest flag set/read/clear', () async {
    final flag = AuthGuestFlag();
    expect(await flag.isGuest(), false);
    await flag.setGuest();
    expect(await flag.isGuest(), true);
    await flag.clear();
    expect(await flag.isGuest(), false);
  });
}
