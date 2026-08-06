/// A session change that replaces the interactive provider runtime.
enum SessionRuntimeChange { participantReplacement, logout }

typedef SessionRuntimeReplace = Future<void> Function(
  SessionRuntimeChange change,
  Future<void> Function() persistSession,
);

/// Connects [SessionController] to the process-level app root.
///
/// Unit tests and headless engines have no registered root, so their
/// transition runs in place. The interactive root blocks until the old
/// runtime is fully stopped before persisting and bootstrapping the next one.
class SessionRuntimeBoundary {
  SessionRuntimeBoundary._();

  static final instance = SessionRuntimeBoundary._();

  SessionRuntimeReplace? _replaceRuntime;
  bool _busy = false;

  bool get isBusy => _busy;

  void register(SessionRuntimeReplace replaceRuntime) {
    _replaceRuntime = replaceRuntime;
  }

  void unregister() {
    _replaceRuntime = null;
  }

  Future<T> replace<T>({
    required SessionRuntimeChange change,
    required Future<T> Function(bool replacingRuntime) transition,
  }) async {
    final replaceRuntime = _replaceRuntime;
    if (replaceRuntime == null) return transition(false);
    if (_busy) throw StateError('A session replacement is already in progress');

    _busy = true;
    try {
      late T result;
      await replaceRuntime(change, () async {
        result = await transition(true);
      });
      return result;
    } finally {
      _busy = false;
    }
  }

  void resetForTesting() {
    _replaceRuntime = null;
    _busy = false;
  }
}
