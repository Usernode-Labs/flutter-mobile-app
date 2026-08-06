import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
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
/// authenticated).
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

/// True only when a session is fully established.
final isAuthenticatedProvider = Provider<bool>(
    (ref) => ref.watch(authStatusProvider) == AuthStatus.authenticated);
