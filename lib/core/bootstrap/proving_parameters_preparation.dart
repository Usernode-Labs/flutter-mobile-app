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

/// Keeps foreground startup pending across a retry, before session admission.
class ProvingParametersPreparation
    extends ValueNotifier<ProvingParametersProgress?> {
  ProvingParametersPreparation() : super(null);

  Future<void>? _active;
  Completer<void>? _retry;

  Future<void> run(
      Future<void> Function(void Function(int, int) report) attempt) {
    return _active ??= _run(attempt).whenComplete(() => _active = null);
  }

  Future<void> _run(
      Future<void> Function(void Function(int, int) report) attempt) async {
    while (true) {
      value = const ProvingParametersProgress(0, 0);
      try {
        await attempt((completed, total) {
          value = ProvingParametersProgress(completed, total);
        });
        value = null;
        return;
      } catch (_) {
        final previous = value!;
        final retry = _retry = Completer<void>();
        value = ProvingParametersProgress(
            previous.completedBytes, previous.totalBytes,
            failed: true);
        await retry.future;
        _retry = null;
      }
    }
  }

  void retry() {
    final retry = _retry;
    if (retry != null && !retry.isCompleted) retry.complete();
  }
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
