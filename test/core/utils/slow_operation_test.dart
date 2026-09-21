import 'dart:async';

import 'package:crypto_mobile_app/core/utils/slow_operation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const threshold = Duration(seconds: 5);
  late SlowOperationMonitor monitor;
  setUp(() => monitor = SlowOperationMonitor());
  tearDown(() => expect(monitor.pendingCallers, 0));

  testWidgets('completion before five seconds cancels the report',
      (tester) async {
    final operation = Completer<int>();
    var reports = 0;
    final result = monitor.run(
      operation: () => operation.future,
      threshold: threshold,
      report: (_) async => reports++,
    );

    await tester.pump(const Duration(milliseconds: 4999));
    expect(reports, 0);
    operation.complete(42);
    await tester.pump();
    expect(await result, 42);

    await tester.pump(const Duration(seconds: 10));
    expect(reports, 0);
  });

  testWidgets('reports a pending read once and preserves its eventual result',
      (tester) async {
    final stopwatch = _ManualStopwatch();
    monitor = SlowOperationMonitor(stopwatchFactory: () => stopwatch);
    final operation = Completer<int>();
    final reportDelivery = Completer<void>();
    var reports = 0;
    var completed = false;
    final result = monitor
        .run(
      operation: () => operation.future,
      threshold: threshold,
      report: (_) {
        reports++;
        return reportDelivery.future;
      },
    )
        .then((value) {
      completed = true;
      return value;
    });

    await tester.pump(const Duration(milliseconds: 4999));
    expect(reports, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(reports, 1);
    expect(completed, isFalse);

    await tester.pump(const Duration(seconds: 20));
    expect(reports, 1);
    expect(completed, isFalse);

    stopwatch.elapsed = const Duration(seconds: 25);
    operation.complete(42);
    await tester.pump();
    expect(await result, 42);
    // Native completion does not wait for Sentry delivery either.
    expect(reportDelivery.isCompleted, isFalse);
    expect(reports, 1);
    reportDelivery.complete();
    await tester.pump();
  });

  for (final fails in [false, true]) {
    testWidgets(
        'reports late ${fails ? 'failure' : 'success'} before a delayed timer',
        (tester) async {
      final stopwatch = _ManualStopwatch();
      var calls = 0;
      monitor = SlowOperationMonitor(
        stopwatchFactory: () => calls++ == 0 ? stopwatch : _ManualStopwatch(),
      );
      final operation = Completer<int>();
      final youngerOperation = Completer<int>();
      final failure = StateError('native read failed');
      final stackTrace = StackTrace.current;
      final counts = <int>[];
      Object? outcome;
      StackTrace? observedStack;
      final result = monitor.run(
        operation: () => operation.future,
        threshold: threshold,
        report: (pendingCallers) async => counts.add(pendingCallers),
      );
      final observed = result.then<void>((value) {
        outcome = value;
      }, onError: (Object error, StackTrace stack) {
        outcome = error;
        observedStack = stack;
      });
      final youngerResult = monitor.run(
        operation: () => youngerOperation.future,
        threshold: threshold,
        report: (pendingCallers) async => counts.add(pendingCallers),
      );

      // Time passed while Dart was stalled, but timers have not been delivered.
      stopwatch.elapsed = const Duration(seconds: 6);
      expect(counts, isEmpty);
      if (fails) {
        operation.completeError(failure, stackTrace);
      } else {
        operation.complete(42);
      }
      await tester.pump();
      await observed;
      expect(outcome, fails ? same(failure) : 42);
      expect(observedStack, fails ? same(stackTrace) : isNull);
      expect(counts, [2]);
      expect(monitor.pendingCallers, 1);

      youngerOperation.complete(7);
      await tester.pump();
      expect(await youngerResult, 7);
      await tester.pump(const Duration(seconds: 10));
      expect(counts, [2]);
    });
  }

  for (final slow in [false, true]) {
    testWidgets('preserves ${slow ? 'slow' : 'fast'} errors and stack traces',
        (tester) async {
      final operation = Completer<int>();
      final failure = StateError('native read failed');
      final stackTrace = StackTrace.current;
      Object? observedError;
      StackTrace? observedStack;
      var reports = 0;
      final result = monitor
          .run(
        operation: () => operation.future,
        threshold: threshold,
        report: (_) async => reports++,
      )
          .then<void>((_) => fail('Expected the original failure'),
              onError: (Object error, StackTrace stack) {
        observedError = error;
        observedStack = stack;
      });

      await tester.pump(Duration(seconds: slow ? 6 : 1));
      operation.completeError(failure, stackTrace);
      await tester.pump();
      await result;
      expect(observedError, same(failure));
      expect(observedStack, same(stackTrace));
      await tester.pump(const Duration(seconds: 10));
      expect(reports, slow ? 1 : 0);
    });
  }

  testWidgets('synchronous invocation failure cancels the timer',
      (tester) async {
    final failure = StateError('could not invoke native read');
    var reports = 0;
    final result = monitor.run<int>(
      operation: () => throw failure,
      threshold: threshold,
      report: (_) async => reports++,
    );

    await expectLater(result, throwsA(same(failure)));
    await tester.pump(const Duration(seconds: 10));
    expect(reports, 0);
  });

  for (final synchronous in [false, true]) {
    testWidgets(
        '${synchronous ? 'sync' : 'async'} reporting failure cannot fail the read',
        (tester) async {
      final operation = Completer<int>();
      final result = monitor.run(
        operation: () => operation.future,
        threshold: threshold,
        report: (_) {
          final failure = StateError('telemetry unavailable');
          if (synchronous) throw failure;
          return Future<void>.error(failure);
        },
      );

      await tester.pump(threshold);
      operation.complete(42);
      await tester.pump();
      expect(await result, 42);
    });
  }

  testWidgets('concurrent reads have independent warning timers',
      (tester) async {
    final first = Completer<int>();
    final second = Completer<int>();
    final reports = <String>[];
    final firstResult = monitor.run(
      operation: () => first.future,
      threshold: threshold,
      report: (_) async => reports.add('first'),
    );
    await tester.pump(const Duration(seconds: 2));
    final secondResult = monitor.run(
      operation: () => second.future,
      threshold: threshold,
      report: (_) async => reports.add('second'),
    );
    first.complete(1);
    await tester.pump(const Duration(seconds: 3));
    expect(reports, isEmpty);
    await tester.pump(const Duration(seconds: 2));
    expect(reports, ['second']);
    second.complete(2);
    await tester.pump();
    expect(await firstResult, 1);
    expect(await secondResult, 2);
  });

  testWidgets('warnings count all currently pending callers, including self',
      (tester) async {
    final first = Completer<int>();
    final second = Completer<int>();
    final third = Completer<int>();
    final counts = <int>[];
    Future<int> start(Completer<int> operation) => monitor.run(
          operation: () => operation.future,
          threshold: threshold,
          report: (pendingCallers) async => counts.add(pendingCallers),
        );

    final firstResult = start(first);
    expect(monitor.pendingCallers, 1);
    await tester.pump(const Duration(seconds: 2));
    final secondResult = start(second);
    final thirdResult = start(third);
    expect(monitor.pendingCallers, 3);

    // First call reaches five seconds; the other two are only three seconds old.
    await tester.pump(const Duration(seconds: 3));
    expect(counts, [3]);

    first.complete(1);
    second.complete(2);
    await tester.pump();
    expect(monitor.pendingCallers, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(counts, [3, 1]);

    third.complete(3);
    await tester.pump();
    expect(
        await Future.wait([firstResult, secondResult, thirdResult]), [1, 2, 3]);
    expect(monitor.pendingCallers, 0);
  });

  testWidgets('failed callers are removed before another call reports',
      (tester) async {
    final failing = Completer<int>();
    final pending = Completer<int>();
    final failure = StateError('native read failed');
    final counts = <int>[];
    final failedResult = monitor.run(
      operation: () => failing.future,
      threshold: threshold,
      report: (pendingCallers) async => counts.add(pendingCallers),
    );
    final failureObserved = expectLater(failedResult, throwsA(same(failure)));
    final pendingResult = monitor.run(
      operation: () => pending.future,
      threshold: threshold,
      report: (pendingCallers) async => counts.add(pendingCallers),
    );
    expect(monitor.pendingCallers, 2);

    await tester.pump(const Duration(seconds: 1));
    failing.completeError(failure);
    await tester.pump();
    await failureObserved;
    expect(monitor.pendingCallers, 1);

    await tester.pump(const Duration(seconds: 4));
    expect(counts, [1]);
    pending.complete(42);
    await tester.pump();
    expect(await pendingResult, 42);
  });
}

class _ManualStopwatch extends Stopwatch {
  @override
  Duration elapsed = Duration.zero;
}
