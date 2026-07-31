import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';

void main() {
  test('unknown -> allow (loading)', () {
    expect(authRedirect(AuthStatus.unknown, AppRoutes.home), isNull);
  });
  test('unauthenticated on private route -> landing', () {
    expect(authRedirect(AuthStatus.unauthenticated, AppRoutes.home),
        AppRoutes.authLanding);
  });
  test('unauthenticated on an auth route -> allow', () {
    expect(
        authRedirect(AuthStatus.unauthenticated, AppRoutes.authEmail), isNull);
  });
  test('authenticated on an auth route -> leave to splash', () {
    expect(authRedirect(AuthStatus.authenticated, AppRoutes.authLanding),
        AppRoutes.splash);
  });
  test('authenticated on private route -> defer to existing logic (null)', () {
    expect(authRedirect(AuthStatus.authenticated, AppRoutes.home), isNull);
  });
  test('guest on a private route -> defer to existing logic (null)', () {
    expect(authRedirect(AuthStatus.guest, AppRoutes.home), isNull);
  });

  // A guest reaching the auth flow is the whole upgrade path — Settings shows
  // them a "Log in" tile that routes to the landing. Bouncing them off auth
  // routes the way we bounce authenticated users sent them landing -> splash
  // -> guestRedirect -> dapps, so the tile did nothing.
  test('guest on an auth route -> allow (upgrade path)', () {
    for (final route in [
      AppRoutes.authLanding,
      AppRoutes.authEmail,
      AppRoutes.authPassword,
      AppRoutes.authOtp,
      AppRoutes.authSetPassword,
    ]) {
      expect(authRedirect(AuthStatus.guest, route), isNull, reason: route);
    }
  });

  group('guestRedirect', () {
    test('splash -> dapps', () {
      expect(guestRedirect(AppRoutes.splash), AppRoutes.dapps);
    });
    test('onboarding routes -> dapps (never node onboarding)', () {
      expect(guestRedirect(AppRoutes.onboarding), AppRoutes.dapps);
      expect(guestRedirect(AppRoutes.onboardingWelcomeSetup), AppRoutes.dapps);
    });
    test('other app routes -> allow (null)', () {
      expect(guestRedirect(AppRoutes.dapps), isNull);
      expect(guestRedirect(AppRoutes.home), isNull);
      expect(guestRedirect(AppRoutes.profile), isNull);
    });

    // Second half of the upgrade path: authRedirect lets a guest onto an auth
    // route, so guestRedirect must not pull them back off it.
    test('auth routes -> allow (null), so the guest can log in', () {
      expect(guestRedirect(AppRoutes.authLanding), isNull);
      expect(guestRedirect(AppRoutes.authEmail), isNull);
      expect(guestRedirect(AppRoutes.authOtp), isNull);
    });
  });

  group('identityGateRedirect', () {
    test('transitioning and reconciling identities block wallet routes', () {
      for (final phase in [
        IdentityPhase.transitioning,
        IdentityPhase.reconciling,
      ]) {
        for (final route in identityGatedRoutes) {
          expect(
            identityGateRedirect(phase: phase, location: route),
            AppRoutes.home,
            reason: '${phase.name}: $route',
          );
        }
      }
    });

    test('non-wallet routes stay reachable while reconciling', () {
      for (final route in [AppRoutes.home, AppRoutes.profile]) {
        expect(
          identityGateRedirect(
            phase: IdentityPhase.reconciling,
            location: route,
          ),
          isNull,
          reason: route,
        );
      }
    });

    test('wallet routes open once the identity settles to ready', () {
      expect(
        identityGateRedirect(
          phase: IdentityPhase.ready,
          location: AppRoutes.walletSend,
        ),
        isNull,
      );
    });

    test('settled non-authenticated phases are never gated', () {
      for (final phase in [
        IdentityPhase.unknown,
        IdentityPhase.unauthenticated,
        IdentityPhase.guest,
      ]) {
        expect(
          identityGateRedirect(
            phase: phase,
            location: AppRoutes.walletSend,
          ),
          isNull,
          reason: phase.name,
        );
      }
    });
  });
}
