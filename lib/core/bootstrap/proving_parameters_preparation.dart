import 'dart:async';

import 'package:flutter/foundation.dart';

/// Presentation state only; native capabilities stay in the composition root.
class ProvingParametersProgress {
  const ProvingParametersProgress(this.completedBytes, this.totalBytes,
      {this.failed = false});

  final int completedBytes;
  final int totalBytes;
  final bool failed;
  double get fraction =>
      totalBytes == 0 ? 0 : (completedBytes / totalBytes).clamp(0, 1);
}

/// Coalesces foreground preparation and clears its UI when the session closes.
class ProvingParametersPreparation
    extends ValueNotifier<ProvingParametersProgress?> {
  ProvingParametersPreparation() : super(null);

  Future<void>? _active;
  Completer<void>? _retry;

  Future<void> run(
    Future<void> Function(void Function(int, int) report) attempt, {
    Future<void>? cancelled,
  }) {
    return _active ??=
        _run(attempt, cancelled).whenComplete(() => _active = null);
  }

  Future<void> _run(
    Future<void> Function(void Function(int, int) report) attempt,
    Future<void>? cancelled,
  ) async {
    var stopped = false;
    final cancellation = cancelled?.then<void>((_) {
      stopped = true;
      throw const ProvingParametersPreparationCancelled();
    });
    Future<void> wait(Future<void> work) =>
        cancellation == null ? work : Future.any([work, cancellation]);
    try {
      while (true) {
        value = const ProvingParametersProgress(0, 0);
        try {
          await wait(attempt((completed, total) {
            if (!stopped) value = ProvingParametersProgress(completed, total);
          }));
          value = null;
          return;
        } catch (_) {
          if (stopped) rethrow;
          final previous = value!;
          final retry = _retry = Completer<void>();
          value = ProvingParametersProgress(
              previous.completedBytes, previous.totalBytes,
              failed: true);
          await wait(retry.future);
          _retry = null;
        }
      }
    } finally {
      stopped = true;
      _retry = null;
      value = null;
    }
  }

  void retry() {
    final retry = _retry;
    if (retry != null && !retry.isCompleted) retry.complete();
  }
}

final class ProvingParametersPreparationCancelled implements Exception {
  const ProvingParametersPreparationCancelled();
}

/// Joins polling with preparation so failures cannot leave polling behind.
Future<void> pollProvingParameters({
  required Future<void> Function() prepare,
  required Future<(bool ready, int completed, int total)> Function() status,
  required void Function(int, int) report,
  Duration interval = const Duration(milliseconds: 500),
}) async {
  final initial = await status();
  if (initial.$1) return;
  report(initial.$2, initial.$3);
  var finished = false;
  final preparation = prepare().whenComplete(() => finished = true);
  final progress = () async {
    while (!finished) {
      final current = await status();
      report(current.$2, current.$3);
      if (!finished) await Future<void>.delayed(interval);
    }
  }();
  await Future.wait<void>([preparation, progress]);
}
