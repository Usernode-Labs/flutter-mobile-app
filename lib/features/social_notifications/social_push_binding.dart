import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';

import 'social_push_service.dart';

/// Keeps the process-level push service attached to the exact ready identity
/// owned by this ProviderContainer. The service never retains Ref/container.
final socialPushBindingProvider = Provider<void>((ref) {
  final service = SocialPushService.instance;
  final owner = Object();
  var generation = 0;
  var disposed = false;

  void detach({required bool rotateProviderToken}) {
    generation += 1;
    service.detachSession(
      owner,
      rotateProviderToken: rotateProviderToken,
      ifAlreadyUnbound: true,
    );
  }

  void attachReadyIdentity() {
    final identity = ref.read(identityProvider);
    if (identity.phase != IdentityPhase.ready ||
        identity.participantId == null) {
      return;
    }
    final expectedGeneration = ++generation;
    unawaited(() async {
      String? token;
      try {
        token = await ref.read(authTokenStoreProvider).read();
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
          ),
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
          attachReadyIdentity();
        case IdentityPhase.transitioning:
          if (previous?.isAuthenticated == true) {
            detach(rotateProviderToken: true);
          }
        case IdentityPhase.unauthenticated:
        case IdentityPhase.guest:
          detach(rotateProviderToken: true);
        case IdentityPhase.unknown:
        case IdentityPhase.reconciling:
          // Initial login and same-user season reconciliation keep a tapped
          // notification until a ready identity can validate its binding.
          break;
      }
    },
    fireImmediately: true,
  );

  final tokenChanges = AuthTokenStore.changes.listen((_) {
    if (!disposed && ref.read(identityProvider).phase == IdentityPhase.ready) {
      // The store emits only after the old bearer has been replaced/cleared.
      // Close its service lease before the async read of the new value.
      detach(rotateProviderToken: false);
      attachReadyIdentity();
    }
  });

  ref.onDispose(() {
    disposed = true;
    generation += 1;
    unawaited(tokenChanges.cancel());
    service.detachSession(owner, rotateProviderToken: false);
  });
});
