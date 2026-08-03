import 'dart:async';

import 'package:crypto_mobile_app/core/services/session_runtime_boundary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final boundary = SessionRuntimeBoundary.instance;

  setUp(boundary.resetForTesting);
  tearDown(boundary.resetForTesting);

  test('interactive replacement delegates the transition to the host',
      () async {
    final events = <String>[];
    boundary.register((change, persistSession) async {
      events.add('stop:${change.name}');
      await persistSession();
      events.add('start:${change.name}');
    });

    final result = await boundary.replace<int>(
      change: SessionRuntimeChange.logout,
      transition: (replacingRuntime) async {
        expect(replacingRuntime, isTrue);
        events.add('persist');
        return 7;
      },
    );

    expect(result, 7);
    expect(events, ['stop:logout', 'persist', 'start:logout']);
  });

  test('headless replacement runs in place', () async {
    final result = await boundary.replace<int>(
      change: SessionRuntimeChange.logout,
      transition: (replacingRuntime) async {
        expect(replacingRuntime, isFalse);
        return 7;
      },
    );

    expect(result, 7);
  });

  test('rejects overlapping interactive replacements', () async {
    final release = Completer<void>();
    boundary.register((_, persistSession) async {
      await release.future;
      await persistSession();
    });

    final first = boundary.replace<void>(
      change: SessionRuntimeChange.logout,
      transition: (_) async {},
    );
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      boundary.replace<void>(
        change: SessionRuntimeChange.logout,
        transition: (_) async {},
      ),
      throwsStateError,
    );

    release.complete();
    await first;
  });
}
