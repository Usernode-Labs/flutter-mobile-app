import 'dart:async';

/// Share one monitor across callers of the same operation in a Dart isolate.
final class SlowOperationMonitor {
  SlowOperationMonitor({
    Stopwatch Function() stopwatchFactory = Stopwatch.new,
  }) : _stopwatchFactory = stopwatchFactory;

  final Stopwatch Function() _stopwatchFactory;
  int _pendingCallers = 0;

  int get pendingCallers => _pendingCallers;

  /// Reports once when [operation] reaches [threshold], including at completion
  /// if the timer was delayed. The report receives the current pending count,
  /// including this call. Neither the report nor its delivery changes the
  /// operation's result or lifetime.
  Future<T> run<T>({
    required Future<T> Function() operation,
    required Duration threshold,
    required Future<void> Function(int pendingCallers) report,
  }) async {
    final stopwatch = _stopwatchFactory()..start();
    _pendingCallers++;
    var reported = false;
    void reportOnce() {
      if (reported) return;
      reported = true;
      final pendingCallers = _pendingCallers;
      unawaited(Future<void>.sync(() => report(pendingCallers))
          .catchError((Object _, StackTrace __) {
        // A telemetry failure must not fail the native operation or its caller.
      }));
    }

    final timer = Timer(threshold, reportOnce);
    try {
      return await operation();
    } finally {
      stopwatch.stop();
      timer.cancel();
      // Completion microtasks can run before an overdue timer after a stall.
      if (stopwatch.elapsed >= threshold) reportOnce();
      _pendingCallers--;
    }
  }
}
