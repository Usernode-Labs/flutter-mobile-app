import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/config/api_version_gate.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/features/auth/data/account_api_service.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/models/me.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';

final _log = LoggingService.instance.withTag('usernode/Auth');

enum AuthStatus { unknown, unauthenticated, guest, authenticated }

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());

final authTokenStoreProvider =
    Provider<AuthTokenStore>((ref) => AuthTokenStore());

final userTypeStoreProvider = Provider<UserTypeStore>((ref) => UserTypeStore());

final authStatusProvider =
    StateNotifierProvider<AuthStatusNotifier, AuthStatus>((ref) {
  return AuthStatusNotifier(
    tokenStore: ref.watch(authTokenStoreProvider),
    userTypeStore: ref.watch(userTypeStoreProvider),
    repository: ref.watch(authRepositoryProvider),
  )..load();
});

class AuthStatusNotifier extends StateNotifier<AuthStatus> {
  AuthStatusNotifier({
    required AuthTokenStore tokenStore,
    required UserTypeStore userTypeStore,
    required AuthRepository repository,
  })  : _tokenStore = tokenStore,
        _userTypeStore = userTypeStore,
        _repository = repository,
        super(AuthStatus.unknown);

  final AuthTokenStore _tokenStore;
  final UserTypeStore _userTypeStore;
  final AuthRepository _repository;

  /// Bumped on every identity transition, inside the serialised block so it
  /// always reflects the last transition that actually ran.
  ///
  /// A `/me` write-through is async: one issued for the previous session can
  /// still be queued when a logout runs. Without this guard it would restore a
  /// privileged `operator` tier after sign-out.
  int _generation = 0;

  /// Sequence number for `/me` write-throughs.
  int _writeSeq = 0;

  /// Serialises **every** identity transition and tier write.
  ///
  /// The chain slot is reserved synchronously at invocation, so ordering
  /// follows call order rather than however long each transition's network and
  /// storage work happens to take. Reserving it late was subtly wrong: a slow
  /// `logout()` awaiting its repository call could enqueue its clear *after* a
  /// `continueAsGuest()` that was called later, wiping the newer tier.
  ///
  /// Wiping matters more than it looks: an empty store is not read as `guest`
  /// (`UserTypeStore.isGuest`), so the node would treat the session as
  /// producing.
  Future<void> _chain = Future<void>.value();

  Future<void> _serialise(Future<void> Function() action) {
    final next = _chain.then((_) => action());
    _chain = next.catchError((_) {});
    return next;
  }

  Future<void> load() async {
    final token = await _tokenStore.read();
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      state = AuthStatus.authenticated;
      return;
    }
    final guest = await _userTypeStore.isGuest();
    if (!mounted) return;
    state = guest ? AuthStatus.guest : AuthStatus.unauthenticated;
  }

  Future<void> completeLogin(AuthSession session) => _serialise(() async {
        _generation++;
        await _tokenStore.write(session.token);
        // Conservative until `/me` confirms otherwise: a fresh session is a
        // member, never an operator, so nothing starts producing blocks on the
        // strength of a stale local key alone.
        await _userTypeStore.write(UserLevel.member);
        await refreshActiveAccountBucket(guest: false);
        await markApiVersionCurrent();
        state = AuthStatus.authenticated;
      });

  Future<void> continueAsGuest() => _serialise(() async {
        _generation++;
        await _userTypeStore.write(UserLevel.guest);
        await refreshActiveAccountBucket(guest: true);
        await markApiVersionCurrent();
        state = AuthStatus.guest;
      });

  Future<void> logout() => _serialise(() async {
        _generation++;
        final token = await _tokenStore.read();
        if (token != null && token.isNotEmpty) {
          // Best effort. Signing out locally must succeed even when the server
          // is unreachable or rejects the call — otherwise a failed request
          // leaves the token on disk and the next launch silently restores the
          // session the user just ended.
          try {
            await _repository.logout(token);
          } catch (e) {
            _log.warn(
                'Remote logout failed; clearing local session anyway: $e');
          }
        }
        await _tokenStore.clear();
        await _userTypeStore.clear();
        await refreshActiveAccountBucket(guest: false);
        state = AuthStatus.unauthenticated;
      });

  Future<void> onUnauthorized() => _serialise(() async {
        _generation++;
        await _tokenStore.clear();
        await _userTypeStore.clear();
        await refreshActiveAccountBucket(guest: false);
        state = AuthStatus.unauthenticated;
      });

  /// Persists a `/me`-confirmed tier.
  ///
  /// Last-write-wins: a superseded or wrong-generation write is dropped before
  /// it touches the store. Because identity transitions share this chain, a
  /// stale write can never land on top of a newer tier, so there is nothing to
  /// undo afterwards.
  Future<void> cacheConfirmedLevel(UserLevel level) {
    final seq = ++_writeSeq;
    final gen = _generation;
    return _serialise(() async {
      if (seq != _writeSeq) return; // superseded by a newer write
      if (gen != _generation) return; // session changed before our turn
      if (state != AuthStatus.authenticated) return;
      await _userTypeStore.write(level);
    });
  }
}

class AuthFlowState {
  const AuthFlowState({
    this.email,
    this.setPasswordToken,
    this.recovery = false,
  });
  final String? email;
  final String? setPasswordToken;

  /// When true, the email step skips the password branch and forces the OTP
  /// path so the user can set a new password (forgot-password recovery).
  final bool recovery;

  AuthFlowState copyWith({
    String? email,
    String? setPasswordToken,
    bool? recovery,
  }) =>
      AuthFlowState(
        email: email ?? this.email,
        setPasswordToken: setPasswordToken ?? this.setPasswordToken,
        recovery: recovery ?? this.recovery,
      );
}

final authFlowProvider = StateNotifierProvider<AuthFlowNotifier, AuthFlowState>(
    (ref) => AuthFlowNotifier());

class AuthFlowNotifier extends StateNotifier<AuthFlowState> {
  AuthFlowNotifier() : super(const AuthFlowState());

  void setEmail(String email) => state = state.copyWith(email: email);
  void setPasswordToken(String token) =>
      state = state.copyWith(setPasswordToken: token);

  /// Start a fresh flow. [recovery] true forces the forgot-password OTP path.
  void start({bool recovery = false}) =>
      state = AuthFlowState(recovery: recovery);

  void reset() => state = const AuthFlowState();
}

final accountApiServiceProvider = Provider<AccountApiService>((ref) {
  final service = AccountApiService(
    tokenProvider: () => ref.read(authTokenStoreProvider).read(),
    onUnauthorized: () =>
        ref.read(authStatusProvider.notifier).onUnauthorized(),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// The authenticated participant profile from `/me` (null when not
/// authenticated). Carries the backend-resolved [Me.level].
final meProvider = FutureProvider<Me?>((ref) async {
  if (ref.watch(authStatusProvider) != AuthStatus.authenticated) return null;
  return ref.read(accountApiServiceProvider).getMe();
});

/// The user's level (guest / member / operator). Backend-authoritative via
/// `/me`, with a local fallback until it resolves or while offline.
///
/// Whenever `/me` confirms a level, it is written through to [UserTypeStore].
/// That cache is what bootstrap and the Android background engine read to pick
/// the node mode, and neither can call `/me`; without the write-through an
/// operator would stay cached as `member` forever and never start keyed.
final userLevelProvider = Provider<UserLevel>((ref) {
  final authenticated =
      ref.watch(authStatusProvider) == AuthStatus.authenticated;
  final me = ref.watch(meProvider).valueOrNull;
  final onchain = ref.watch(hasAnyAccountProvider).valueOrNull ?? false;
  return resolveUserLevel(
    authenticated: authenticated,
    me: me,
    hasOnchainAccount: onchain,
  );
});

/// Keeps [UserTypeStore] in step with the backend-confirmed tier.
///
/// Must be kept alive explicitly (see `main.dart`, alongside
/// `backendLifecycleProvider`). Riverpod providers are lazy: [userLevelProvider]
/// and [meProvider] have no other consumers, so without this nothing would ever
/// call `/me` and the cache would sit on the login-time `member` forever —
/// meaning an operator would never start a keyed node.
///
/// Only backend-confirmed levels are persisted. The `hasOnchainAccount`
/// fallback in [resolveUserLevel] is a guess, and caching a guessed `operator`
/// is precisely the over-privilege the node gate exists to prevent.
final userLevelCacheSyncProvider = Provider<void>((ref) {
  void sync(UserLevel level) {
    if (ref.read(authStatusProvider) != AuthStatus.authenticated) return;
    if (ref.read(meProvider).valueOrNull == null) return;
    unawaited(ref.read(authStatusProvider.notifier).cacheConfirmedLevel(level));
  }

  ref.listen<UserLevel>(userLevelProvider, (_, next) => sync(next));
  sync(ref.read(userLevelProvider));
});
