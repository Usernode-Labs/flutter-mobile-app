import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/services/zkpassport_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('persistZkCompletionInOrder', () {
    test('outbox completes before optimistic registration starts', () async {
      final events = <String>[];

      await persistZkCompletionInOrder(
        persistOutbox: () async {
          events.add('outbox:start');
          await Future<void>.delayed(Duration.zero);
          events.add('outbox:done');
        },
        persistRegistration: () async {
          events.add('registration');
        },
      );

      expect(events, ['outbox:start', 'outbox:done', 'registration']);
    });

    test('an outbox failure prevents registration', () async {
      var registrationStarted = false;

      await expectLater(
        persistZkCompletionInOrder(
          persistOutbox: () async => throw StateError('write failed'),
          persistRegistration: () async {
            registrationStarted = true;
          },
        ),
        throwsStateError,
      );
      expect(registrationStarted, isFalse);
    });
  });

  group('isTerminalZkCompletionRejection', () {
    LeaderboardApiException ex(int code) =>
        LeaderboardApiException(code, 'error $code');

    test('terminal 4xx responses are rejections', () {
      expect(isTerminalZkCompletionRejection(ex(400)), isTrue);
      expect(isTerminalZkCompletionRejection(ex(404)), isTrue);
      // Duplicate nullifier / session already used.
      expect(isTerminalZkCompletionRejection(ex(409)), isTrue);
      // Closed or superseded challenge.
      expect(isTerminalZkCompletionRejection(ex(422)), isTrue);
    });

    test('retryable statuses are not terminal', () {
      // 401 is an expired/invalid session: the API layer clears the token
      // and the app re-authenticates, after which the same completion can
      // succeed — never discard the pending claim for it.
      expect(isTerminalZkCompletionRejection(ex(401)), isFalse);
      expect(isTerminalZkCompletionRejection(ex(408)), isFalse);
      expect(isTerminalZkCompletionRejection(ex(429)), isFalse);
      expect(isTerminalZkCompletionRejection(ex(500)), isFalse);
      expect(isTerminalZkCompletionRejection(ex(502)), isFalse);
      expect(isTerminalZkCompletionRejection(ex(503)), isFalse);
    });

    test('transport errors and null are not terminal', () {
      expect(isTerminalZkCompletionRejection(null), isFalse);
      expect(isTerminalZkCompletionRejection(StateError('boom')), isFalse);
      expect(isTerminalZkCompletionRejection(Exception('socket')), isFalse);
    });
  });
}
