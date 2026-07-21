import 'package:flutter_test/flutter_test.dart';
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
  test('guest behaves like authenticated for the gate', () {
    expect(authRedirect(AuthStatus.guest, AppRoutes.authLanding),
        AppRoutes.splash);
    expect(authRedirect(AuthStatus.guest, AppRoutes.home), isNull);
  });
}
