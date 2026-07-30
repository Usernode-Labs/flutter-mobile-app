import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

/// Records whether the login recovery payload (reconcile-pending marker +
/// participant id staged in the guest bucket) was already persisted when the
/// token write made the session boot-restorable. A crash after the token
/// write must find the payload in place, or the boot reconcile "succeeds"
/// with nothing to migrate and the participant id is lost.
class _OrderProbeTokenStore extends AuthTokenStore {
  bool payloadPersistedBeforeTokenWrite = false;

  @override
  Future<void> write(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final stagedId = prefs.getInt(NetworkPrefs.prefixAccountKeyFor(
        'leaderboard:participant_id', NetworkPrefs.guestBucket));
    final markerSet =
        prefs.getBool(NetworkPrefs.prefixKey('account:reconcile_pending')) ??
            false;
    payloadPersistedBeforeTokenWrite = stagedId != null && markerSet;
    await super.write(token);
  }
}

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

  test('boots to guest when guest flag set', () async {
    SharedPreferences.setMockInitialValues({'auth:v3:guest': true});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await _settle(c), AuthStatus.guest);
  });

  test('completeLogin persists token and authenticates', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(authStatusProvider.notifier).completeLogin(_session('sess-2'));
    expect(c.read(authStatusProvider), AuthStatus.authenticated);
    expect(await c.read(authTokenStoreProvider).read(), 'sess-2');
  });

  test('completeLogin persists the session user id as participant id',
      () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(authStatusProvider.notifier).completeLogin(_session('sess-2'));
    // The retired registration flow was the old writer of this id; sessions
    // are now its only source (ZK completion, log sharing, token allocation
    // all key off it).
    expect(await loadParticipantId(), 1);
    expect(await c.read(participantIdProvider.future), 1);
  });

  test(
      'completeLogin persists the recovery payload before the token becomes '
      'boot-restorable (crash-atomic login)', () async {
    final probe = _OrderProbeTokenStore();
    final c = ProviderContainer(overrides: [
      authTokenStoreProvider.overrideWithValue(probe),
    ]);
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(authStatusProvider.notifier).completeLogin(_session('sess-2'));
    expect(probe.payloadPersistedBeforeTokenWrite, isTrue);
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

  test('onUnauthorized keeps a remembered guest as guest', () async {
    // A stray 401 (auth-required endpoint reached while browsing as guest)
    // invalidates the token, not the user's explicit guest choice.
    SharedPreferences.setMockInitialValues({'auth:v3:guest': true});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(authStatusProvider.notifier).onUnauthorized();
    expect(c.read(authStatusProvider), AuthStatus.guest);
  });
}
