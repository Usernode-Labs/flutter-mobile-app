import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/features/auth/providers/post_sign_in_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isSignInTransition', () {
    test('true for settled signed-out states -> authenticated', () {
      expect(
        isSignInTransition(
            AuthStatus.unauthenticated, AuthStatus.authenticated),
        isTrue,
      );
      expect(
        isSignInTransition(AuthStatus.guest, AuthStatus.authenticated),
        isTrue,
      );
    });

    test('false for boot restore (unknown -> authenticated)', () {
      expect(
        isSignInTransition(AuthStatus.unknown, AuthStatus.authenticated),
        isFalse,
      );
      expect(isSignInTransition(null, AuthStatus.authenticated), isFalse);
    });

    test('false for any transition not ending authenticated', () {
      expect(
        isSignInTransition(
            AuthStatus.authenticated, AuthStatus.unauthenticated),
        isFalse,
      );
      expect(
        isSignInTransition(AuthStatus.unauthenticated, AuthStatus.guest),
        isFalse,
      );
      expect(
        isSignInTransition(AuthStatus.authenticated, AuthStatus.authenticated),
        isFalse,
      );
    });
  });

  group('PostSignInSync', () {
    test('sign-in runs account reconcile then zk completion retry', () async {
      final calls = <String>[];
      final sync = PostSignInSync(
        reconcileNodeAccount: () async => calls.add('reconcile'),
        retryPendingZkCompletion: () async => calls.add('zk-retry'),
      );

      // The 401 -> auth landing -> successful login lifecycle: the proof
      // preserved across the 401 must be retried NOW, not on next cold start.
      sync.onAuthStatusChanged(
        AuthStatus.unauthenticated,
        AuthStatus.authenticated,
      );
      await sync.lastRun;

      expect(calls, ['reconcile', 'zk-retry']);
    });

    test('non-sign-in transitions run nothing', () async {
      final calls = <String>[];
      final sync = PostSignInSync(
        reconcileNodeAccount: () async => calls.add('reconcile'),
        retryPendingZkCompletion: () async => calls.add('zk-retry'),
      );

      sync.onAuthStatusChanged(AuthStatus.unknown, AuthStatus.authenticated);
      sync.onAuthStatusChanged(
        AuthStatus.authenticated,
        AuthStatus.unauthenticated,
      );
      expect(sync.lastRun, isNull);
      expect(calls, isEmpty);
    });

    test('a failing reconcile does not block the zk retry', () async {
      final calls = <String>[];
      final sync = PostSignInSync(
        reconcileNodeAccount: () async => throw Exception('offline'),
        retryPendingZkCompletion: () async => calls.add('zk-retry'),
      );

      sync.onAuthStatusChanged(AuthStatus.guest, AuthStatus.authenticated);
      await sync.lastRun;

      expect(calls, ['zk-retry']);
    });

    test('a failing zk retry does not propagate', () async {
      final sync = PostSignInSync(
        reconcileNodeAccount: () async {},
        retryPendingZkCompletion: () async => throw Exception('still 401'),
      );

      sync.onAuthStatusChanged(
        AuthStatus.unauthenticated,
        AuthStatus.authenticated,
      );
      // Must complete without throwing: post-sign-in sync is opportunistic
      // repair, each unit has its own recovery path.
      await sync.lastRun;
    });
  });
}
