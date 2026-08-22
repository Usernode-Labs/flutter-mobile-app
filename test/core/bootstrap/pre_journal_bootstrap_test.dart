import 'package:crypto_mobile_app/core/bootstrap/app_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing journal replays every cleanup before LoggedOut is created',
      () async {
    const cleanupCount = 4;

    for (var crashAfter = 0; crashAfter < cleanupCount; crashAfter++) {
      final events = <String>[];

      await expectLater(
        runPreJournalBootstrap(
          journalMissing: true,
          cleanupSteps: List.generate(
            cleanupCount,
            (index) => () async {
              events.add('cleanup-$index');
              if (index == crashAfter) throw StateError('injected crash');
              return true;
            },
          ),
          createLoggedOut: () async => events.add('logged-out'),
        ),
        throwsStateError,
      );
      expect(events, [
        for (var index = 0; index <= crashAfter; index++) 'cleanup-$index',
      ]);
    }

    final retried = <String>[];
    await runPreJournalBootstrap(
      journalMissing: true,
      cleanupSteps: List.generate(
        cleanupCount,
        (index) => () async {
          retried.add('cleanup-$index');
          return true;
        },
      ),
      createLoggedOut: () async => retried.add('logged-out'),
    );
    expect(retried, [
      for (var index = 0; index < cleanupCount; index++) 'cleanup-$index',
      'logged-out',
    ]);
  });

  test(
      'unconfirmed cleanup keeps authority closed and existing journal is inert',
      () async {
    var commits = 0;

    await expectLater(
      runPreJournalBootstrap(
        journalMissing: true,
        cleanupSteps: [
          () async => true,
          () async => false,
          () async => true,
        ],
        createLoggedOut: () async => commits++,
      ),
      throwsStateError,
    );
    expect(commits, 0);

    var cleanupCalls = 0;
    await runPreJournalBootstrap(
      journalMissing: false,
      cleanupSteps: [
        () async {
          cleanupCalls++;
          return true;
        },
      ],
      createLoggedOut: () async => commits++,
    );
    expect(cleanupCalls, 0);
    expect(commits, 0);
  });
}
