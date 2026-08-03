import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/features/auth/data/account_api_service.dart';
import 'package:crypto_mobile_app/features/auth/data/models/me.dart';

export 'package:crypto_mobile_app/core/identity/session_controller.dart'
    show
        identityProvider,
        SessionController,
        authRepositoryProvider,
        authTokenStoreProvider,
        authGuestFlagProvider;

enum AuthStatus { unknown, unauthenticated, guest, authenticated }

/// Coarse auth view of the current [Identity]. Both [IdentityPhase.ready]
/// and [IdentityPhase.reconciling] map to [AuthStatus.authenticated] — a
/// session exists in both; whether account-scoped state can be trusted is
/// the finer-grained `identity.isSettled`, which identity-sensitive
/// consumers (router wallet gate, signer, node start) check separately.
final authStatusProvider = Provider<AuthStatus>((ref) {
  switch (ref.watch(identityProvider).phase) {
    case IdentityPhase.unknown:
    case IdentityPhase.transitioning:
      return AuthStatus.unknown;
    case IdentityPhase.unauthenticated:
      return AuthStatus.unauthenticated;
    case IdentityPhase.guest:
      return AuthStatus.guest;
    case IdentityPhase.reconciling:
    case IdentityPhase.ready:
      return AuthStatus.authenticated;
  }
});

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
    onUnauthorized: (credential) => ref
        .read(identityProvider.notifier)
        .onUnauthorized(credential: credential),
    onCredentialMissing: (epoch) =>
        ref.read(identityProvider.notifier).onCredentialMissing(epoch: epoch),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// The authenticated participant profile from `/me` (null when not
/// authenticated). Carries the backend-resolved [Me.level].
final meProvider = FutureProvider<Me?>((ref) async {
  final identity = ref.watch(identityProvider);
  if (!identity.isAuthenticated) return null;
  final me = await ref.read(accountApiServiceProvider).getMe();
  // Profile responses are identity-scoped too. Riverpod normally discards a
  // superseded FutureProvider build, but make the boundary explicit so this
  // value can never be observed under a replacement session.
  if (!identity.sameScopeAs(ref.read(identityProvider))) return null;
  return me;
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

/// True only after the authenticated identity has finished reconciling its
/// account-scoped state. Background work that can issue authenticated requests
/// should use this finer gate instead of the coarse auth status.
final isReadyAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(
    identityProvider.select(
      (identity) => identity.phase == IdentityPhase.ready,
    ),
  ),
);

/// Whether the data screens should show the "sign in to view" gate. True once
/// the session has resolved to guest/unauthenticated; `unknown` (still loading
/// at boot) returns false so the gate never flashes before the state settles.
final showSignInGateProvider = Provider<bool>((ref) {
  final status = ref.watch(authStatusProvider);
  return status == AuthStatus.guest || status == AuthStatus.unauthenticated;
});
