import 'package:flutter_test/flutter_test.dart';
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
