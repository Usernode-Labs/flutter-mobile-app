import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:crypto_mobile_app/features/auth/data/models/me.dart';
import 'package:crypto_mobile_app/core/config/api_version_gate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

AuthSession _session(String token) => AuthSession(
      token: token,
      participant:
          const Participant(id: 1, email: 'a@b.com', emailConfirmed: true),
    );

Future<AuthStatus> _settle(ProviderContainer c) async {
  // Reading instantiates the provider, which kicks off load(); then pump the
  // event loop so the async boot resolves off `unknown`.
  c.read(authStatusProvider);
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return c.read(authStatusProvider);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('boots to unauthenticated when nothing stored', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await _settle(c), AuthStatus.unauthenticated);
  });

  test('boots to authenticated when token stored', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-1'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await _settle(c), AuthStatus.authenticated);
  });

  test('boots to guest when the cached user type is guest', () async {
    SharedPreferences.setMockInitialValues({'app:user_type': 'guest'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await _settle(c), AuthStatus.guest);
  });

  test('member and operator tiers do not boot as guest', () async {
    for (final tier in ['member', 'operator']) {
      SharedPreferences.setMockInitialValues({'app:user_type': tier});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(await _settle(c), AuthStatus.unauthenticated, reason: tier);
    }
  });

  // The legacy auth:v3:guest boolean is intentionally NOT migrated. A device
  // still holding it has no app:api_version either, so the version gate clears
  // its session and the welcome screen re-establishes the tier.
  test('legacy auth:v3:guest flag is not honoured', () async {
    SharedPreferences.setMockInitialValues({'auth:v3:guest': true});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await _settle(c), AuthStatus.unauthenticated);
  });

  test('completeLogin persists token and authenticates', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(authStatusProvider.notifier).completeLogin(_session('sess-2'));
    expect(c.read(authStatusProvider), AuthStatus.authenticated);
    expect(await c.read(authTokenStoreProvider).read(), 'sess-2');
  });

  test('continueAsGuest sets guest', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(authStatusProvider.notifier).continueAsGuest();
    expect(c.read(authStatusProvider), AuthStatus.guest);
  });

  test('onUnauthorized clears token and unauthenticates', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-1'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(authStatusProvider.notifier).onUnauthorized();
    expect(c.read(authStatusProvider), AuthStatus.unauthenticated);
    expect(await c.read(authTokenStoreProvider).read(), isNull);
  });

  group('user type cache write-through', () {
    test('completeLogin caches member, never operator', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await _settle(c);
      await c.read(authStatusProvider.notifier).completeLogin(_session('s'));
      // A fresh session must not be cached as operator on the strength of a
      // leftover local key — that is what would start block production.
      expect(await c.read(userTypeStoreProvider).read(), UserLevel.member);
    });

    test('continueAsGuest caches guest', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await _settle(c);
      await c.read(authStatusProvider.notifier).continueAsGuest();
      expect(await c.read(userTypeStoreProvider).read(), UserLevel.guest);
    });

    test('logout and onUnauthorized clear the cached tier', () async {
      for (final viaLogout in [true, false]) {
        SharedPreferences.setMockInitialValues({});
        FlutterSecureStorage.setMockInitialValues({});
        final c = ProviderContainer();
        addTearDown(c.dispose);
        await _settle(c);
        await c.read(authStatusProvider.notifier).completeLogin(_session('s'));
        expect(await c.read(userTypeStoreProvider).read(), isNotNull);

        final n = c.read(authStatusProvider.notifier);
        if (viaLogout) {
          await n.logout();
        } else {
          await n.onUnauthorized();
        }
        expect(await c.read(userTypeStoreProvider).read(), isNull,
            reason: viaLogout ? 'logout' : 'onUnauthorized');
      }
    });

    test('both resolution paths stamp the api version', () async {
      for (final guest in [true, false]) {
        SharedPreferences.setMockInitialValues({});
        FlutterSecureStorage.setMockInitialValues({});
        final c = ProviderContainer();
        addTearDown(c.dispose);
        await _settle(c);
        final n = c.read(authStatusProvider.notifier);
        if (guest) {
          await n.continueAsGuest();
        } else {
          await n.completeLogin(_session('s'));
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        expect(prefs.getInt(kApiVersionKey), kCurrentApiVersion,
            reason: guest ? 'guest' : 'login');
      }
    });
  });

  // A /me write-through is async. One issued for the old session must never
  // land after logout and restore a privileged tier.
  test('cacheConfirmedLevel is discarded when the session changed', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    final n = c.read(authStatusProvider.notifier);
    await n.completeLogin(_session('s'));

    final inFlight = n.cacheConfirmedLevel(UserLevel.operator);
    await n.logout();
    await inFlight;

    expect(await c.read(userTypeStoreProvider).read(), isNull,
        reason: 'operator tier must not survive logout');
  });

  test('cacheConfirmedLevel is ignored when not authenticated', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(authStatusProvider.notifier).continueAsGuest();
    await c
        .read(authStatusProvider.notifier)
        .cacheConfirmedLevel(UserLevel.operator);
    expect(await c.read(userTypeStoreProvider).read(), UserLevel.guest);
  });

  test('cacheConfirmedLevel persists an operator for a live session', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    final n = c.read(authStatusProvider.notifier);
    await n.completeLogin(_session('s'));
    await n.cacheConfirmedLevel(UserLevel.operator);
    expect(await c.read(userTypeStoreProvider).read(), UserLevel.operator);
  });

  // Two writes inside one session: an older operator completing after a newer
  // member must not leave the privileged tier behind.
  test('concurrent cacheConfirmedLevel writes are last-write-wins', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    final n = c.read(authStatusProvider.notifier);
    await n.completeLogin(_session('s'));

    final first = n.cacheConfirmedLevel(UserLevel.operator);
    final second = n.cacheConfirmedLevel(UserLevel.member);
    await Future.wait([first, second]);

    expect(await c.read(userTypeStoreProvider).read(), UserLevel.member);
  });

  // The dangerous interleaving: a /me write-through issued for the old session
  // racing a continueAsGuest. The store must end up `guest`, never empty —
  // empty is not read as guest, so the node would treat it as producing.
  test('stale write racing continueAsGuest leaves guest, not empty', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    final n = c.read(authStatusProvider.notifier);
    await n.completeLogin(_session('s'));

    final stale = n.cacheConfirmedLevel(UserLevel.operator);
    await n.logout();
    await n.continueAsGuest();
    await stale;

    expect(await c.read(userTypeStoreProvider).read(), UserLevel.guest);
    expect(await c.read(userTypeStoreProvider).isGuest(), true);
  });

  // Ordering must follow call order, not completion order. A slow logout
  // (network round trip) called before continueAsGuest must not land its clear
  // afterwards and wipe the newer guest tier.
  test('a slow logout cannot overtake a later continueAsGuest', () async {
    final c = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(_SlowLogoutRepository()),
    ]);
    addTearDown(c.dispose);
    await _settle(c);
    final n = c.read(authStatusProvider.notifier);
    await n.completeLogin(_session('s'));

    final slowLogout = n.logout();
    final guest = n.continueAsGuest();
    await Future.wait([slowLogout, guest]);

    expect(c.read(authStatusProvider), AuthStatus.guest);
    expect(await c.read(userTypeStoreProvider).read(), UserLevel.guest);
  });

  // The cached tier must be invalidated before the new status is published,
  // or a dependent recomputing on the status change reads the old session.
  test('cached tier is current the moment login publishes authenticated',
      () async {
    SharedPreferences.setMockInitialValues({'app:user_type': 'operator'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);

    UserLevel? seenAtTransition;
    c.listen<AuthStatus>(authStatusProvider, (_, next) {
      if (next == AuthStatus.authenticated) {
        seenAtTransition = c.read(cachedUserTypeProvider);
      }
    });

    await c.read(authStatusProvider.notifier).completeLogin(_session('s'));

    expect(seenAtTransition, isNot(UserLevel.operator),
        reason: 'stale operator from the previous session');
  });

  // Signing out locally must succeed even when the server call fails, or the
  // token survives on disk and the next launch restores the ended session.
  test('logout clears local session even if the remote call throws', () async {
    final c = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(_ThrowingLogoutRepository()),
    ]);
    addTearDown(c.dispose);
    await _settle(c);
    final n = c.read(authStatusProvider.notifier);
    await n.completeLogin(_session('s'));

    await n.logout();

    expect(c.read(authStatusProvider), AuthStatus.unauthenticated);
    expect(await c.read(authTokenStoreProvider).read(), isNull);
    expect(await c.read(userTypeStoreProvider).read(), isNull);
  });

  // A cached operator must not leak into the next session while its /me loads.
  test('cached tier is re-read after an auth transition', () async {
    SharedPreferences.setMockInitialValues({'app:user_type': 'operator'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    expect(c.read(cachedUserTypeProvider), UserLevel.operator);

    await c.read(authStatusProvider.notifier).logout();
    expect(c.read(cachedUserTypeProvider), isNull);

    await c.read(authStatusProvider.notifier).completeLogin(_session('s'));
    expect(c.read(cachedUserTypeProvider), UserLevel.member);
  });

  // Signing out locally must succeed even when the server call fails, or the
  // token survives on disk and the next launch restores the ended session.
  test('logout clears local session even if the remote call throws', () async {
    final c = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(_ThrowingLogoutRepository()),
    ]);
    addTearDown(c.dispose);
    await _settle(c);
    final n = c.read(authStatusProvider.notifier);
    await n.completeLogin(_session('s'));

    await n.logout();

    expect(c.read(authStatusProvider), AuthStatus.unauthenticated);
    expect(await c.read(authTokenStoreProvider).read(), isNull);
    expect(await c.read(userTypeStoreProvider).read(), isNull);
  });
}

class _SlowLogoutRepository implements AuthRepository {
  @override
  Future<void> logout(String token) =>
      Future.delayed(const Duration(milliseconds: 80));

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingLogoutRepository implements AuthRepository {
  @override
  Future<void> logout(String token) async => throw Exception('offline');

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
