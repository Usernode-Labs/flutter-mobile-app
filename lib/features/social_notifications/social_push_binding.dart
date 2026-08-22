import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';

import 'social_push_api.dart';
import 'social_push_service.dart';

bool canAttachSocialPushSession(Identity identity) =>
    identity.isAuthenticated && identity.participantId != null;

/// Keeps the process-level push service attached to the exact authenticated
/// identity owned by this ProviderContainer. Wallet reconciliation is not a
/// push prerequisite; participant id plus the bearer define the recipient.
/// The service never retains Ref/container.
final socialPushBindingProvider = Provider<void>((ref) {
  final service = SocialPushService.instance;
  final credentialRequestSender =
      ref.watch(sessionAuthorityGatewayProvider)?.sendCredentialRequest;
  final owner = Object();
  var generation = 0;
  var disposed = false;

  void detach({
    required bool rotateProviderToken,
    SocialPushUnregisterReason unregisterReason =
        SocialPushUnregisterReason.identityBoundary,
  }) {
    generation += 1;
    service.detachSession(
      owner,
      rotateProviderToken: rotateProviderToken,
      ifAlreadyUnbound: true,
      unregisterReason: unregisterReason,
    );
  }

  void attachAuthenticatedIdentity() {
    final identity = ref.read(identityProvider);
    if (!canAttachSocialPushSession(identity) ||
        credentialRequestSender == null) {
      return;
    }
    final expectedGeneration = ++generation;
    unawaited(() async {
      String? token;
      try {
        token =
            await ref.read(authTokenStoreProvider).readForIdentity(identity);
      } catch (_) {
        // The caller may already have detached a rotated credential. Keep the
        // service fail-closed and let the next lifecycle/token signal retry.
        return;
      }
      if (disposed || expectedGeneration != generation) return;
      final current = ref.read(identityProvider);
      if (!identity.sameScopeAs(current)) return;
      if (token == null || token.isEmpty) {
        try {
          await ref
              .read(identityProvider.notifier)
              .onCredentialMissing(epoch: identity.epoch);
        } catch (_) {
          // Identity remains fail-closed; its normal lifecycle can retry.
        }
        return;
      }
      service.attachSession(
        owner,
        SocialPushSession(
          userId: identity.participantId!,
          credential: AuthCredentialLease(
            epoch: identity.epoch,
            token: token,
            sessionId: identity.sessionId,
            credentialRef: identity.credentialRef,
            credentialGeneration: identity.credentialGeneration,
          ),
          credentialRequestSender: credentialRequestSender,
          onUnauthorized: (credential) async {
            if (disposed) return;
            await ref
                .read(identityProvider.notifier)
                .onUnauthorized(credential: credential);
          },
        ),
      );
    }());
  }

  ref.listen<Identity>(
    identityProvider,
    (previous, next) {
      switch (next.phase) {
        case IdentityPhase.ready:
        case IdentityPhase.reconciling:
          attachAuthenticatedIdentity();
        case IdentityPhase.transitioning:
          if (previous?.isAuthenticated == true) {
            // Transitioning intentionally hides its destination. The service
            // cannot safely guess whether this becomes logout, guest, a 401,
            // or a participant replacement, so use the closed fallback.
            detach(
              rotateProviderToken: true,
              unregisterReason: SocialPushUnregisterReason.identityBoundary,
            );
          }
        case IdentityPhase.unauthenticated:
        case IdentityPhase.guest:
          detach(
            rotateProviderToken: true,
            unregisterReason: SocialPushUnregisterReason.signedOut,
          );
        case IdentityPhase.unknown:
          // Restore has not identified an authenticated participant yet.
          break;
      }
    },
    fireImmediately: true,
  );

  final tokenChanges = AuthTokenStore.changes.listen((_) {
    if (!disposed && ref.read(identityProvider).isAuthenticated) {
      // The store emits only after the old bearer has been replaced/cleared.
      // Close its service lease before the async read of the new value.
      detach(rotateProviderToken: false);
      attachAuthenticatedIdentity();
    }
  });

  ref.onDispose(() {
    disposed = true;
    generation += 1;
    unawaited(tokenChanges.cancel());
    service.detachSession(owner, rotateProviderToken: false);
  });
});
