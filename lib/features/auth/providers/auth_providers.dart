import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/features/auth/data/account_api_service.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/models/me.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';

enum AuthStatus { unknown, unauthenticated, guest, authenticated }

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());

final authTokenStoreProvider =
    Provider<AuthTokenStore>((ref) => AuthTokenStore());

final authGuestFlagProvider = Provider<AuthGuestFlag>((ref) => AuthGuestFlag());

final authStatusProvider =
    StateNotifierProvider<AuthStatusNotifier, AuthStatus>((ref) {
  return AuthStatusNotifier(
    tokenStore: ref.watch(authTokenStoreProvider),
    guestFlag: ref.watch(authGuestFlagProvider),
    repository: ref.watch(authRepositoryProvider),
  )..load();
});

class AuthStatusNotifier extends StateNotifier<AuthStatus> {
  AuthStatusNotifier({
    required AuthTokenStore tokenStore,
    required AuthGuestFlag guestFlag,
    required AuthRepository repository,
  })  : _tokenStore = tokenStore,
        _guestFlag = guestFlag,
        _repository = repository,
        super(AuthStatus.unknown);

  final AuthTokenStore _tokenStore;
  final AuthGuestFlag _guestFlag;
  final AuthRepository _repository;

  Future<void> load() async {
    final token = await _tokenStore.read();
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      state = AuthStatus.authenticated;
      return;
    }
    final guest = await _guestFlag.isGuest();
    if (!mounted) return;
    state = guest ? AuthStatus.guest : AuthStatus.unauthenticated;
  }

  Future<void> completeLogin(AuthSession session) async {
    await _tokenStore.write(session.token);
    await _guestFlag.clear();
    // The retired registration flow was the only writer of the persisted
    // participant id; sessions are now the source of it. Stage it in the
    // guest bucket — NOT the active bucket, which at this point may still
    // belong to a previously signed-in user's account. The post-sign-in
    // account reconcile activates this user's account and moves the id
    // into its bucket. The v4 `user.id` is the same id every token-scoped
    // endpoint resolves from the session server-side.
    await stageParticipantIdInGuestBucket(session.participant.id);
    await refreshActiveAccountBucket(guest: false);
    state = AuthStatus.authenticated;
  }

  Future<void> continueAsGuest() async {
    await _guestFlag.setGuest();
    // A leftover staged id (interrupted earlier login) must not resolve for
    // an explicit guest session.
    await clearGuestParticipantId();
    await refreshActiveAccountBucket(guest: true);
    state = AuthStatus.guest;
  }

  Future<void> logout() async {
    final token = await _tokenStore.read();
    if (token != null && token.isNotEmpty) {
      await _repository.logout(token);
    }
    await _tokenStore.clear();
    await _guestFlag.clear();
    await clearGuestParticipantId();
    await refreshActiveAccountBucket(guest: false);
    state = AuthStatus.unauthenticated;
  }

  Future<void> onUnauthorized() async {
    await _tokenStore.clear();
    // A 401 invalidates the TOKEN, not the user's explicit guest choice —
    // re-resolve rather than forcing unauthenticated, so a stray 401 (e.g.
    // an auth-required endpoint reached while browsing as guest) doesn't
    // kick a remembered guest back to the auth landing.
    final guest = await _guestFlag.isGuest();
    await refreshActiveAccountBucket(guest: guest);
    state = guest ? AuthStatus.guest : AuthStatus.unauthenticated;
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

/// The current session token (null when none stored). Async because it reads
/// secure storage; callers that need it per-request use it directly.
final sessionTokenProvider =
    FutureProvider<String?>((ref) => ref.watch(authTokenStoreProvider).read());

/// True only when a session is fully established.
final isAuthenticatedProvider = Provider<bool>(
    (ref) => ref.watch(authStatusProvider) == AuthStatus.authenticated);

/// Whether the data screens should show the "sign in to view" gate. True once
/// the session has resolved to guest/unauthenticated; `unknown` (still loading
/// at boot) returns false so the gate never flashes before the state settles.
final showSignInGateProvider = Provider<bool>((ref) {
  final status = ref.watch(authStatusProvider);
  return status == AuthStatus.guest || status == AuthStatus.unauthenticated;
});
