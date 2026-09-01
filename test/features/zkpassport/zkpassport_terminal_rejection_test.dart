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
}
