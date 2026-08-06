import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

/// The full router guard as a pure function (mirrors the provider's redirect).
String? redirectFor({
  AuthStatus authStatus = AuthStatus.authenticated,
  required String location,
  Uri? requestUri,
  bool? hasAnyAccount = true,
  bool? hasCompletedOnboarding = true,
  RegistrationFreshness registrationFreshness = RegistrationFreshness.current,
}) {
  return appRedirect(
    authStatus: authStatus,
    location: location,
    requestUri: requestUri ?? Uri.parse(location),
    hasAnyAccount: hasAnyAccount,
    hasCompletedOnboarding: hasCompletedOnboarding,
    registrationFreshness: registrationFreshness,
  );
}

void main() {
  group('deep-link blocking', () {
    // usernode:// links not on the allowlist must be blocked for every
    // status that passes the auth gate (unknown, guest, authenticated).
    // Guests especially: iOS registers the scheme unrestricted, so a guest
    // session is the easiest way to smuggle a link to an internal route.
    // Unauthenticated users never get that far — the auth gate wins.
    test('guest: non-allowlisted usernode link -> /home', () {
      expect(
        redirectFor(
          authStatus: AuthStatus.guest,
          location: AppRoutes.profile,
          requestUri: Uri.parse('usernode://app/profile'),
        ),
        AppRoutes.home,
      );
    });

    test('authenticated: non-allowlisted usernode link -> /home', () {
      expect(
        redirectFor(
          location: AppRoutes.profile,
          requestUri: Uri.parse('usernode://app/profile'),
        ),
        AppRoutes.home,
      );
    });

    test('unknown (still loading): non-allowlisted usernode link -> /home', () {
      expect(
        redirectFor(
          authStatus: AuthStatus.unknown,
          location: AppRoutes.profile,
          requestUri: Uri.parse('usernode://app/profile'),
        ),
        AppRoutes.home,
      );
    });

    test('unauthenticated: blocked link loses to the auth gate -> /auth', () {
      expect(
        redirectFor(
          authStatus: AuthStatus.unauthenticated,
          location: AppRoutes.profile,
          requestUri: Uri.parse('usernode://app/profile'),
        ),
        AppRoutes.authLanding,
      );
    });

    test('guest: allowlisted usernode link -> allowed', () {
      expect(
        redirectFor(
          authStatus: AuthStatus.guest,
          location: AppRoutes.dapps,
          requestUri: Uri.parse('usernode://app/dapps'),
        ),
        isNull,
      );
    });
  });

  group('guest routing (unchanged behavior)', () {
    test('guest: in-app navigation to app routes is allowed', () {
      expect(
        redirectFor(authStatus: AuthStatus.guest, location: AppRoutes.profile),
        isNull,
      );
    });

    test('guest: splash -> dapps', () {
      expect(
        redirectFor(authStatus: AuthStatus.guest, location: AppRoutes.splash),
        AppRoutes.dapps,
      );
    });
  });

  group('account/onboarding routing (unchanged behavior)', () {
    test('loading state -> hold', () {
      expect(
        redirectFor(location: AppRoutes.home, hasAnyAccount: null),
        isNull,
      );
    });

    test('no account: splash -> onboarding welcome', () {
      expect(
        redirectFor(
          location: AppRoutes.splash,
          hasAnyAccount: false,
          hasCompletedOnboarding: false,
        ),
        AppRoutes.onboarding,
      );
    });

    test('stale registration -> stale screen', () {
      expect(
        redirectFor(
          location: AppRoutes.home,
          registrationFreshness: RegistrationFreshness.stale,
        ),
        AppRoutes.staleRegistration,
      );
    });

    test('all set: splash -> home', () {
      expect(
        redirectFor(location: AppRoutes.splash),
        AppRoutes.home,
      );
    });

    test('all set: app route allowed', () {
      expect(redirectFor(location: AppRoutes.mainNode), isNull);
    });
  });
}
