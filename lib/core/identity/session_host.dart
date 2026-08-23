import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionHostLifecycleProvider = Provider<SessionHostLifecycle>((ref) {
  throw StateError('Session host lifecycle was not installed');
});

/// Replaces the complete session-owned provider graph around one retirement.
abstract interface class SessionHostLifecycle {
  /// Detaches the current host synchronously, runs [retire], then creates and
  /// mounts one fresh logged-out host.
  ///
  /// Production returns the successor container. Focused controller tests use
  /// [InlineSessionHostLifecycle], which returns null and keeps publication in
  /// the controller under test.
  Future<ProviderContainer?> replace({
    required Future<void> Function() retire,
  });
}

/// Unit-test lifecycle for a controller with no widget/provider host.
class InlineSessionHostLifecycle implements SessionHostLifecycle {
  const InlineSessionHostLifecycle();

  @override
  Future<ProviderContainer?> replace({
    required Future<void> Function() retire,
  }) async {
    await retire();
    return null;
  }
}

enum SessionHostStatus { mounted, transitioning, recoveryRequired, closed }

/// Root-owned lifecycle for exactly one disposable session host at a time.
///
/// There is no session-specific dispatch here. Every replacement disposes the
/// old container, runs one replayable retirement closure, and creates a fresh
/// container. A failed closure stays on one in-process recovery surface; Retry
/// invokes that same closure again.
class SessionHostCoordinator extends ChangeNotifier
    implements SessionHostLifecycle {
  SessionHostCoordinator({
    required Future<ProviderContainer> Function() createSuccessor,
    void Function()? onDetached,
  })  : _createSuccessor = createSuccessor,
        _onDetached = onDetached;

  final Future<ProviderContainer> Function() _createSuccessor;
  final void Function()? _onDetached;

  ProviderContainer? _container;
  SessionHostStatus _status = SessionHostStatus.transitioning;
  Future<void> Function()? _retire;
  Completer<ProviderContainer?>? _replacement;
  bool _running = false;
  bool _closed = false;
  int _generation = 0;

  ProviderContainer? get container => _container;
  SessionHostStatus get status => _status;
  int get generation => _generation;

  void mountInitial(ProviderContainer container) {
    if (_closed || _container != null || _replacement != null) {
      throw StateError('Session host already initialized');
    }
    _container = container;
    _status = SessionHostStatus.mounted;
  }

  @override
  Future<ProviderContainer?> replace({
    required Future<void> Function() retire,
  }) {
    if (_closed) {
      return Future.error(StateError('Session host is closed'));
    }
    final active = _replacement;
    if (active != null) return active.future;

    final replacement = Completer<ProviderContainer?>();
    _replacement = replacement;
    _retire = retire;

    final old = _container;
    _container = null;
    _status = SessionHostStatus.transitioning;
    _onDetached?.call();
    old?.dispose();
    notifyListeners();

    unawaited(_runReplacement());
    return replacement.future;
  }

  void retry() {
    if (_closed || _status != SessionHostStatus.recoveryRequired || _running) {
      return;
    }
    _status = SessionHostStatus.transitioning;
    notifyListeners();
    unawaited(_runReplacement());
  }

  Future<void> _runReplacement() async {
    if (_running || _closed) return;
    final retire = _retire;
    final replacement = _replacement;
    if (retire == null || replacement == null) return;
    _running = true;
    try {
      await retire();
      final successor = await _createSuccessor();
      if (_closed) {
        successor.dispose();
        if (!replacement.isCompleted) {
          replacement.completeError(StateError('Session host is closed'));
        }
        return;
      }
      _container = successor;
      _generation += 1;
      _status = SessionHostStatus.mounted;
      _retire = null;
      _replacement = null;
      notifyListeners();
      replacement.complete(successor);
    } catch (error, stackTrace) {
      if (_closed) {
        if (!replacement.isCompleted) {
          replacement.completeError(error, stackTrace);
        }
        return;
      }
      _status = SessionHostStatus.recoveryRequired;
      notifyListeners();
    } finally {
      _running = false;
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _status = SessionHostStatus.closed;
    final current = _container;
    _container = null;
    _onDetached?.call();
    current?.dispose();
    final replacement = _replacement;
    if (replacement != null && !replacement.isCompleted && !_running) {
      replacement.completeError(StateError('Session host is closed'));
    }
    notifyListeners();
  }
}
